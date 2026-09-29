import { Inject, Injectable, Logger } from '@nestjs/common';
import { APP_CONFIG, AppConfig } from '../config/configuration';
import { ErrorCode, AppException, badRequest, tooMany } from '../common/errors';
import { hmac, randomOtp, safeEqualHex } from '../common/utils/crypto';
import { maskPhone } from '../common/utils/phone';
import { PrismaService } from '../prisma/prisma.service';
import { SmsProvider } from './sms/sms.provider';
import { HttpStatus } from '@nestjs/common';

@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly sms: SmsProvider,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  private hash(phone: string, code: string) {
    return hmac(this.config.otp.pepper, `${phone}:${code}`);
  }

  async request(phone: string, ip?: string): Promise<{ expiresInSeconds: number; resendInSeconds: number }> {
    const { ttlSeconds, resendCooldownSeconds, maxPerHour } = this.config.otp;
    const now = Date.now();

    const latest = await this.prisma.otpChallenge.findFirst({ where: { phone }, orderBy: { createdAt: 'desc' } });
    if (latest) {
      const elapsed = (now - latest.createdAt.getTime()) / 1000;
      if (elapsed < resendCooldownSeconds) {
        const retryAfter = Math.ceil(resendCooldownSeconds - elapsed);
        throw tooMany(ErrorCode.OTP_COOLDOWN, `Please wait ${retryAfter}s before requesting a new code`, { retryAfterSeconds: retryAfter });
      }
    }
    const lastHour = await this.prisma.otpChallenge.count({ where: { phone, createdAt: { gt: new Date(now - 3600_000) } } });
    if (lastHour >= maxPerHour) {
      throw tooMany(ErrorCode.OTP_LIMIT_EXCEEDED, 'Too many codes requested. Try again later.', { retryAfterSeconds: 3600 });
    }

    const code = this.config.otp.devCode ?? randomOtp();
    // Only the newest challenge is valid.
    await this.prisma.otpChallenge.updateMany({ where: { phone, consumedAt: null }, data: { consumedAt: new Date() } });
    const challenge = await this.prisma.otpChallenge.create({
      data: { phone, codeHash: this.hash(phone, code), expiresAt: new Date(now + ttlSeconds * 1000), ip: ip?.slice(0, 64) },
    });

    try {
      await this.sms.send(phone, `Worker OS tasdiqlash kodi: ${code}. Kodni hech kimga bermang.`);
    } catch (e) {
      await this.prisma.otpChallenge.delete({ where: { id: challenge.id } });
      this.logger.error({ err: (e as Error).message, phone: maskPhone(phone) }, 'SMS send failed');
      throw new AppException(ErrorCode.SMS_SEND_FAILED, 'Could not send SMS. Try again later.', HttpStatus.SERVICE_UNAVAILABLE);
    }
    return { expiresInSeconds: ttlSeconds, resendInSeconds: resendCooldownSeconds };
  }

  /** Verifies and consumes the code. Attempts are counted atomically so parallel guesses cannot exceed the limit. */
  async verify(phone: string, code: string): Promise<void> {
    if (!/^\d{6}$/.test(code)) throw badRequest(ErrorCode.OTP_INVALID, 'Code must be 6 digits');
    const challenge = await this.prisma.otpChallenge.findFirst({
      where: { phone, consumedAt: null },
      orderBy: { createdAt: 'desc' },
    });
    if (!challenge) throw badRequest(ErrorCode.OTP_EXPIRED, 'Code expired. Request a new one.');
    if (challenge.expiresAt < new Date()) throw badRequest(ErrorCode.OTP_EXPIRED, 'Code expired. Request a new one.');

    const { maxAttempts } = this.config.otp;
    const claimed = await this.prisma.otpChallenge.updateMany({
      where: { id: challenge.id, attempts: { lt: maxAttempts }, consumedAt: null },
      data: { attempts: { increment: 1 } },
    });
    if (claimed.count === 0) {
      throw tooMany(ErrorCode.OTP_TOO_MANY_ATTEMPTS, 'Too many wrong attempts. Request a new code.');
    }

    if (!safeEqualHex(challenge.codeHash, this.hash(phone, code))) {
      const attemptsLeft = Math.max(0, maxAttempts - (challenge.attempts + 1));
      if (attemptsLeft === 0) {
        await this.prisma.otpChallenge.update({ where: { id: challenge.id }, data: { consumedAt: new Date() } });
        throw tooMany(ErrorCode.OTP_TOO_MANY_ATTEMPTS, 'Too many wrong attempts. Request a new code.');
      }
      throw badRequest(ErrorCode.OTP_INVALID, 'Wrong code', { attemptsLeft });
    }

    const consumed = await this.prisma.otpChallenge.updateMany({
      where: { id: challenge.id, consumedAt: null },
      data: { consumedAt: new Date() },
    });
    if (consumed.count === 0) throw badRequest(ErrorCode.OTP_EXPIRED, 'Code already used');
  }
}
