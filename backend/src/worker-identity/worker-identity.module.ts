import { Global, Module } from '@nestjs/common';
import { WorkerIdentityController } from './worker-identity.controller';
import { WorkerIdentityService } from './worker-identity.service';

@Global()
@Module({ controllers: [WorkerIdentityController], providers: [WorkerIdentityService], exports: [WorkerIdentityService] })
export class WorkerIdentityModule {}
