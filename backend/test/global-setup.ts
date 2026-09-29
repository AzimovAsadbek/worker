import { execSync } from 'child_process';
import { existsSync } from 'fs';
import { resolve } from 'path';

export default async function globalSetup() {
  for (const file of [resolve(__dirname, '../.env'), resolve(__dirname, '../../.env')]) {
    if (existsSync(file)) process.loadEnvFile(file);
  }
  const url = process.env.TEST_DATABASE_URL;
  if (!url || !/_test\b/.test(url)) throw new Error('Refusing to migrate: TEST_DATABASE_URL must point to a *_test database');
  execSync('npx prisma migrate deploy', { cwd: resolve(__dirname, '..'), env: { ...process.env, DATABASE_URL: url }, stdio: 'pipe' });
}
