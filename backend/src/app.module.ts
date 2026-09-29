import { Module } from '@nestjs/common';
import { APP_FILTER, APP_GUARD } from '@nestjs/core';
import { ScheduleModule } from '@nestjs/schedule';
import { ThrottlerModule } from '@nestjs/throttler';
import { LoggerModule } from 'nestjs-pino';
import { AccessModule } from './access/access.module';
import { AttendanceModule } from './attendance/attendance.module';
import { AuditModule } from './audit/audit.module';
import { AuthModule } from './auth/auth.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import { AppThrottlerGuard } from './common/guards/app-throttler.guard';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { CompaniesModule } from './companies/companies.module';
import { AppConfigModule } from './config/config.module';
import { loadConfig } from './config/configuration';
import { DisputesModule } from './disputes/disputes.module';
import { HealthController } from './health/health.controller';
import { MembershipsModule } from './memberships/memberships.module';
import { NotificationsModule } from './notifications/notifications.module';
import { PrismaModule } from './prisma/prisma.module';
import { ProjectsModule } from './projects/projects.module';
import { SitesModule } from './sites/sites.module';
import { StorageModule } from './storage/storage.module';
import { TasksModule } from './tasks/tasks.module';
import { UsersModule } from './users/users.module';
import { VacanciesModule } from './vacancies/vacancies.module';
import { WorkerIdentityModule } from './worker-identity/worker-identity.module';

const cfg = loadConfig();

/** Human-friendly logs only in development and only when pino-pretty is installed (not in the prod image). */
function prettyTransport() {
  if (cfg.isProduction) return undefined;
  try {
    require.resolve('pino-pretty');
    return { target: 'pino-pretty', options: { singleLine: true } };
  } catch {
    return undefined;
  }
}

@Module({
  imports: [
    LoggerModule.forRoot({
      pinoHttp: {
        level: cfg.logLevel,
        transport: prettyTransport(),
        // Never log secrets, tokens, OTP codes or personal data.
        redact: {
          paths: [
            'req.headers.authorization',
            'req.headers.cookie',
            'req.body.code',
            'req.body.refreshToken',
            'req.body.phone',
            'res.headers["set-cookie"]',
          ],
          censor: '[redacted]',
        },
        serializers: {
          req: (req: { id: string; method: string; url: string }) => ({ id: req.id, method: req.method, url: req.url?.split('?')[0] }),
          res: (res: { statusCode: number }) => ({ statusCode: res.statusCode }),
        },
        autoLogging: { ignore: (req) => req.url === '/api/v1/health' },
      },
    }),
    ThrottlerModule.forRoot({
      throttlers: [{ name: 'default', ttl: 60_000, limit: 120 }],
      // Only for automated tests; refused in production by loadConfig().
      skipIf: () => process.env.THROTTLE_DISABLED === 'true',
    }),
    ScheduleModule.forRoot(),
    AppConfigModule,
    PrismaModule,
    AuditModule,
    AccessModule,
    StorageModule,
    UsersModule,
    NotificationsModule,
    AuthModule,
    CompaniesModule,
    MembershipsModule,
    ProjectsModule,
    SitesModule,
    AttendanceModule,
    TasksModule,
    WorkerIdentityModule,
    VacanciesModule,
    DisputesModule,
  ],
  controllers: [HealthController],
  providers: [
    // Order matters: authenticate first so the throttler can key limits by user id.
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: AppThrottlerGuard },
    { provide: APP_FILTER, useClass: AllExceptionsFilter },
  ],
})
export class AppModule {}
