import { Inject, Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { AssignmentStatus, Role, ShiftStatus } from '@prisma/client';
import { APP_CONFIG, AppConfig } from '../config/configuration';
import { dateOnly, isoWeekday, localDateString, zonedTimeToUtc } from '../common/utils/time';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { scheduledEnd } from './attendance.rules';

const TEN_MINUTES = 10 * 60_000;

/**
 * Periodic reminders/alerts. Idempotent via Notification.dedupeKey, so running on several
 * instances or restarting never spams users.
 */
@Injectable()
export class AttendanceJobs {
  private readonly logger = new Logger(AttendanceJobs.name);
  private running = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  @Interval(TEN_MINUTES)
  async tick() {
    if (!this.config.jobsEnabled || this.running) return;
    this.running = true;
    try {
      await this.run(new Date());
    } catch (e) {
      this.logger.error({ err: e }, 'Attendance job failed');
    } finally {
      this.running = false;
    }
  }

  async run(now: Date) {
    const sites = await this.prisma.site.findMany({ where: { deletedAt: null, status: 'ACTIVE', company: { deletedAt: null } } });
    for (const site of sites) {
      const today = localDateString(now, site.timezone);
      if (!site.workDays.includes(isoWeekday(today))) continue;
      const start = zonedTimeToUtc(today, site.shiftStart, site.timezone);
      const lateCutoff = new Date(start.getTime() + site.lateGraceMinutes * 60_000);
      const end = scheduledEnd(site, today);

      const assignments = await this.prisma.siteAssignment.findMany({
        where: { siteId: site.id, status: AssignmentStatus.ACTIVE, role: Role.WORKER },
        select: { userId: true },
      });
      if (!assignments.length) continue;
      const workerIds = assignments.map((a) => a.userId);

      // 1) Shift reminder: 30 → 0 minutes before start, for workers without an open shift.
      const msToStart = start.getTime() - now.getTime();
      if (msToStart > 0 && msToStart <= 30 * 60_000) {
        const open = await this.prisma.shift.findMany({ where: { workerId: { in: workerIds }, status: ShiftStatus.OPEN }, select: { workerId: true } });
        const openIds = new Set(open.map((o) => o.workerId));
        await this.notifications.notify(
          workerIds.filter((id) => !openIds.has(id)),
          {
            type: 'SHIFT_REMINDER',
            category: 'shift',
            companyId: site.companyId,
            title: 'Ish boshlanishiga oz qoldi',
            body: `${site.name}: ish ${site.shiftStart} da boshlanadi. Kelganda "Ishni boshlash" tugmasini bosing.`,
            data: { siteId: site.id },
            dedupeKey: `reminder:${site.id}:${today}`,
          },
        );
      }

      // 2) Absent alert for foremen: first hour after the late cutoff.
      const sinceCutoff = now.getTime() - lateCutoff.getTime();
      if (sinceCutoff > 0 && sinceCutoff <= 60 * 60_000) {
        const present = await this.prisma.shift.findMany({
          where: { siteId: site.id, workerId: { in: workerIds }, businessDate: dateOnly(today) },
          select: { workerId: true, isLate: true },
        });
        const presentIds = new Set(present.map((p) => p.workerId));
        const absent = workerIds.filter((id) => !presentIds.has(id)).length;
        const late = present.filter((p) => p.isLate).length;
        if (absent || late) {
          const foremen = await this.notifications.supervisorsOf(site.companyId, site.id);
          await this.notifications.notify(foremen, {
            type: 'ATTENDANCE_ALERT',
            category: 'attendance',
            companyId: site.companyId,
            title: `${site.name}: davomat`,
            body: `Kelmagan: ${absent}, kechikkan: ${late}.`,
            data: { siteId: site.id },
            dedupeKey: `absent:${site.id}:${today}`,
          });
        }
      }

      // 3) Pending checkout: 2 h after the scheduled end.
      const sinceEnd = now.getTime() - end.getTime();
      if (sinceEnd > 2 * 3600_000 && sinceEnd <= 4 * 3600_000) {
        const open = await this.prisma.shift.findMany({
          where: { siteId: site.id, status: ShiftStatus.OPEN, businessDate: dateOnly(today) },
          select: { workerId: true },
        });
        if (open.length) {
          await this.notifications.notify(
            open.map((o) => o.workerId),
            {
              type: 'CHECKOUT_REMINDER',
              category: 'shift',
              companyId: site.companyId,
              title: 'Ishni yakunlashni unutdingizmi?',
              body: `${site.name}: ish tugagan bo'lsa, "Ishni yakunlash" tugmasini bosing.`,
              data: { siteId: site.id },
              dedupeKey: `checkout:${site.id}:${today}`,
            },
          );
          const foremen = await this.notifications.supervisorsOf(site.companyId, site.id);
          await this.notifications.notify(foremen, {
            type: 'PENDING_CHECKOUT',
            category: 'attendance',
            companyId: site.companyId,
            title: `${site.name}: yakunlanmagan smenalar`,
            body: `${open.length} ishchi ishni yakunlamagan.`,
            data: { siteId: site.id },
            dedupeKey: `pending-checkout:${site.id}:${today}`,
          });
        }
      }
    }
  }
}
