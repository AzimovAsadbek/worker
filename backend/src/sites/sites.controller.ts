import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiQuery, ApiTags } from '@nestjs/swagger';
import { CompanyMembership } from '@prisma/client';
import { CompanyRoles, MANAGEMENT_ROLES, SUPERVISOR_ROLES } from '../common/decorators/company-roles.decorator';
import { CurrentMembership, ReqMeta } from '../common/decorators/current-user.decorator';
import { isUuid } from '../common/utils/ids';
import type { RequestMeta } from '../common/types';
import { AssignDto, CreateSiteDto, UpdateAssignmentDto, UpdateSiteDto } from './dto/sites.dto';
import { SitesService } from './sites.service';

@ApiTags('sites')
@Controller('companies/:companyId/sites')
export class SitesController {
  constructor(private readonly sites: SitesService) {}

  @Get()
  @CompanyRoles(...SUPERVISOR_ROLES)
  @ApiQuery({ name: 'projectId', required: false })
  list(@CurrentMembership() m: CompanyMembership, @Query('projectId') projectId?: string) {
    return this.sites.list(m, isUuid(projectId) ? projectId : undefined);
  }

  @Post()
  @CompanyRoles(...MANAGEMENT_ROLES)
  create(@CurrentMembership() m: CompanyMembership, @Body() dto: CreateSiteDto, @ReqMeta() meta: RequestMeta) {
    return this.sites.create(m, dto, meta);
  }

  @Get(':siteId')
  @CompanyRoles(...SUPERVISOR_ROLES)
  get(@CurrentMembership() m: CompanyMembership, @Param('siteId', ParseUUIDPipe) id: string) {
    return this.sites.get(m, id);
  }

  @Patch(':siteId')
  @CompanyRoles(...MANAGEMENT_ROLES)
  update(@CurrentMembership() m: CompanyMembership, @Param('siteId', ParseUUIDPipe) id: string, @Body() dto: UpdateSiteDto, @ReqMeta() meta: RequestMeta) {
    return this.sites.update(m, id, dto, meta);
  }

  @Delete(':siteId')
  @HttpCode(204)
  @CompanyRoles(...MANAGEMENT_ROLES)
  async remove(@CurrentMembership() m: CompanyMembership, @Param('siteId', ParseUUIDPipe) id: string, @ReqMeta() meta: RequestMeta) {
    await this.sites.remove(m, id, meta);
  }

  @Get(':siteId/assignments')
  @CompanyRoles(...SUPERVISOR_ROLES)
  assignments(@CurrentMembership() m: CompanyMembership, @Param('siteId', ParseUUIDPipe) id: string) {
    return this.sites.listAssignments(m, id);
  }

  @Post(':siteId/assignments')
  @CompanyRoles(...SUPERVISOR_ROLES)
  assign(@CurrentMembership() m: CompanyMembership, @Param('siteId', ParseUUIDPipe) id: string, @Body() dto: AssignDto, @ReqMeta() meta: RequestMeta) {
    return this.sites.assign(m, id, dto, meta);
  }

  @Patch(':siteId/assignments/:assignmentId')
  @CompanyRoles(...SUPERVISOR_ROLES)
  updateAssignment(
    @CurrentMembership() m: CompanyMembership,
    @Param('siteId', ParseUUIDPipe) id: string,
    @Param('assignmentId', ParseUUIDPipe) aid: string,
    @Body() dto: UpdateAssignmentDto,
  ) {
    return this.sites.updateAssignment(m, id, aid, dto);
  }

  @Delete(':siteId/assignments/:assignmentId')
  @HttpCode(204)
  @CompanyRoles(...SUPERVISOR_ROLES)
  async unassign(
    @CurrentMembership() m: CompanyMembership,
    @Param('siteId', ParseUUIDPipe) id: string,
    @Param('assignmentId', ParseUUIDPipe) aid: string,
    @ReqMeta() meta: RequestMeta,
  ) {
    await this.sites.unassign(m, id, aid, meta);
  }
}
