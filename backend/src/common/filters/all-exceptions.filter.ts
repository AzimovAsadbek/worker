import { ArgumentsHost, Catch, ExceptionFilter, HttpException, HttpStatus, Logger } from '@nestjs/common';
import { ThrottlerException } from '@nestjs/throttler';
import { Prisma } from '@prisma/client';
import type { Request, Response } from 'express';
import { ErrorCode } from '../errors';

interface ErrorBody {
  statusCode: number;
  code: string;
  message: string;
  details?: unknown;
  path: string;
  timestamp: string;
}

/**
 * Single error shape for every failure: { statusCode, code, message, details, path, timestamp }.
 * Internal errors never leak stack traces or SQL to clients.
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger('Error');

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();
    const req = ctx.getRequest<Request>();
    const body = this.toBody(exception, req);
    if (body.statusCode >= 500) {
      this.logger.error({ err: exception, path: req.url, method: req.method }, 'Unhandled error');
    }
    res.status(body.statusCode).json(body);
  }

  private toBody(exception: unknown, req: Request): ErrorBody {
    const base = { path: req.url.split('?')[0], timestamp: new Date().toISOString() };

    if (exception instanceof ThrottlerException) {
      return { ...base, statusCode: 429, code: ErrorCode.RATE_LIMITED, message: 'Too many requests' };
    }

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const response = exception.getResponse() as Record<string, unknown> | string;
      if (typeof response === 'object' && response && typeof response.code === 'string') {
        return {
          ...base,
          statusCode: status,
          code: response.code,
          message: String(response.message ?? ''),
          details: response.details,
        };
      }
      // class-validator (ValidationPipe) → message: string[]
      if (status === HttpStatus.BAD_REQUEST && typeof response === 'object' && Array.isArray(response.message)) {
        return {
          ...base,
          statusCode: status,
          code: ErrorCode.VALIDATION_FAILED,
          message: 'Validation failed',
          details: { errors: response.message },
        };
      }
      const message = typeof response === 'string' ? response : String(response.message ?? exception.message);
      return { ...base, statusCode: status, code: this.codeForStatus(status), message };
    }

    if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      if (exception.code === 'P2002') {
        return { ...base, statusCode: 409, code: ErrorCode.CONFLICT, message: 'Resource already exists' };
      }
      if (exception.code === 'P2025') {
        return { ...base, statusCode: 404, code: ErrorCode.NOT_FOUND, message: 'Resource not found' };
      }
    }

    // body-parser / multer errors
    const anyErr = exception as { type?: string; code?: string; status?: number };
    if (anyErr?.type === 'entity.too.large' || anyErr?.code === 'LIMIT_FILE_SIZE') {
      return { ...base, statusCode: 413, code: ErrorCode.FILE_TOO_LARGE, message: 'Payload too large' };
    }
    if (anyErr?.type === 'entity.parse.failed') {
      return { ...base, statusCode: 400, code: ErrorCode.VALIDATION_FAILED, message: 'Malformed JSON body' };
    }

    return { ...base, statusCode: 500, code: ErrorCode.INTERNAL, message: 'Internal server error' };
  }

  private codeForStatus(status: number): string {
    switch (status) {
      case 400:
        return ErrorCode.VALIDATION_FAILED;
      case 401:
        return ErrorCode.UNAUTHORIZED;
      case 403:
        return ErrorCode.FORBIDDEN;
      case 404:
        return ErrorCode.NOT_FOUND;
      case 409:
        return ErrorCode.CONFLICT;
      case 413:
        return ErrorCode.FILE_TOO_LARGE;
      case 429:
        return ErrorCode.RATE_LIMITED;
      default:
        return status >= 500 ? ErrorCode.INTERNAL : 'HTTP_' + status;
    }
  }
}
