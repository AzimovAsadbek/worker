import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ShiftStatus } from '@prisma/client';
import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsEnum,
  IsIn,
  IsInt,
  IsISO8601,
  IsLatitude,
  IsLongitude,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Matches,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { PaginationQuery } from '../../common/dto/pagination.dto';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

export const ATTENDANCE_EVENT_TYPES = ['WORK_STARTED', 'WORK_ENDED'] as const;
export type AttendanceEventType = (typeof ATTENDANCE_EVENT_TYPES)[number];

export class SyncEventDto {
  @ApiProperty({ description: 'Idempotency key generated on the device (UUID)', example: '5b6f9f0e-3c1a-4b7e-9a51-0e0d7c1f1a11' })
  @IsString()
  @Matches(/^[A-Za-z0-9-]{8,64}$/)
  clientEventId: string;

  @ApiProperty({ enum: ATTENDANCE_EVENT_TYPES })
  @IsIn(ATTENDANCE_EVENT_TYPES)
  type: AttendanceEventType;

  @ApiProperty()
  @IsUUID()
  siteId: string;

  @ApiProperty({ description: 'Device time of the tap (ISO 8601 with offset)' })
  @IsISO8601({ strict: true })
  occurredAt: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsLatitude()
  latitude?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsLongitude()
  longitude?: number;

  @ApiPropertyOptional({ description: 'GPS accuracy radius in meters' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100000)
  accuracy?: number;

  @ApiPropertyOptional({ description: 'Android "mock location" flag reported by the OS' })
  @IsOptional()
  @IsBoolean()
  isMocked?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Length(8, 128)
  deviceId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(500)
  note?: string;
}

export class SyncEventsDto {
  @ApiProperty({ type: [SyncEventDto], maxItems: 50 })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => SyncEventDto)
  events: SyncEventDto[];
}

export class ManualEventDto {
  @ApiProperty()
  @IsUUID()
  workerId: string;

  @ApiProperty()
  @IsUUID()
  siteId: string;

  @ApiProperty({ enum: ATTENDANCE_EVENT_TYPES })
  @IsIn(ATTENDANCE_EVENT_TYPES)
  type: AttendanceEventType;

  @ApiProperty()
  @IsISO8601({ strict: true })
  occurredAt: string;

  @ApiProperty({ description: 'Why the entry is manual (worker has no phone, phone broken, …)' })
  @Transform(trim)
  @IsString()
  @Length(3, 500)
  reason: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Matches(/^[A-Za-z0-9-]{8,64}$/)
  clientEventId?: string;
}

export class ListShiftsQuery extends PaginationQuery {
  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  siteId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  workerId?: string;

  @ApiPropertyOptional({ enum: ShiftStatus, isArray: true, description: 'Comma-separated' })
  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? value.split(',').filter(Boolean) : value))
  @IsArray()
  @IsEnum(ShiftStatus, { each: true })
  status?: ShiftStatus[];

  @ApiPropertyOptional({ example: '2026-09-01' })
  @IsOptional()
  @IsDateString({ strict: true })
  from?: string;

  @ApiPropertyOptional({ example: '2026-09-30' })
  @IsOptional()
  @IsDateString({ strict: true })
  to?: string;

  @ApiPropertyOptional({ description: 'Only shifts with anomaly flags' })
  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  @IsBoolean()
  flagged?: boolean;
}

export class MyShiftsQuery extends PaginationQuery {
  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString({ strict: true })
  from?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString({ strict: true })
  to?: string;
}

export class VerifyShiftDto {
  @ApiPropertyOptional({ default: 0, description: 'Unpaid break minutes to subtract' })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(600)
  breakMinutes?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(500)
  note?: string;
}

export class BulkVerifyDto {
  @ApiProperty({ type: [String] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(200)
  @IsUUID('all', { each: true })
  shiftIds: string[];
}

export class RejectShiftDto {
  @ApiProperty({ description: 'Required — the worker sees it and can dispute' })
  @Transform(trim)
  @IsString()
  @Length(3, 500)
  reason: string;
}

export class CorrectShiftDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsISO8601({ strict: true })
  startedAt?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsISO8601({ strict: true })
  endedAt?: string;

  @ApiProperty({ description: 'Required — stored with the original values' })
  @Transform(trim)
  @IsString()
  @Length(3, 500)
  reason: string;

  @ApiPropertyOptional({ description: 'Verify immediately after correcting' })
  @IsOptional()
  @IsBoolean()
  verify?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(600)
  breakMinutes?: number;
}

export class DashboardQuery {
  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  siteId?: string;
}
