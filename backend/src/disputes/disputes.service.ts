import { Injectable } from '@nestjs/common';
import { CompanyMembership, DisputeStatus, EventSource, Prisma, ShiftStatus, WorkEventType } from '@prisma/client';
import { ErrorCode, badRequest, conflict, forbidden, notFound } from '../common/errors';
import { paginated } from '../common/dto/pagination.dto';
import type { RequestMeta } from '../common/types';
import { PrismaService } from '../prisma/prisma.service';
import { AccessService } from '../access/access.service';
import { AuditAction, AuditService } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { ShiftsService } from '../attendance/shifts.service';
import { DisputesQuery, OpenDisputeDto, ResolveDisputeDto } from './dto/disputes.dto';

/**
 * Disputes keep BOTH sides: the worker's claim (reason, claimed times) and the employer's resolution.
 * Nothing is deleted; accepted disputes produce a SHIFT_CORRECTED event linked to the dispute.
 */
@Injectable()
export class DisputesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessService,
    private readonly audit: AuditService,
    private readonly notifications: NotificationsService,
    private readonly shifts: ShiftsService,
  ) {}

  async open(userId: string, shiftId: string, dto: OpenDisputeDto, meta: RequestMeta) {
    const shift = await this.prisma.shift.findFirst({ where: { id: shiftId, workerId: userId } });
    if (!shift) throw notFound('Shift');
    if (shift.status === ShiftStatus.OPEN) throw conflict(ErrorCode.SHIFT_OPEN, 'Finish the shift before disputing it');
    if (!dto.claimedStart && !dto.claimedEnd && dto.reason.length < 10) {
      throw badRequest(ErrorCode.VALIDATION_FAILED, 'Describe the problem or provide the correct times');
    }
    const claimedStart = dto.claimedStart ? new Date(dto.claimedStart) : null;
    const claimedEnd = dto.claimedEnd ? new Date(dto.claimedEnd) : null;
    if (claimedStart && claimedEnd && claimedEnd <= claimedStart) throw badRequest(ErrorCode.END_BEFORE_START, 'End must be after start');

    const dispute = await this.prisma.$transaction(async (tx) => {
      const existing = await tx.dispute.count({ where: { shiftId, status: DisputeStatus.OPEN } });
      if (existing) throw conflict(ErrorCode.DISPUTE_ALREADY_OPEN, 'There is already an open dispute for this shift');
      const d = await tx.dispute.create({
        data: { companyId: shift.companyId, shiftId, openedById: userId, reason: dto.reason, claimedStart, claimedEnd },
      });
      await tx.workEvent.create({
        data: {
          companyId: shift.companyId,
          siteId: shift.siteId,
          shiftId,
          subjectUserId: userId,
          actorUserId: userId,
          type: WorkEventType.DISPUTE_OPENED,
          source: EventSource.MOBILE_APP,
          occurredAt: new Date(),
          entityType: 'Dispute',
          entityId: d.id,
          reason: dto.reason,
          metadata: { claimedStart, claimedEnd },
        },
      });
      await this.audit.log(
        { action: AuditAction.DISPUTE_OPENED, entityType: 'Dispute', entityId: d.id, companyId: shift.companyId, actorUserId: userId, ip: meta.ip, metadata: { shiftId } },
        tx,
      );
      return d;
    });
    const supervisors = await this.notifications.supervisorsOf(shift.companyId, shift.siteId);
    await this.notifications.notify(supervisors, {
      type: 'DISPUTE_OPENED',
      category: 'disputes',
      companyId: shift.companyId,
      title: "Ish vaqti bo'yicha e'tiroz",
      body: dto.reason.slice(0, 200),
      data: { disputeId: dispute.id, shiftId },
    });
    return dispute;
  }

  async mine(userId: string, q: DisputesQuery) {
    const where: Prisma.DisputeWhereInput = { openedById: userId, ...(q.status ? { status: q.status } : {}) };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.dispute.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: q.skip,
        take: q.limit,
        include: { shift: { select: { id: true, businessDate: true, startedAt: true, endedAt: true, status: true } }, company: { select: { id: true, name: true } } },
      }),
      this.prisma.dispute.count({ where }),
    ]);
    return paginated(items, total, q);
  }

  async list(actor: CompanyMembership, q: DisputesQuery) {
    const scope = await this.access.siteScope(actor);
    const where: Prisma.DisputeWhereInput = {
      companyId: actor.companyId,
      ...(q.status ? { status: q.status } : {}),
      ...(scope.siteId ? { shift: { siteId: scope.siteId } } : {}),
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.dispute.findMany({
        where,
        orderBy: [{ status: 'asc' }, { createdAt: 'desc' }],
        skip: q.skip,
        take: q.limit,
        include: {
          shift: {
            select: {
              id: true,
              businessDate: true,
              startedAt: true,
              endedAt: true,
              status: true,
              site: { select: { id: true, name: true } },
              worker: { select: { id: true, fullName: true, phone: true } },
            },
          },
        },
      }),
      this.prisma.dispute.count({ where }),
    ]);
    return paginated(items, total, q);
  }

  async resolve(actor: CompanyMembership, id: string, dto: ResolveDisputeDto, meta: RequestMeta) {
    const d = await this.prisma.dispute.findFirst({ where: { id, companyId: actor.companyId }, include: { shift: true } });
    if (!d) throw notFound('Dispute');
    await this.access.assertSiteAccess(actor, d.shift.siteId);
    if (d.shift.workerId === actor.userId) throw forbidden(ErrorCode.CANNOT_REVIEW_OWN_WORK, 'You cannot resolve your own dispute');
    if (d.status !== DisputeStatus.OPEN) throw conflict(ErrorCode.DISPUTE_NOT_OPEN, 'Dispute is already resolved');

    if (dto.accept) {
      const startedAt = dto.correctedStart ?? d.claimedStart?.toISOString();
      const endedAt = dto.correctedEnd ?? d.claimedEnd?.toISOString();
      if (startedAt || endedAt) {
        await this.shifts.correct(actor, d.shiftId, { startedAt, endedAt, reason: `E'tiroz qabul qilindi: ${dto.resolution}`, verify: true }, meta, { disputeId: d.id });
      } else if (d.shift.status !== ShiftStatus.VERIFIED && d.shift.endedAt) {
        await this.shifts.verify(actor, d.shiftId, { note: dto.resolution }, meta);
      }
    }
    const status = dto.accept ? DisputeStatus.ACCEPTED : DisputeStatus.REJECTED;
    const updated = await this.prisma.$transaction(async (tx) => {
      const r = await tx.dispute.updateMany({
        where: { id, status: DisputeStatus.OPEN },
        data: { status, resolution: dto.resolution, resolvedById: actor.userId, resolvedAt: new Date() },
      });
      if (r.count === 0) throw conflict(ErrorCode.DISPUTE_NOT_OPEN, 'Dispute is already resolved');
      await tx.workEvent.create({
        data: {
          companyId: d.companyId,
          siteId: d.shift.siteId,
          shiftId: d.shiftId,
          subjectUserId: d.shift.workerId,
          actorUserId: actor.userId,
          type: WorkEventType.DISPUTE_RESOLVED,
          source: EventSource.FOREMAN_APP,
          occurredAt: new Date(),
          entityType: 'Dispute',
          entityId: d.id,
          reason: dto.resolution,
          metadata: { accepted: dto.accept },
        },
      });
      await this.audit.log(
        {
          action: AuditAction.DISPUTE_RESOLVED,
          entityType: 'Dispute',
          entityId: d.id,
          companyId: d.companyId,
          actorUserId: actor.userId,
          ip: meta.ip,
          metadata: { accepted: dto.accept, resolution: dto.resolution },
        },
        tx,
      );
      return tx.dispute.findUniqueOrThrow({ where: { id } });
    });
    await this.notifications.notify([d.shift.workerId], {
      type: dto.accept ? 'DISPUTE_ACCEPTED' : 'DISPUTE_REJECTED',
      category: 'disputes',
      companyId: d.companyId,
      title: dto.accept ? "E'tirozingiz qabul qilindi" : "E'tirozingiz rad etildi",
      body: dto.resolution,
      data: { disputeId: d.id, shiftId: d.shiftId },
    });
    return updated;
  }
}
