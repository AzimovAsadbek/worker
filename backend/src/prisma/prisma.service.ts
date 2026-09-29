import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { Prisma, PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient<Prisma.PrismaClientOptions, 'warn' | 'error'> implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger('Prisma');

  constructor() {
    super({
      log: [
        { emit: 'event', level: 'warn' },
        { emit: 'event', level: 'error' },
      ],
    });
    this.$on('warn', (e) => this.logger.warn(e.message));
    this.$on('error', (e) => {
      // Serialization conflicts are retried by `serializable()`; append-only violations are rethrown to callers.
      if (/write conflict|deadlock|could not serialize/i.test(e.message)) return;
      this.logger.error(e.message);
    });
  }

  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }

  /**
   * Runs `fn` in a SERIALIZABLE transaction and retries on serialization failures / unique races.
   * Used for attendance state transitions where two devices may race.
   */
  async serializable<T>(fn: (tx: Prisma.TransactionClient) => Promise<T>, retries = 4): Promise<T> {
    for (let attempt = 0; ; attempt++) {
      try {
        return await this.$transaction(fn, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable, timeout: 15000 });
      } catch (e) {
        const code = (e as { code?: string }).code;
        const retryable = code === 'P2034' || /could not serialize|write conflict|deadlock/i.test((e as Error).message ?? '');
        if (!retryable || attempt >= retries) throw e;
        await new Promise((r) => setTimeout(r, 20 + Math.random() * 60 * (attempt + 1)));
      }
    }
  }
}
