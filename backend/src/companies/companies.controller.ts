import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { CompanyVerificationStatus, Role } from '@prisma/client';
import { CompanyMembership } from '@prisma/client';
import { CompanyRoles, SUPERVISOR_ROLES } from '../common/decorators/company-roles.decorator';
import { CurrentMembership, CurrentUser, ReqMeta } from '../common/decorators/current-user.decorator';
import { PaginationQuery, paginated } from '../common/dto/pagination.dto';
import { PlatformAdminGuard } from '../common/guards/platform-admin.guard';
import type { AuthUser, RequestMeta } from '../common/types';
import { AuditService } from '../audit/audit.service';
import { CompaniesService } from './companies.service';
import { CreateCompanyDto, UpdateCompanyDto, VerificationDecisionDto, VerificationRequestDto } from './dto/companies.dto';

@ApiTags('companies')
@ApiBearerAuth()
@Controller('companies')
export class CompaniesController {
  constructor(
    private readonly companies: CompaniesService,
    private readonly audit: AuditService,
  ) {}

  @Post()
  @ApiOperation({ summary: 'Create a company; the creator becomes COMPANY_ADMIN' })
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateCompanyDto, @ReqMeta() meta: RequestMeta) {
    return this.companies.create(user.id, dto, meta);
  }

  @Get(':companyId')
  @CompanyRoles(...SUPERVISOR_ROLES, Role.WORKER)
  async get(@Param('companyId') companyId: string, @CurrentMembership() m: CompanyMembership) {
    const company = await this.companies.get(companyId);
    return { ...company, myRole: m.role, myMembershipId: m.id };
  }

  @Patch(':companyId')
  @CompanyRoles(Role.COMPANY_ADMIN)
  update(@Param('companyId') companyId: string, @CurrentUser() user: AuthUser, @Body() dto: UpdateCompanyDto, @ReqMeta() meta: RequestMeta) {
    return this.companies.update(companyId, user.id, dto, meta);
  }

  @Get(':companyId/trust')
  @ApiOperation({ summary: 'Public trust signals of a company (any authenticated user)' })
  trust(@Param('companyId', ParseUUIDPipe) companyId: string) {
    return this.companies.trustSignals(companyId);
  }

  @Post(':companyId/verification-request')
  @CompanyRoles(Role.COMPANY_ADMIN)
  @ApiOperation({ summary: 'Submit company STIR for platform verification' })
  requestVerification(
    @Param('companyId') companyId: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: VerificationRequestDto,
    @ReqMeta() meta: RequestMeta,
  ) {
    return this.companies.requestVerification(companyId, user.id, dto, meta);
  }

  @Get(':companyId/audit-logs')
  @CompanyRoles(Role.COMPANY_ADMIN)
  @ApiQuery({ name: 'action', required: false })
  async auditLogs(@Param('companyId') companyId: string, @Query() q: PaginationQuery, @Query('action') action?: string) {
    const { items, total } = await this.audit.listForCompany(companyId, q.skip, q.limit, action);
    return paginated(items, total, q);
  }
}

@ApiTags('platform-admin')
@ApiBearerAuth()
@UseGuards(PlatformAdminGuard)
@Controller('admin/companies')
export class PlatformAdminController {
  constructor(private readonly companies: CompaniesService) {}

  @Get()
  @ApiQuery({ name: 'status', enum: CompanyVerificationStatus, required: false })
  list(@Query('status') status?: CompanyVerificationStatus) {
    return this.companies.listForVerification(
      status && Object.values(CompanyVerificationStatus).includes(status) ? status : CompanyVerificationStatus.PENDING,
    );
  }

  @Post(':companyId/verification')
  decide(
    @Param('companyId', ParseUUIDPipe) companyId: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: VerificationDecisionDto,
    @ReqMeta() meta: RequestMeta,
  ) {
    return this.companies.decideVerification(companyId, user.id, dto, meta);
  }
}
