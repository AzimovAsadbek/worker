import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService, TokenExpiredError } from '@nestjs/jwt';
import { PrismaService } from '../../prisma/prisma.service';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';
import { ErrorCode, unauthorized } from '../errors';
import type { AuthedRequest } from '../types';

interface AccessPayload {
  sub: string;
  sid: string;
  typ: string;
}

/**
 * Global guard: verifies the access JWT **and** that its session is still valid and the user active,
 * so logout / session revocation / deactivation take effect immediately.
 */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    const req = context.switchToHttp().getRequest<AuthedRequest>();
    const header = req.headers.authorization;
    if (!header || !header.startsWith('Bearer ')) throw unauthorized();
    const token = header.slice(7).trim();

    let payload: AccessPayload;
    try {
      payload = await this.jwt.verifyAsync<AccessPayload>(token, { algorithms: ['HS256'] });
    } catch (e) {
      if (e instanceof TokenExpiredError) throw unauthorized(ErrorCode.TOKEN_EXPIRED, 'Access token expired');
      throw unauthorized(ErrorCode.UNAUTHORIZED, 'Invalid access token');
    }
    if (payload.typ !== 'access' || !payload.sub || !payload.sid) throw unauthorized();

    const session = await this.prisma.session.findUnique({
      where: { id: payload.sid },
      select: { userId: true, revokedAt: true, expiresAt: true, user: { select: { phone: true, isActive: true, isPlatformAdmin: true } } },
    });
    if (!session || session.userId !== payload.sub || session.revokedAt || session.expiresAt < new Date()) {
      throw unauthorized(ErrorCode.SESSION_REVOKED, 'Session is no longer valid');
    }
    if (!session.user.isActive) throw unauthorized(ErrorCode.USER_DEACTIVATED, 'User is deactivated');

    req.user = {
      id: payload.sub,
      sessionId: payload.sid,
      phone: session.user.phone,
      isPlatformAdmin: session.user.isPlatformAdmin,
    };
    return true;
  }
}
