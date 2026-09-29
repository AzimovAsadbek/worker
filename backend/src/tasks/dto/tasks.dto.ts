import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ApprovalDecision, TaskStatus } from '@prisma/client';
import { Transform, Type } from 'class-transformer';
import { IsArray, IsDateString, IsEnum, IsIn, IsISO8601, IsLatitude, IsLongitude, IsNumber, IsOptional, IsString, IsUUID, Length, Max, MaxLength, Min } from 'class-validator';
import { PaginationQuery } from '../../common/dto/pagination.dto';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);
export const TASK_UNITS = ['m2', 'm3', 'm', 'pcs', 'kg', 't', 'hours', 'other'];

export class CreateTaskDto {
  @ApiProperty() @IsUUID() siteId: string;
  @ApiProperty({ description: 'Worker user id' }) @IsUUID() assigneeId: string;

  @ApiProperty({ example: "G'isht terish — 3-qavat" })
  @Transform(trim)
  @IsString()
  @Length(2, 160)
  title: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(2000)
  description?: string;

  @ApiPropertyOptional({ example: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(1_000_000)
  quantity?: number;

  @ApiPropertyOptional({ enum: TASK_UNITS, example: 'm2' })
  @IsOptional()
  @IsIn(TASK_UNITS)
  unit?: string;

  @ApiPropertyOptional({ example: '2026-10-05' })
  @IsOptional()
  @IsDateString({ strict: true })
  dueDate?: string;
}

export class ListTasksQuery extends PaginationQuery {
  @ApiPropertyOptional() @IsOptional() @IsUUID() siteId?: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() assigneeId?: string;

  @ApiPropertyOptional({ enum: TaskStatus, isArray: true, description: 'Comma-separated' })
  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? value.split(',').filter(Boolean) : value))
  @IsArray()
  @IsEnum(TaskStatus, { each: true })
  status?: TaskStatus[];
}

export class ReviewTaskDto {
  @ApiProperty({ enum: ApprovalDecision })
  @IsEnum(ApprovalDecision)
  decision: ApprovalDecision;

  @ApiPropertyOptional({ description: 'Required for REJECTED / CHANGES_REQUESTED' })
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(1000)
  comment?: string;
}

export class SubmitTaskDto {
  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(1_000_000)
  completedQuantity?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(1000)
  note?: string;
}

/** Multipart fields accompanying an evidence file. */
export class EvidenceFieldsDto {
  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(1000)
  comment?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsISO8601({ strict: true })
  capturedAt?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsLatitude()
  latitude?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsLongitude()
  longitude?: number;
}
