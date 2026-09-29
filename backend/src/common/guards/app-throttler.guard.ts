import { Injectable } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';
import type { AuthedRequest } from '../types';

/**
 * Rate limits per authenticated user, per IP otherwise. Uzbek mobile carriers use carrier-grade NAT,
 * so a whole construction crew can share one public IP — per-IP limits alone would block them.
 * Must run after JwtAuthGuard (see provider order in AppModule).
 */
@Injectable()
export class AppThrottlerGuard extends ThrottlerGuard {
  protected override async getTracker(req: Record<string, unknown>): Promise<string> {
    const r = req as unknown as AuthedRequest;
    return r.user?.id ? `u:${r.user.id}` : `ip:${r.ip}`;
  }
}
