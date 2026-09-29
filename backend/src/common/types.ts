import type { CompanyMembership } from '@prisma/client';
import type { Request } from 'express';

export interface AuthUser {
  id: string;
  sessionId: string;
  phone: string;
  isPlatformAdmin: boolean;
}

export interface AuthedRequest extends Request {
  user: AuthUser;
  membership?: CompanyMembership;
}

export interface RequestMeta {
  ip?: string;
  userAgent?: string;
}
