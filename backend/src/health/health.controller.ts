import { Controller, Get, HttpStatus, Res } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { SkipThrottle } from '@nestjs/throttler';
import type { Response } from 'express';
import { Public } from '../common/decorators/public.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  @Public()
  @SkipThrottle()
  @Get()
  async health(@Res() res: Response) {
    let database = false;
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      database = true;
    } catch {
      database = false;
    }
    const storage = await this.storage.ping();
    // Storage outage degrades uploads only; the API stays "up" as long as the DB is reachable.
    res.status(database ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE).json({
      status: database ? (storage ? 'ok' : 'degraded') : 'down',
      database,
      storage,
      time: new Date().toISOString(),
    });
  }
}
