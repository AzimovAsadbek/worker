import { Inject, Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { APP_CONFIG, AppConfig } from '../config/configuration';
import { ErrorCode, unauthorized } from '../common/errors';
import { randomToken, sha256 } from '../common/utils/crypto';
import { PrismaService } from '../prisma/prisma.service';
import { AuditAction, AuditService } from '../audit/audit.service';

export interface DeviceMeta {
  deviceId?: string;
  deviceName?: string;
  platform?: string;
  ip?: string;
  userAgent?: string;
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  accessTokenExpiresIn: number;
  sessionId: string;
}

/** Grace window in which a just-rotated token is rejected without revoking the session (parallel refresh race). */
const REUSE_GRACE_MS = 15_000;

@Injectable()
export class TokenService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly audit: AuditService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  private signAccess(userId: string, sessionId: string) {
    return this.jwt.sign({ sub: userId, sid: sessionId, typ: 'access' }, { expiresIn: this.config.jwt.accessTtlSeconds, algorithm: 'HS256' });
  }

  async createSession(userId: string, meta: DeviceMeta): Promise<TokenPair> {
    const refreshToken = randomToken();
    const session = await this.prisma.session.create({
      data: {
        userId,
        deviceId: meta.deviceId?.slice(0, 128),
        deviceName: meta.deviceName?.slice(0, 120),
        platform: meta.platform?.slice(0, 20),
        ip: meta.ip?.slice(0, 64),
        userAgent: meta.userAgent?.slice(0, 255),
        expiresAt: new Date(Date.now() + this.config.jwt.refreshTtlDays * 86400_000),
        refreshTokens: { create: { tokenHash: sha256(refreshToken) } },
      },
    });
    return {
      accessToken: this.signAccess(userId, session.id),
      refreshToken,
      accessTokenExpiresIn: this.config.jwt.accessTtlSeconds,
      sessionId: session.id,
    };
  }

  async rotate(refreshToken: string, ip?: string): Promise<TokenPair> {
    const token = await this.prisma.refreshToken.findUnique({
      where: { tokenHash: sha256(refreshToken) },
      include: { session: { include: { user: { select: { isActive: true } } } } },
    });
    if (!token) throw unauthorized(ErrorCode.REFRESH_INVALID, 'Invalid refresh token');
    const { session } = token;
    if (session.revokedAt || session.expiresAt < new Date()) throw unauthorized(ErrorCode.REFRESH_INVALID, 'Session expired');
    if (!session.user.isActive) throw unauthorized(ErrorCode.USER_DEACTIVATED, 'User is deactivated');

    if (token.rotatedAt) {
      if (Date.now() - token.rotatedAt.getTime() > REUSE_GRACE_MS) {
        // A rotated token was replayed → assume theft, kill the whole session.
        await this.prisma.session.update({ where: { id: session.id }, data: { revokedAt: new Date(), revokedReason: 'REFRESH_REUSE' } });
        await this.audit.log({ action: AuditAction.REFRESH_REUSE_DETECTED, entityType: 'Session', entityId: session.id, actorUserId: session.userId, ip });
      }
      throw unauthorized(ErrorCode.REFRESH_INVALID, 'Refresh token already used');
    }

    const next = randomToken();
    const rotated = await this.prisma.$transaction(async (tx) => {
      const r = await tx.refreshToken.updateMany({ where: { id: token.id, rotatedAt: null }, data: { rotatedAt: new Date() } });
      if (r.count === 0) return false;
      await tx.refreshToken.create({ data: { sessionId: session.id, tokenHash: sha256(next) } });
      await tx.session.update({ where: { id: session.id }, data: { lastUsedAt: new Date(), ip: ip?.slice(0, 64) } });
      return true;
    });
    if (!rotated) throw unauthorized(ErrorCode.REFRESH_INVALID, 'Refresh token already used');

    return {
      accessToken: this.signAccess(session.userId, session.id),
      refreshToken: next,
      accessTokenExpiresIn: this.config.jwt.accessTtlSeconds,
      sessionId: session.id,
    };
  }

  async revokeSession(sessionId: string, reason: string) {
    await this.prisma.session.updateMany({ where: { id: sessionId, revokedAt: null }, data: { revokedAt: new Date(), revokedReason: reason } });
  }

  async revokeAllForUser(userId: string, reason: string, exceptSessionId?: string) {
    await this.prisma.session.updateMany({
      where: { userId, revokedAt: null, ...(exceptSessionId ? { id: { not: exceptSessionId } } : {}) },
      data: { revokedAt: new Date(), revokedReason: reason },
    });
  }
}
