import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags, ApiTooManyRequestsResponse } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser, ReqMeta } from '../common/decorators/current-user.decorator';
import { Public } from '../common/decorators/public.decorator';
import type { AuthUser, RequestMeta } from '../common/types';
import { AuthService } from './auth.service';
import { RefreshDto, RequestOtpDto, VerifyOtpDto } from './dto/auth.dto';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Public()
  @Post('otp/request')
  @HttpCode(200)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @ApiOperation({ summary: 'Send a 6-digit OTP by SMS (60 s cooldown, 5/hour per phone, 5/min per IP)' })
  @ApiTooManyRequestsResponse({ description: 'OTP_COOLDOWN | OTP_LIMIT_EXCEEDED | RATE_LIMITED' })
  requestOtp(@Body() dto: RequestOtpDto, @ReqMeta() meta: RequestMeta) {
    return this.auth.requestOtp(dto, meta);
  }

  @Public()
  @Post('otp/verify')
  @HttpCode(200)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @ApiOperation({ summary: 'Verify OTP → access + refresh tokens (creates the user on first login)' })
  verifyOtp(@Body() dto: VerifyOtpDto, @ReqMeta() meta: RequestMeta) {
    return this.auth.verifyOtp(dto, meta);
  }

  @Public()
  @Post('refresh')
  @HttpCode(200)
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @ApiOperation({ summary: 'Rotate refresh token. Replaying an old token revokes the session.' })
  refresh(@Body() dto: RefreshDto, @ReqMeta() meta: RequestMeta) {
    return this.auth.refresh(dto.refreshToken, meta);
  }

  @ApiBearerAuth()
  @Post('logout')
  @HttpCode(204)
  @ApiOperation({ summary: 'Revoke the current session' })
  async logout(@CurrentUser() user: AuthUser, @ReqMeta() meta: RequestMeta) {
    await this.auth.logout(user.id, user.sessionId, meta);
  }

  @ApiBearerAuth()
  @Post('logout-all')
  @HttpCode(204)
  @ApiOperation({ summary: 'Revoke all sessions of the user (all devices)' })
  async logoutAll(@CurrentUser() user: AuthUser, @ReqMeta() meta: RequestMeta) {
    await this.auth.logoutAll(user.id, meta);
  }

  @ApiBearerAuth()
  @Get('sessions')
  @ApiOperation({ summary: 'Active sessions (devices)' })
  sessions(@CurrentUser() user: AuthUser) {
    return this.auth.listSessions(user.id, user.sessionId);
  }

  @ApiBearerAuth()
  @Delete('sessions/:sessionId')
  @HttpCode(204)
  async revoke(@CurrentUser() user: AuthUser, @Param('sessionId', ParseUUIDPipe) sessionId: string, @ReqMeta() meta: RequestMeta) {
    await this.auth.revokeSession(user.id, sessionId, meta);
  }
}
