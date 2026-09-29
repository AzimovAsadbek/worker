import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CompanyMembership, Role } from '@prisma/client';
import { CompanyRoles, MANAGEMENT_ROLES, SUPERVISOR_ROLES } from '../common/decorators/company-roles.decorator';
import { CurrentMembership, ReqMeta } from '../common/decorators/current-user.decorator';
import type { RequestMeta } from '../common/types';
import { AddMemberDto, BlockWorkerDto, ListMembersQuery, UpdateMemberDto } from './dto/memberships.dto';
import { MembershipsService } from './memberships.service';

@ApiTags('members')
@Controller('companies/:companyId')
export class MembershipsController {
  constructor(private readonly members: MembershipsService) {}

  @Get('members')
  @CompanyRoles(...SUPERVISOR_ROLES)
  @ApiOperation({ summary: 'List members. Foremen see only workers of their sites.' })
  list(@CurrentMembership() m: CompanyMembership, @Query() q: ListMembersQuery) {
    return this.members.list(m, q);
  }

  @Post('members')
  @CompanyRoles(...SUPERVISOR_ROLES)
  @ApiOperation({ summary: 'Add a member by phone. Foremen may add only WORKERs to their own sites.' })
  add(@CurrentMembership() m: CompanyMembership, @Body() dto: AddMemberDto, @ReqMeta() meta: RequestMeta) {
    return this.members.add(m, dto, meta);
  }

  @Get('members/:memberId')
  @CompanyRoles(...SUPERVISOR_ROLES)
  get(@CurrentMembership() m: CompanyMembership, @Param('memberId', ParseUUIDPipe) id: string) {
    return this.members.get(m, id);
  }

  @Patch('members/:memberId')
  @CompanyRoles(...MANAGEMENT_ROLES)
  update(@CurrentMembership() m: CompanyMembership, @Param('memberId', ParseUUIDPipe) id: string, @Body() dto: UpdateMemberDto, @ReqMeta() meta: RequestMeta) {
    return this.members.update(m, id, dto, meta);
  }

  @Delete('members/:memberId')
  @HttpCode(204)
  @CompanyRoles(...MANAGEMENT_ROLES)
  @ApiOperation({ summary: 'Remove from company (history is preserved)' })
  async remove(@CurrentMembership() m: CompanyMembership, @Param('memberId', ParseUUIDPipe) id: string, @ReqMeta() meta: RequestMeta) {
    await this.members.remove(m, id, meta);
  }

  @Get('blocks')
  @CompanyRoles(...MANAGEMENT_ROLES)
  blocks(@Param('companyId') companyId: string) {
    return this.members.listBlocks(companyId);
  }

  @Post('blocks')
  @CompanyRoles(...MANAGEMENT_ROLES)
  @ApiOperation({ summary: "Block a worker from this company's vacancies (company-local, reason required)" })
  block(@CurrentMembership() m: CompanyMembership, @Body() dto: BlockWorkerDto, @ReqMeta() meta: RequestMeta) {
    return this.members.block(m, dto, meta);
  }

  @Delete('blocks/:userId')
  @HttpCode(204)
  @CompanyRoles(Role.COMPANY_ADMIN, Role.MANAGER)
  async unblock(@CurrentMembership() m: CompanyMembership, @Param('userId', ParseUUIDPipe) userId: string, @ReqMeta() meta: RequestMeta) {
    await this.members.unblock(m, userId, meta);
  }
}
