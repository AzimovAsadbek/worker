import { Module } from '@nestjs/common';
import { ApplicationsService } from '../applications/applications.service';
import { CompaniesModule } from '../companies/companies.module';
import { CompanyVacanciesController, JobsController } from './vacancies.controller';
import { VacanciesService } from './vacancies.service';

@Module({
  imports: [CompaniesModule],
  controllers: [CompanyVacanciesController, JobsController],
  providers: [VacanciesService, ApplicationsService],
})
export class VacanciesModule {}
