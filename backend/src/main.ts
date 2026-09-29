import { existsSync } from 'fs';
import { resolve } from 'path';

// Load env files before anything reads process.env (existing variables are never overridden).
const envFiles = new Set([
  resolve(process.cwd(), '.env'),
  resolve(process.cwd(), '../.env'),
  resolve(__dirname, '../.env'), // backend/.env when started as `node backend/dist/main.js`
  resolve(__dirname, '../../.env'), // repository root .env
]);
for (const file of envFiles) {
  if (existsSync(file)) process.loadEnvFile(file);
}

import { NestFactory } from '@nestjs/core';
import { Logger } from 'nestjs-pino';
import { AppModule } from './app.module';
import { configureApp } from './bootstrap';
import { loadConfig } from './config/configuration';

async function bootstrap() {
  const config = loadConfig();
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  app.useLogger(app.get(Logger));
  configureApp(app, config);
  await app.listen(config.port, '0.0.0.0');
  app.get(Logger).log(`Worker OS API listening on :${config.port} (${config.nodeEnv})${config.swaggerEnabled ? ' — docs at /api/docs' : ''}`);
}

void bootstrap();
