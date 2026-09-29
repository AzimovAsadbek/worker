import { Inject, Injectable, Logger } from '@nestjs/common';
import { APP_CONFIG, AppConfig } from '../../config/configuration';
import { maskPhone } from '../../common/utils/phone';

export abstract class SmsProvider {
  abstract send(phone: string, text: string): Promise<void>;
}

/** Development provider: sends nothing. The fixed OTP_DEV_CODE is accepted instead. Never logs codes. */
@Injectable()
export class DevSmsProvider extends SmsProvider {
  private readonly logger = new Logger('DevSms');
  async send(phone: string): Promise<void> {
    this.logger.log(`[dev] OTP issued for ${maskPhone(phone)} (use OTP_DEV_CODE)`);
  }
}

/**
 * Eskiz.uz SMS gateway (popular Uzbek provider).
 * Auth: POST /api/auth/login (email, password) → bearer token (cached, refreshed on 401).
 * Send: POST /api/message/sms/send (mobile_phone without '+', message, from).
 * NOTE: Eskiz requires message templates to be approved on their side before production use.
 */
@Injectable()
export class EskizSmsProvider extends SmsProvider {
  private readonly logger = new Logger('EskizSms');
  private token: string | null = null;
  private readonly base = 'https://notify.eskiz.uz/api';

  constructor(@Inject(APP_CONFIG) private readonly config: AppConfig) {
    super();
  }

  private async login(): Promise<string> {
    const form = new FormData();
    form.set('email', this.config.eskiz.email);
    form.set('password', this.config.eskiz.password);
    const res = await fetch(`${this.base}/auth/login`, { method: 'POST', body: form, signal: AbortSignal.timeout(10000) });
    if (!res.ok) throw new Error(`Eskiz login failed: HTTP ${res.status}`);
    const json = (await res.json()) as { data?: { token?: string } };
    if (!json.data?.token) throw new Error('Eskiz login: no token');
    this.token = json.data.token;
    return this.token;
  }

  async send(phone: string, text: string): Promise<void> {
    const attempt = async (token: string) => {
      const form = new FormData();
      form.set('mobile_phone', phone.replace('+', ''));
      form.set('message', text);
      form.set('from', this.config.eskiz.from);
      return fetch(`${this.base}/message/sms/send`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        body: form,
        signal: AbortSignal.timeout(10000),
      });
    };
    let res = await attempt(this.token ?? (await this.login()));
    if (res.status === 401) res = await attempt(await this.login());
    if (!res.ok) {
      this.logger.error(`Eskiz send failed for ${maskPhone(phone)}: HTTP ${res.status}`);
      throw new Error(`SMS send failed: HTTP ${res.status}`);
    }
  }
}
