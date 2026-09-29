import { applyDecorators, SetMetadata, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiForbiddenResponse, ApiParam } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import { CompanyRolesGuard } from '../guards/company-roles.guard';

export const COMPANY_ROLES_KEY = 'companyRoles';

/**
 * Requires an ACTIVE membership in `:companyId` with one of the given roles.
 * Enforces tenant isolation at the edge; services additionally scope every query by companyId.
 */
export const CompanyRoles = (...roles: Role[]) =>
  applyDecorators(
    SetMetadata(COMPANY_ROLES_KEY, roles),
    UseGuards(CompanyRolesGuard),
    ApiBearerAuth(),
    ApiParam({ name: 'companyId', format: 'uuid' }),
    ApiForbiddenResponse({ description: `Requires role: ${roles.join(' | ')}` }),
  );

export const MANAGEMENT_ROLES: Role[] = [Role.COMPANY_ADMIN, Role.MANAGER];
export const SUPERVISOR_ROLES: Role[] = [Role.COMPANY_ADMIN, Role.MANAGER, Role.FOREMAN];
