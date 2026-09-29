import { Module } from '@nestjs/common';
import { CompaniesController, PlatformAdminController } from './companies.controller';
import { CompaniesService } from './companies.service';

@Module({ controllers: [CompaniesController, PlatformAdminController], providers: [CompaniesService], exports: [CompaniesService] })
export class CompaniesModule {}
