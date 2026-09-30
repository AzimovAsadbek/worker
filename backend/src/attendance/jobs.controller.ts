import { Controller, Get, Headers, HttpCode, Inject, Query } from '@nestjs/common';
import { ApiExcludeController } from '@nestjs/swagger';
import { SkipThrottle } from '@nestjs/throttler';
import { APP_CONFIG, AppConfig } from '../config/configuration';
import { notFound } from '../common/errors';
import { safeEqualHex, sha256 } from '../common/utils/crypto';
import { Public } from '../common/decorators/public.decorator';
import { AttendanceJobs } from './attendance.jobs';

/**
 * Serverless-friendly trigger for reminders / absence alerts (Vercel Cron or any external scheduler).
 * Auth: `Authorization: Bearer <CRON_SECRET>` (what Vercel Cron sends) or `?secret=`.
 * Returns 404 when CRON_SECRET is not configured or does not match.
 */
@ApiExcludeController()
@Controller('internal/jobs')
export class JobsController {
  constructor(
    private readonly jobs: AttendanceJobs,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  @Public()
  @SkipThrottle()
  @Get('attendance')
  @HttpCode(200)
  async run(@Headers('authorization') auth?: string, @Query('secret') secret?: string) {
    const expected = this.config.cronSecret;
    const given = auth?.startsWith('Bearer ') ? auth.slice(7) : secret;
    if (!expected || !given || !safeEqualHex(sha256(given), sha256(expected))) throw notFound('Route');
    await this.jobs.run(new Date());
    return { ok: true, ranAt: new Date().toISOString() };
  }
}
