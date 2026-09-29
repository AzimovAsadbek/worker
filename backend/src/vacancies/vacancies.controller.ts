import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CompanyMembership } from '@prisma/client';
import { CompanyRoles, SUPERVISOR_ROLES } from '../common/decorators/company-roles.decorator';
import { CurrentMembership, CurrentUser, ReqMeta } from '../common/decorators/current-user.decorator';
import type { AuthUser, RequestMeta } from '../common/types';
import { ApplicationsService } from '../applications/applications.service';
import {
  ApplicationsQuery,
  ApplicationStatusDto,
  ApplyDto,
  BrowseVacanciesQuery,
  CompanyVacanciesQuery,
  CreateVacancyDto,
  UpdateVacancyDto,
  VACANCY_CATEGORIES,
  VacancyStatusDto,
} from './dto/vacancies.dto';
import { VacanciesService } from './vacancies.service';

@ApiTags('vacancies (company)')
@Controller('companies/:companyId')
export class CompanyVacanciesController {
  constructor(
    private readonly vacancies: VacanciesService,
    private readonly applications: ApplicationsService,
  ) {}

  @Post('vacancies')
  @CompanyRoles(...SUPERVISOR_ROLES)
  create(@CurrentMembership() m: CompanyMembership, @Body() dto: CreateVacancyDto, @ReqMeta() meta: RequestMeta) {
    return this.vacancies.create(m, dto, meta);
  }

  @Get('vacancies')
  @CompanyRoles(...SUPERVISOR_ROLES)
  list(@CurrentMembership() m: CompanyMembership, @Query() q: CompanyVacanciesQuery) {
    return this.vacancies.listForCompany(m, q);
  }

  @Get('vacancies/:vacancyId')
  @CompanyRoles(...SUPERVISOR_ROLES)
  get(@CurrentMembership() m: CompanyMembership, @Param('vacancyId', ParseUUIDPipe) id: string) {
    return this.vacancies.getForCompany(m, id);
  }

  @Patch('vacancies/:vacancyId')
  @CompanyRoles(...SUPERVISOR_ROLES)
  update(@CurrentMembership() m: CompanyMembership, @Param('vacancyId', ParseUUIDPipe) id: string, @Body() dto: UpdateVacancyDto, @ReqMeta() meta: RequestMeta) {
    return this.vacancies.update(m, id, dto, meta);
  }

  @Post('vacancies/:vacancyId/status')
  @HttpCode(200)
  @CompanyRoles(...SUPERVISOR_ROLES)
  @ApiOperation({ summary: 'Publish (OPEN) / pause / close a vacancy' })
  status(@CurrentMembership() m: CompanyMembership, @Param('vacancyId', ParseUUIDPipe) id: string, @Body() dto: VacancyStatusDto, @ReqMeta() meta: RequestMeta) {
    return this.vacancies.setStatus(m, id, dto, meta);
  }

  @Get('vacancies/:vacancyId/applications')
  @CompanyRoles(...SUPERVISOR_ROLES)
  @ApiOperation({ summary: "Applicants with their verified identity summary" })
  applicationsFor(@CurrentMembership() m: CompanyMembership, @Param('vacancyId', ParseUUIDPipe) id: string, @Query() q: ApplicationsQuery) {
    return this.applications.listForVacancy(m, id, q);
  }

  @Get('applications/:applicationId')
  @CompanyRoles(...SUPERVISOR_ROLES)
  application(@CurrentMembership() m: CompanyMembership, @Param('applicationId', ParseUUIDPipe) id: string) {
    return this.applications.getForCompany(m, id);
  }

  @Post('applications/:applicationId/status')
  @HttpCode(200)
  @CompanyRoles(...SUPERVISOR_ROLES)
  @ApiOperation({ summary: 'Shortlist / accept (hires the worker) / reject' })
  changeStatus(
    @CurrentMembership() m: CompanyMembership,
    @Param('applicationId', ParseUUIDPipe) id: string,
    @Body() dto: ApplicationStatusDto,
    @ReqMeta() meta: RequestMeta,
  ) {
    return this.applications.changeStatus(m, id, dto, meta);
  }
}

@ApiTags('jobs (worker)')
@ApiBearerAuth()
@Controller()
export class JobsController {
  constructor(
    private readonly vacancies: VacanciesService,
    private readonly applications: ApplicationsService,
  ) {}

  @Get('vacancies')
  @ApiOperation({ summary: 'Browse open vacancies' })
  browse(@CurrentUser() user: AuthUser, @Query() q: BrowseVacanciesQuery) {
    return this.vacancies.browse(user.id, q);
  }

  @Get('vacancies/categories')
  categories() {
    return VACANCY_CATEGORIES;
  }

  @Get('vacancies/:vacancyId')
  detail(@CurrentUser() user: AuthUser, @Param('vacancyId', ParseUUIDPipe) id: string) {
    return this.vacancies.publicDetail(user.id, id);
  }

  @Post('vacancies/:vacancyId/apply')
  apply(@CurrentUser() user: AuthUser, @Param('vacancyId', ParseUUIDPipe) id: string, @Body() dto: ApplyDto, @ReqMeta() meta: RequestMeta) {
    return this.applications.apply(user.id, id, dto, meta);
  }

  @Get('me/applications')
  mine(@CurrentUser() user: AuthUser, @Query() q: ApplicationsQuery) {
    return this.applications.mine(user.id, q);
  }

  @Post('me/applications/:applicationId/withdraw')
  @HttpCode(200)
  withdraw(@CurrentUser() user: AuthUser, @Param('applicationId', ParseUUIDPipe) id: string, @ReqMeta() meta: RequestMeta) {
    return this.applications.withdraw(user.id, id, meta);
  }
}
