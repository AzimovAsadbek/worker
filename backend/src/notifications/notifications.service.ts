import { Injectable, Logger } from '@nestjs/common';
import { MembershipStatus, Prisma, Role } from '@prisma/client';
import { notFound } from '../common/errors';
import { PrismaService } from '../prisma/prisma.service';
import { UsersService } from '../users/users.service';
import type { NotificationCategory } from '../users/dto/users.dto';
import { FcmSender } from './fcm.sender';

export interface NotifyInput {
  type: string;
  category: NotificationCategory;
  title: string;
  body: string;
  companyId?: string | null;
  data?: Record<string, string>;
  /** Makes the notification idempotent per user (e.g. "absent:site:date"). */
  dedupeKey?: string;
}

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly fcm: FcmSender,
    private readonly users: UsersService,
  ) {}

  /** Never throws — notifications must not break business operations. */
  async notify(userIds: string[], input: NotifyInput): Promise<void> {
    const unique = [...new Set(userIds)].filter(Boolean);
    if (!unique.length) return;
    try {
      const users = await this.prisma.user.findMany({
        where: { id: { in: unique }, isActive: true },
        select: { id: true, notificationPrefs: true, deviceTokens: { select: { token: true } } },
      });
      for (const u of users) {
        const prefs = this.users.resolvePrefs(u.notificationPrefs)[input.category] ?? { push: true, inApp: true };
        let created = true;
        if (prefs.inApp) {
          try {
            await this.prisma.notification.create({
              data: {
                userId: u.id,
                companyId: input.companyId ?? null,
                type: input.type,
                category: input.category,
                title: input.title,
                body: input.body,
                data: (input.data ?? {}) as Prisma.InputJsonValue,
                dedupeKey: input.dedupeKey ? `${input.dedupeKey}:${u.id}` : null,
              },
            });
          } catch (e) {
            if ((e as { code?: string }).code === 'P2002') created = false; // already notified
            else throw e;
          }
        }
        if (created && prefs.push && this.fcm.enabled && u.deviceTokens.length) {
          const { invalidTokens } = await this.fcm.send(
            u.deviceTokens.map((t) => t.token),
            { title: input.title, body: input.body, data: { type: input.type, ...(input.data ?? {}) } },
          );
          if (invalidTokens.length) await this.prisma.deviceToken.deleteMany({ where: { token: { in: invalidTokens } } });
        }
      }
    } catch (e) {
      this.logger.error({ err: e, type: input.type }, 'Failed to deliver notification');
    }
  }

  /** Company admins/managers (+ optionally foremen of a site). */
  async supervisorsOf(companyId: string, siteId?: string | null): Promise<string[]> {
    const admins = await this.prisma.companyMembership.findMany({
      where: { companyId, status: MembershipStatus.ACTIVE, role: { in: [Role.COMPANY_ADMIN, Role.MANAGER] } },
      select: { userId: true },
    });
    const ids = admins.map((a) => a.userId);
    if (siteId) ids.push(...(await this.foremenOf(siteId)));
    return [...new Set(ids)];
  }

  async foremenOf(siteId: string): Promise<string[]> {
    const rows = await this.prisma.siteAssignment.findMany({
      where: { siteId, role: Role.FOREMAN, status: 'ACTIVE' },
      select: { userId: true },
    });
    return rows.map((r) => r.userId);
  }

  async list(userId: string, skip: number, take: number, unreadOnly: boolean) {
    const where: Prisma.NotificationWhereInput = { userId, ...(unreadOnly ? { readAt: null } : {}) };
    const [items, total, unread] = await this.prisma.$transaction([
      this.prisma.notification.findMany({ where, orderBy: { createdAt: 'desc' }, skip, take }),
      this.prisma.notification.count({ where }),
      this.prisma.notification.count({ where: { userId, readAt: null } }),
    ]);
    return { items, total, unread };
  }

  async markRead(userId: string, id: string) {
    const r = await this.prisma.notification.updateMany({ where: { id, userId, readAt: null }, data: { readAt: new Date() } });
    if (r.count === 0) {
      const exists = await this.prisma.notification.count({ where: { id, userId } });
      if (!exists) throw notFound('Notification');
    }
  }

  async markAllRead(userId: string) {
    await this.prisma.notification.updateMany({ where: { userId, readAt: null }, data: { readAt: new Date() } });
  }
}
