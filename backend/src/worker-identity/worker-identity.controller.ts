import { Controller, Get, Param, ParseUUIDPipe } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CompanyMembership } from '@prisma/client';
import { CompanyRoles, SUPERVISOR_ROLES } from '../common/decorators/company-roles.decorator';
import { CurrentMembership, CurrentUser } from '../common/decorators/current-user.decorator';
import type { AuthUser } from '../common/types';
import { WorkerIdentityService } from './worker-identity.service';

@ApiTags('worker-identity')
@ApiBearerAuth()
@Controller()
export class WorkerIdentityController {
  constructor(private readonly identity: WorkerIdentityService) {}

  @Get('me/identity')
  @ApiOperation({ summary: 'My verified work identity (portable across companies) + self-reported profile' })
  mine(@CurrentUser() user: AuthUser) {
    return this.identity.identity(user.id);
  }

  @Get('companies/:companyId/workers/:userId/identity')
  @CompanyRoles(...SUPERVISOR_ROLES)
  @ApiOperation({ summary: 'Worker identity for members / applicants of this company' })
  forCompany(@CurrentMembership() m: CompanyMembership, @Param('userId', ParseUUIDPipe) userId: string) {
    return this.identity.identityForCompany(m, userId);
  }
}
