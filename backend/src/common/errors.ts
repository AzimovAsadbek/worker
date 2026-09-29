import { HttpException, HttpStatus } from '@nestjs/common';

/**
 * Stable, machine-readable error codes. The mobile app maps each code to a specific Uzbek message,
 * so never rename a code — add new ones instead.
 */
export const ErrorCode = {
  // generic
  VALIDATION_FAILED: 'VALIDATION_FAILED',
  UNAUTHORIZED: 'UNAUTHORIZED',
  TOKEN_EXPIRED: 'TOKEN_EXPIRED',
  SESSION_REVOKED: 'SESSION_REVOKED',
  FORBIDDEN: 'FORBIDDEN',
  NOT_FOUND: 'NOT_FOUND',
  CONFLICT: 'CONFLICT',
  RATE_LIMITED: 'RATE_LIMITED',
  INTERNAL: 'INTERNAL',
  // auth
  INVALID_PHONE: 'INVALID_PHONE',
  OTP_COOLDOWN: 'OTP_COOLDOWN',
  OTP_LIMIT_EXCEEDED: 'OTP_LIMIT_EXCEEDED',
  OTP_INVALID: 'OTP_INVALID',
  OTP_EXPIRED: 'OTP_EXPIRED',
  OTP_TOO_MANY_ATTEMPTS: 'OTP_TOO_MANY_ATTEMPTS',
  SMS_SEND_FAILED: 'SMS_SEND_FAILED',
  REFRESH_INVALID: 'REFRESH_INVALID',
  USER_DEACTIVATED: 'USER_DEACTIVATED',
  // tenancy / roles
  NOT_A_MEMBER: 'NOT_A_MEMBER',
  ROLE_NOT_ALLOWED: 'ROLE_NOT_ALLOWED',
  SITE_NOT_ASSIGNED: 'SITE_NOT_ASSIGNED',
  WORKER_NOT_IN_YOUR_SITES: 'WORKER_NOT_IN_YOUR_SITES',
  MEMBER_ALREADY_EXISTS: 'MEMBER_ALREADY_EXISTS',
  CANNOT_MODIFY_SELF: 'CANNOT_MODIFY_SELF',
  LAST_ADMIN: 'LAST_ADMIN',
  // attendance
  NOT_ASSIGNED_TO_SITE: 'NOT_ASSIGNED_TO_SITE',
  SITE_INACTIVE: 'SITE_INACTIVE',
  MEMBERSHIP_INACTIVE: 'MEMBERSHIP_INACTIVE',
  ALREADY_CHECKED_IN: 'ALREADY_CHECKED_IN',
  NO_OPEN_SHIFT: 'NO_OPEN_SHIFT',
  OUTSIDE_GEOFENCE: 'OUTSIDE_GEOFENCE',
  LOCATION_REQUIRED: 'LOCATION_REQUIRED',
  TIMESTAMP_IN_FUTURE: 'TIMESTAMP_IN_FUTURE',
  EVENT_TOO_OLD: 'EVENT_TOO_OLD',
  END_BEFORE_START: 'END_BEFORE_START',
  SHIFT_NOT_REVIEWABLE: 'SHIFT_NOT_REVIEWABLE',
  SHIFT_OPEN: 'SHIFT_OPEN',
  CANNOT_REVIEW_OWN_WORK: 'CANNOT_REVIEW_OWN_WORK',
  // tasks / evidence
  TASK_INVALID_STATE: 'TASK_INVALID_STATE',
  FILE_REQUIRED: 'FILE_REQUIRED',
  FILE_TOO_LARGE: 'FILE_TOO_LARGE',
  FILE_TYPE_NOT_ALLOWED: 'FILE_TYPE_NOT_ALLOWED',
  STORAGE_UNAVAILABLE: 'STORAGE_UNAVAILABLE',
  // marketplace
  VACANCY_NOT_OPEN: 'VACANCY_NOT_OPEN',
  ALREADY_APPLIED: 'ALREADY_APPLIED',
  ALREADY_MEMBER: 'ALREADY_MEMBER',
  BLOCKED_BY_COMPANY: 'BLOCKED_BY_COMPANY',
  APPLICATION_INVALID_STATE: 'APPLICATION_INVALID_STATE',
  // disputes
  DISPUTE_ALREADY_OPEN: 'DISPUTE_ALREADY_OPEN',
  DISPUTE_NOT_OPEN: 'DISPUTE_NOT_OPEN',
} as const;

export type ErrorCode = (typeof ErrorCode)[keyof typeof ErrorCode];

export class AppException extends HttpException {
  constructor(
    public readonly code: ErrorCode,
    message: string,
    status: HttpStatus,
    public readonly details?: Record<string, unknown>,
  ) {
    super({ code, message, details }, status);
  }
}

export const badRequest = (code: ErrorCode, message: string, details?: Record<string, unknown>) =>
  new AppException(code, message, HttpStatus.BAD_REQUEST, details);
export const unprocessable = (code: ErrorCode, message: string, details?: Record<string, unknown>) =>
  new AppException(code, message, HttpStatus.UNPROCESSABLE_ENTITY, details);
export const forbidden = (code: ErrorCode = ErrorCode.FORBIDDEN, message = 'Access denied') =>
  new AppException(code, message, HttpStatus.FORBIDDEN);
export const notFound = (entity = 'Resource') =>
  new AppException(ErrorCode.NOT_FOUND, `${entity} not found`, HttpStatus.NOT_FOUND);
export const conflict = (code: ErrorCode, message: string, details?: Record<string, unknown>) =>
  new AppException(code, message, HttpStatus.CONFLICT, details);
export const unauthorized = (code: ErrorCode = ErrorCode.UNAUTHORIZED, message = 'Authentication required') =>
  new AppException(code, message, HttpStatus.UNAUTHORIZED);
export const tooMany = (code: ErrorCode, message: string, details?: Record<string, unknown>) =>
  new AppException(code, message, HttpStatus.TOO_MANY_REQUESTS, details);
