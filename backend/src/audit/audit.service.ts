import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

export const AuditAction = {
  LOGIN: 'LOGIN',
  LOGOUT: 'LOGOUT',
  LOGOUT_ALL: 'LOGOUT_ALL',
  REFRESH_REUSE_DETECTED: 'REFRESH_REUSE_DETECTED',
  SESSION_REVOKED: 'SESSION_REVOKED',
  COMPANY_CREATED: 'COMPANY_CREATED',
  COMPANY_UPDATED: 'COMPANY_UPDATED',
  COMPANY_VERIFICATION_REQUESTED: 'COMPANY_VERIFICATION_REQUESTED',
  COMPANY_VERIFICATION_DECIDED: 'COMPANY_VERIFICATION_DECIDED',
  MEMBER_ADDED: 'MEMBER_ADDED',
  WORKER_ADDED: 'WORKER_ADDED',
  MEMBER_UPDATED: 'MEMBER_UPDATED',
  WORKER_REMOVED: 'WORKER_REMOVED',
  MEMBER_REMOVED: 'MEMBER_REMOVED',
  MEMBER_LEFT: 'MEMBER_LEFT',
  WORKER_BLOCKED: 'WORKER_BLOCKED',
  WORKER_UNBLOCKED: 'WORKER_UNBLOCKED',
  PROJECT_CREATED: 'PROJECT_CREATED',
  PROJECT_UPDATED: 'PROJECT_UPDATED',
  PROJECT_DELETED: 'PROJECT_DELETED',
  SITE_CREATED: 'SITE_CREATED',
  SITE_UPDATED: 'SITE_UPDATED',
  SITE_DELETED: 'SITE_DELETED',
  SITE_ASSIGNED: 'SITE_ASSIGNED',
  SITE_UNASSIGNED: 'SITE_UNASSIGNED',
  WORK_STARTED: 'WORK_STARTED',
  WORK_ENDED: 'WORK_ENDED',
  SHIFT_AUTO_CLOSED: 'SHIFT_AUTO_CLOSED',
  SHIFT_VERIFIED: 'SHIFT_VERIFIED',
  SHIFT_REJECTED: 'SHIFT_REJECTED',
  SHIFT_CORRECTED: 'SHIFT_CORRECTED',
  TASK_CREATED: 'TASK_CREATED',
  TASK_APPROVED: 'TASK_APPROVED',
  TASK_REJECTED: 'TASK_REJECTED',
  TASK_CHANGES_REQUESTED: 'TASK_CHANGES_REQUESTED',
  TASK_CANCELLED: 'TASK_CANCELLED',
  EVIDENCE_UPLOADED: 'EVIDENCE_UPLOADED',
  VACANCY_CREATED: 'VACANCY_CREATED',
  VACANCY_UPDATED: 'VACANCY_UPDATED',
  VACANCY_STATUS_CHANGED: 'VACANCY_STATUS_CHANGED',
  APPLICATION_SUBMITTED: 'APPLICATION_SUBMITTED',
  APPLICATION_WITHDRAWN: 'APPLICATION_WITHDRAWN',
  APPLICATION_STATUS_CHANGED: 'APPLICATION_STATUS_CHANGED',
  DISPUTE_OPENED: 'DISPUTE_OPENED',
  DISPUTE_RESOLVED: 'DISPUTE_RESOLVED',
} as const;
export type AuditAction = (typeof AuditAction)[keyof typeof AuditAction];

export interface AuditEntry {
  action: AuditAction;
  entityType: string;
  entityId?: string | null;
  companyId?: string | null;
  actorUserId?: string | null;
  metadata?: Record<string, unknown>;
  ip?: string | null;
}

@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(private readonly prisma: PrismaService) {}

  /** Writes inside the caller's transaction when `tx` is passed (atomic with the business change). */
  async log(entry: AuditEntry, tx?: Prisma.TransactionClient): Promise<void> {
    const client = tx ?? this.prisma;
    try {
      await client.auditLog.create({
        data: {
          action: entry.action,
          entityType: entry.entityType,
          entityId: entry.entityId ?? null,
          companyId: entry.companyId ?? null,
          actorUserId: entry.actorUserId ?? null,
          metadata: (entry.metadata ?? {}) as Prisma.InputJsonValue,
          ip: entry.ip ?? null,
        },
      });
    } catch (e) {
      if (tx) throw e; // inside a transaction the business change must roll back too
      this.logger.error({ err: e, action: entry.action }, 'Failed to write audit log');
    }
  }

  async listForCompany(companyId: string, skip: number, take: number, action?: string) {
    const where: Prisma.AuditLogWhereInput = { companyId, ...(action ? { action } : {}) };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.auditLog.findMany({ where, orderBy: { createdAt: 'desc' }, skip, take }),
      this.prisma.auditLog.count({ where }),
    ]);
    return { items, total };
  }
}
