import { Inject, Injectable, Logger } from '@nestjs/common';
import { createSign } from 'crypto';
import { APP_CONFIG, AppConfig } from '../config/configuration';

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

export interface PushMessage {
  title: string;
  body: string;
  data?: Record<string, string>;
}

/**
 * Minimal FCM HTTP v1 client (no firebase-admin dependency).
 * Disabled unless FCM_SERVICE_ACCOUNT_BASE64 is configured. Returns tokens that FCM reports as invalid.
 */
@Injectable()
export class FcmSender {
  private readonly logger = new Logger(FcmSender.name);
  private readonly account: ServiceAccount | null;
  private accessToken: { value: string; expiresAt: number } | null = null;

  constructor(@Inject(APP_CONFIG) config: AppConfig) {
    this.account = null;
    if (config.fcmServiceAccountBase64) {
      try {
        const parsed = JSON.parse(Buffer.from(config.fcmServiceAccountBase64, 'base64').toString('utf8')) as ServiceAccount;
        if (parsed.project_id && parsed.client_email && parsed.private_key) this.account = parsed;
        else this.logger.warn('FCM service account is incomplete — push disabled');
      } catch {
        this.logger.warn('FCM service account is not valid base64 JSON — push disabled');
      }
    }
  }

  get enabled() {
    return this.account !== null;
  }

  private async getAccessToken(): Promise<string> {
    if (this.accessToken && this.accessToken.expiresAt > Date.now() + 60_000) return this.accessToken.value;
    const acc = this.account!;
    const now = Math.floor(Date.now() / 1000);
    const b64 = (o: object) => Buffer.from(JSON.stringify(o)).toString('base64url');
    const unsigned = `${b64({ alg: 'RS256', typ: 'JWT' })}.${b64({
      iss: acc.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    })}`;
    const signature = createSign('RSA-SHA256').update(unsigned).sign(acc.private_key).toString('base64url');
    const res = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: `${unsigned}.${signature}` }),
      signal: AbortSignal.timeout(10000),
    });
    if (!res.ok) throw new Error(`Google OAuth failed: HTTP ${res.status}`);
    const json = (await res.json()) as { access_token: string; expires_in: number };
    this.accessToken = { value: json.access_token, expiresAt: Date.now() + json.expires_in * 1000 };
    return json.access_token;
  }

  async send(tokens: string[], msg: PushMessage): Promise<{ invalidTokens: string[] }> {
    if (!this.account || tokens.length === 0) return { invalidTokens: [] };
    const invalidTokens: string[] = [];
    try {
      const accessToken = await this.getAccessToken();
      await Promise.all(
        tokens.map(async (token) => {
          const res = await fetch(`https://fcm.googleapis.com/v1/projects/${this.account!.project_id}/messages:send`, {
            method: 'POST',
            headers: { authorization: `Bearer ${accessToken}`, 'content-type': 'application/json' },
            body: JSON.stringify({
              message: {
                token,
                notification: { title: msg.title, body: msg.body },
                data: msg.data ?? {},
                android: { priority: 'high' },
              },
            }),
            signal: AbortSignal.timeout(10000),
          });
          if (res.status === 404 || res.status === 400) invalidTokens.push(token);
          else if (!res.ok) this.logger.warn(`FCM send failed: HTTP ${res.status}`);
        }),
      );
    } catch (e) {
      this.logger.warn(`FCM unavailable: ${(e as Error).message}`);
    }
    return { invalidTokens };
  }
}
