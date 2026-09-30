/**
 * Typed, validated configuration. The app refuses to boot with missing/unsafe secrets.
 */
export interface AppConfig {
  nodeEnv: string;
  isProduction: boolean;
  port: number;
  corsOrigins: string[];
  trustProxy: number;
  swaggerEnabled: boolean;
  logLevel: string;
  jwt: { accessSecret: string; accessTtlSeconds: number; refreshTtlDays: number };
  otp: {
    pepper: string;
    provider: 'dev' | 'eskiz';
    devCode: string | null;
    ttlSeconds: number;
    maxAttempts: number;
    resendCooldownSeconds: number;
    maxPerHour: number;
  };
  eskiz: { email: string; password: string; from: string };
  s3: {
    endpoint: string;
    region: string;
    bucket: string;
    accessKey: string;
    secretKey: string;
    forcePathStyle: boolean;
  };
  storageDriver: 's3' | 'database';
  cronSecret: string | null;
  uploadMaxBytes: number;
  fcmServiceAccountBase64: string | null;
  jobsEnabled: boolean;
}

function required(env: NodeJS.ProcessEnv, key: string): string {
  const v = env[key];
  if (!v || !v.trim()) throw new Error(`Missing required environment variable ${key}`);
  return v.trim();
}

function int(env: NodeJS.ProcessEnv, key: string, def: number): number {
  const raw = env[key];
  if (raw === undefined || raw === '') return def;
  const n = Number(raw);
  if (!Number.isFinite(n)) throw new Error(`Environment variable ${key} must be a number`);
  return n;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const nodeEnv = env.NODE_ENV ?? 'development';
  const isProduction = nodeEnv === 'production';

  const accessSecret = required(env, 'JWT_ACCESS_SECRET');
  if (accessSecret.length < 32) throw new Error('JWT_ACCESS_SECRET must be at least 32 characters');
  const pepper = required(env, 'OTP_PEPPER');
  if (pepper.length < 16) throw new Error('OTP_PEPPER must be at least 16 characters');

  if (isProduction && env.THROTTLE_DISABLED === 'true') throw new Error('THROTTLE_DISABLED is not allowed in production');

  const provider = (env.SMS_PROVIDER ?? 'dev') as 'dev' | 'eskiz';
  if (!['dev', 'eskiz'].includes(provider)) throw new Error('SMS_PROVIDER must be dev or eskiz');
  const devCode = env.OTP_DEV_CODE?.trim() || null;
  if (provider === 'dev') {
    if (isProduction && env.ALLOW_DEV_OTP_IN_PRODUCTION !== 'true') {
      throw new Error('SMS_PROVIDER=dev is not allowed in production (set SMS_PROVIDER=eskiz)');
    }
    if (!devCode || !/^\d{6}$/.test(devCode)) throw new Error('OTP_DEV_CODE must be 6 digits when SMS_PROVIDER=dev');
  }

  return {
    nodeEnv,
    isProduction,
    port: int(env, 'PORT', 3000),
    corsOrigins: (env.CORS_ORIGINS ?? '')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean),
    trustProxy: int(env, 'TRUST_PROXY', 0),
    swaggerEnabled: (env.SWAGGER_ENABLED ?? (isProduction ? 'false' : 'true')) === 'true',
    logLevel: env.LOG_LEVEL ?? 'info',
    jwt: {
      accessSecret,
      accessTtlSeconds: int(env, 'JWT_ACCESS_TTL_SECONDS', 900),
      refreshTtlDays: int(env, 'REFRESH_TOKEN_TTL_DAYS', 30),
    },
    otp: {
      pepper,
      provider,
      devCode: provider === 'dev' ? devCode : null,
      ttlSeconds: int(env, 'OTP_TTL_SECONDS', 300),
      maxAttempts: int(env, 'OTP_MAX_ATTEMPTS', 5),
      resendCooldownSeconds: int(env, 'OTP_RESEND_COOLDOWN_SECONDS', 60),
      maxPerHour: int(env, 'OTP_MAX_PER_HOUR', 5),
    },
    eskiz: {
      email: env.ESKIZ_EMAIL ?? '',
      password: env.ESKIZ_PASSWORD ?? '',
      from: env.ESKIZ_FROM ?? '4546',
    },
    s3: {
      endpoint: env.S3_ENDPOINT ?? '',
      region: env.S3_REGION ?? 'us-east-1',
      bucket: env.S3_BUCKET ?? 'worker-evidence',
      accessKey: env.S3_ACCESS_KEY ?? '',
      secretKey: env.S3_SECRET_KEY ?? '',
      forcePathStyle: (env.S3_FORCE_PATH_STYLE ?? 'true') === 'true',
    },
    storageDriver: (env.STORAGE_DRIVER ?? 's3') === 'database' ? 'database' : 's3',
    cronSecret: env.CRON_SECRET?.trim() || null,
    uploadMaxBytes: int(env, 'UPLOAD_MAX_BYTES', 8 * 1024 * 1024),
    fcmServiceAccountBase64: env.FCM_SERVICE_ACCOUNT_BASE64?.trim() || null,
    jobsEnabled: (env.JOBS_ENABLED ?? 'true') === 'true',
  };
}

export const APP_CONFIG = Symbol('APP_CONFIG');
