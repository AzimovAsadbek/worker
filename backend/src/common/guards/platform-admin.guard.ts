import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { notFound } from '../errors';
import type { AuthedRequest } from '../types';

/** Platform staff only (company verification). Responds 404 to hide the endpoint from others. */
@Injectable()
export class PlatformAdminGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest<AuthedRequest>();
    if (!req.user?.isPlatformAdmin) throw notFound('Route');
    return true;
  }
}
