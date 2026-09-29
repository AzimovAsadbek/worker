import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { MembershipStatus, Role } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { COMPANY_ROLES_KEY } from '../decorators/company-roles.decorator';
import { ErrorCode, forbidden, notFound } from '../errors';
import type { AuthedRequest } from '../types';
import { isUuid } from '../utils/ids';

@Injectable()
export class CompanyRolesGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const roles = this.reflector.getAllAndOverride<Role[]>(COMPANY_ROLES_KEY, [context.getHandler(), context.getClass()]) ?? [];
    const req = context.switchToHttp().getRequest<AuthedRequest>();
    const companyId = req.params.companyId;
    if (!companyId || !isUuid(companyId)) throw notFound('Company');

    const membership = await this.prisma.companyMembership.findUnique({
      where: { companyId_userId: { companyId, userId: req.user.id } },
      include: { company: { select: { deletedAt: true } } },
    });
    // Non-members get 404 (not 403) so company ids cannot be enumerated.
    if (!membership || membership.company.deletedAt) throw notFound('Company');
    if (membership.status !== MembershipStatus.ACTIVE) throw forbidden(ErrorCode.NOT_A_MEMBER, 'Membership is not active');
    if (roles.length && !roles.includes(membership.role)) {
      throw forbidden(ErrorCode.ROLE_NOT_ALLOWED, `This action requires role: ${roles.join(', ')}`);
    }
    const { company: _company, ...plain } = membership;
    req.membership = plain;
    return true;
  }
}
