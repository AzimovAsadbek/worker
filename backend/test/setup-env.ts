import { existsSync } from 'fs';
import { resolve } from 'path';

for (const file of [resolve(__dirname, '../.env'), resolve(__dirname, '../../.env')]) {
  if (existsSync(file)) process.loadEnvFile(file);
}
if (!process.env.TEST_DATABASE_URL) throw new Error('TEST_DATABASE_URL is required for e2e tests');
if (process.env.TEST_DATABASE_URL === process.env.DATABASE_URL) throw new Error('TEST_DATABASE_URL must differ from DATABASE_URL');
process.env.DATABASE_URL = process.env.TEST_DATABASE_URL;
process.env.NODE_ENV = 'test';
process.env.SMS_PROVIDER = 'dev';
process.env.OTP_DEV_CODE = '111111';
process.env.JOBS_ENABLED = 'false';
process.env.LOG_LEVEL = 'silent';
process.env.S3_BUCKET = 'worker-evidence-test';
process.env.UPLOAD_MAX_BYTES = String(512 * 1024);
process.env.SWAGGER_ENABLED = 'false';
process.env.THROTTLE_DISABLED = 'true';
