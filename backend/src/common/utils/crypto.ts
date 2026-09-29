import { createHash, createHmac, randomBytes, randomInt, timingSafeEqual } from 'crypto';

export const sha256 = (data: string | Buffer) => createHash('sha256').update(data).digest('hex');
export const hmac = (secret: string, data: string) => createHmac('sha256', secret).update(data).digest('hex');
export const randomToken = (bytes = 48) => randomBytes(bytes).toString('base64url');
export const randomOtp = () => randomInt(0, 1_000_000).toString().padStart(6, '0');

export function safeEqualHex(a: string, b: string): boolean {
  const ba = Buffer.from(a, 'hex');
  const bb = Buffer.from(b, 'hex');
  return ba.length === bb.length && timingSafeEqual(ba, bb);
}
