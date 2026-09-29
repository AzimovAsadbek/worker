import { Injectable } from '@nestjs/common';
import { ErrorCode, badRequest, notFound, unauthorized } from '../common/errors';
import { normalizePhone } from '../common/utils/phone';
import type { RequestMeta } from '../common/types';
import { PrismaService } from '../prisma/prisma.service';
import { AuditAction, AuditService } from '../audit/audit.service';
import { OtpService } from './otp.service';
import { TokenService } from './token.service';
import { RequestOtpDto, VerifyOtpDto } from './dto/auth.dto';
import { UsersService } from '../users/users.service';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly otp: OtpService,
    private readonly tokens: TokenService,
    private readonly audit: AuditService,
    private readonly users: UsersService,
  ) {}

  private phoneOrThrow(raw: string) {
    const phone = normalizePhone(raw);
    if (!phone) throw badRequest(ErrorCode.INVALID_PHONE, 'Invalid Uzbek phone number');
    return phone;
  }

  async requestOtp(dto: RequestOtpDto, meta: RequestMeta) {
    const phone = this.phoneOrThrow(dto.phone);
    const result = await this.otp.request(phone, meta.ip);
    return { phone, ...result };
  }

  /** Login == registration: the user record is created on first successful verification. */
  async verifyOtp(dto: VerifyOtpDto, meta: RequestMeta) {
    const phone = this.phoneOrThrow(dto.phone);
    await this.otp.verify(phone, dto.code);

    let user = await this.prisma.user.findUnique({ where: { phone } });
    const isNewUser = !user;
    if (!user) user = await this.prisma.user.create({ data: { phone } });
    if (!user.isActive) throw unauthorized(ErrorCode.USER_DEACTIVATED, 'User is deactivated');
    await this.prisma.user.update({ where: { id: user.id }, data: { lastLoginAt: new Date() } });

    const tokens = await this.tokens.createSession(user.id, { ...dto, ...meta });
    await this.audit.log({
      action: AuditAction.LOGIN,
      entityType: 'User',
      entityId: user.id,
      actorUserId: user.id,
      ip: meta.ip,
      metadata: { platform: dto.platform ?? null, isNewUser },
    });
    return { ...tokens, isNewUser, me: await this.users.getMe(user.id) };
  }

  refresh(refreshToken: string, meta: RequestMeta) {
    return this.tokens.rotate(refreshToken, meta.ip);
  }

  async logout(userId: string, sessionId: string, meta: RequestMeta) {
    await this.tokens.revokeSession(sessionId, 'LOGOUT');
    await this.prisma.deviceToken.deleteMany({ where: { userId } }).catch(() => undefined);
    await this.audit.log({ action: AuditAction.LOGOUT, entityType: 'Session', entityId: sessionId, actorUserId: userId, ip: meta.ip });
  }

  async logoutAll(userId: string, meta: RequestMeta) {
    await this.tokens.revokeAllForUser(userId, 'LOGOUT_ALL');
    await this.prisma.deviceToken.deleteMany({ where: { userId } });
    await this.audit.log({ action: AuditAction.LOGOUT_ALL, entityType: 'User', entityId: userId, actorUserId: userId, ip: meta.ip });
  }

  async listSessions(userId: string, currentSessionId: string) {
    const sessions = await this.prisma.session.findMany({
      where: { userId, revokedAt: null, expiresAt: { gt: new Date() } },
      orderBy: { lastUsedAt: 'desc' },
      select: { id: true, deviceName: true, platform: true, createdAt: true, lastUsedAt: true, ip: true },
    });
    return sessions.map((s) => ({ ...s, isCurrent: s.id === currentSessionId }));
  }

  async revokeSession(userId: string, sessionId: string, meta: RequestMeta) {
    const s = await this.prisma.session.findFirst({ where: { id: sessionId, userId } });
    if (!s) throw notFound('Session');
    await this.tokens.revokeSession(sessionId, 'USER_REVOKED');
    await this.audit.log({ action: AuditAction.SESSION_REVOKED, entityType: 'Session', entityId: sessionId, actorUserId: userId, ip: meta.ip });
  }
}
