/**
 * Serverless entry (Vercel). The Nest app is created once per warm instance and reused.
 * Built by `nest build` into dist/serverless.js and loaded by api/index.js.
 */
import { NestFactory } from '@nestjs/core';
import { ExpressAdapter } from '@nestjs/platform-express';
import express from 'express';
import type { Request, Response } from 'express';
import { Logger } from 'nestjs-pino';
import { configureApp } from './bootstrap';

// Serverless → keep few connections per instance; add PgBouncer mode for pooled URLs (Neon, Supabase).
const dbUrl = process.env.DATABASE_URL;
if (dbUrl && /pooler|pgbouncer/.test(dbUrl) && !/pgbouncer=true/.test(dbUrl)) {
  process.env.DATABASE_URL = `${dbUrl}${dbUrl.includes('?') ? '&' : '?'}pgbouncer=true&connection_limit=5`;
}

let server: Promise<express.Express> | null = null;

async function create(): Promise<express.Express> {
  // Imported lazily so the DATABASE_URL tweak above happens before Prisma is loaded.
  const { AppModule } = await import('./app.module');
  const { loadConfig } = await import('./config/configuration');
  const instance = express();
  const app = await NestFactory.create(AppModule, new ExpressAdapter(instance), { bufferLogs: true });
  app.useLogger(app.get(Logger));
  configureApp(app, loadConfig());
  await app.init();
  return instance;
}

export default async function handler(req: Request, res: Response) {
  server ??= create().catch((e) => {
    server = null;
    throw e;
  });
  const app = await server;
  app(req, res);
}
