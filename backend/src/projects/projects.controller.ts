import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { CompanyMembership } from '@prisma/client';
import { CompanyRoles, MANAGEMENT_ROLES, SUPERVISOR_ROLES } from '../common/decorators/company-roles.decorator';
import { CurrentMembership, ReqMeta } from '../common/decorators/current-user.decorator';
import type { RequestMeta } from '../common/types';
import { CreateProjectDto, UpdateProjectDto } from './dto/projects.dto';
import { ProjectsService } from './projects.service';

@ApiTags('projects')
@Controller('companies/:companyId/projects')
export class ProjectsController {
  constructor(private readonly projects: ProjectsService) {}

  @Get()
  @CompanyRoles(...SUPERVISOR_ROLES)
  list(@CurrentMembership() m: CompanyMembership) {
    return this.projects.list(m);
  }

  @Post()
  @CompanyRoles(...MANAGEMENT_ROLES)
  create(@CurrentMembership() m: CompanyMembership, @Body() dto: CreateProjectDto, @ReqMeta() meta: RequestMeta) {
    return this.projects.create(m, dto, meta);
  }

  @Get(':projectId')
  @CompanyRoles(...SUPERVISOR_ROLES)
  get(@CurrentMembership() m: CompanyMembership, @Param('projectId', ParseUUIDPipe) id: string) {
    return this.projects.get(m, id);
  }

  @Patch(':projectId')
  @CompanyRoles(...MANAGEMENT_ROLES)
  update(@CurrentMembership() m: CompanyMembership, @Param('projectId', ParseUUIDPipe) id: string, @Body() dto: UpdateProjectDto, @ReqMeta() meta: RequestMeta) {
    return this.projects.update(m, id, dto, meta);
  }

  @Delete(':projectId')
  @HttpCode(204)
  @CompanyRoles(...MANAGEMENT_ROLES)
  async remove(@CurrentMembership() m: CompanyMembership, @Param('projectId', ParseUUIDPipe) id: string, @ReqMeta() meta: RequestMeta) {
    await this.projects.remove(m, id, meta);
  }
}
