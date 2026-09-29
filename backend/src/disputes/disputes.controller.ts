import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CompanyMembership } from '@prisma/client';
import { CompanyRoles, SUPERVISOR_ROLES } from '../common/decorators/company-roles.decorator';
import { CurrentMembership, CurrentUser, ReqMeta } from '../common/decorators/current-user.decorator';
import type { AuthUser, RequestMeta } from '../common/types';
import { DisputesService } from './disputes.service';
import { DisputesQuery, OpenDisputeDto, ResolveDisputeDto } from './dto/disputes.dto';

@ApiTags('disputes')
@ApiBearerAuth()
@Controller()
export class DisputesController {
  constructor(private readonly disputes: DisputesService) {}

  @Post('me/shifts/:shiftId/disputes')
  @ApiOperation({ summary: 'Worker disputes own shift (e.g. "I worked until 18:00")' })
  open(@CurrentUser() user: AuthUser, @Param('shiftId', ParseUUIDPipe) shiftId: string, @Body() dto: OpenDisputeDto, @ReqMeta() meta: RequestMeta) {
    return this.disputes.open(user.id, shiftId, dto, meta);
  }

  @Get('me/disputes')
  mine(@CurrentUser() user: AuthUser, @Query() q: DisputesQuery) {
    return this.disputes.mine(user.id, q);
  }

  @Get('companies/:companyId/disputes')
  @CompanyRoles(...SUPERVISOR_ROLES)
  list(@CurrentMembership() m: CompanyMembership, @Query() q: DisputesQuery) {
    return this.disputes.list(m, q);
  }

  @Post('companies/:companyId/disputes/:disputeId/resolve')
  @HttpCode(200)
  @CompanyRoles(...SUPERVISOR_ROLES)
  resolve(@CurrentMembership() m: CompanyMembership, @Param('disputeId', ParseUUIDPipe) id: string, @Body() dto: ResolveDisputeDto, @ReqMeta() meta: RequestMeta) {
    return this.disputes.resolve(m, id, dto, meta);
  }
}
