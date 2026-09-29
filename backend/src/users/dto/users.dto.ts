import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { WorkerAvailability } from '@prisma/client';
import { Transform } from 'class-transformer';
import { ArrayMaxSize, IsArray, IsEnum, IsIn, IsInt, IsObject, IsOptional, IsString, Length, Max, MaxLength, Min } from 'class-validator';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

export class UpdateMeDto {
  @ApiPropertyOptional({ example: 'Aziz Karimov' })
  @IsOptional()
  @Transform(trim)
  @IsString()
  @Length(2, 120)
  fullName?: string;

  @ApiPropertyOptional({ enum: ['uz', 'ru', 'en'] })
  @IsOptional()
  @IsIn(['uz', 'ru', 'en'])
  locale?: string;
}

export class UpsertWorkerProfileDto {
  @ApiPropertyOptional({ example: "G'isht teruvchi" })
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(80)
  primaryTrade?: string;

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsString({ each: true })
  @MaxLength(80, { each: true })
  trades?: string[];

  @ApiPropertyOptional({ description: 'Self-reported — never mixed with verified data' })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(60)
  selfReportedExperienceYears?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(1000)
  bio?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(80)
  region?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(80)
  city?: string;

  @ApiPropertyOptional({ enum: WorkerAvailability })
  @IsOptional()
  @IsEnum(WorkerAvailability)
  availability?: WorkerAvailability;
}

export class RegisterDeviceDto {
  @ApiProperty({ description: 'FCM registration token' })
  @IsString()
  @Length(10, 4096)
  token: string;

  @ApiProperty({ enum: ['android', 'ios', 'web'] })
  @IsIn(['android', 'ios', 'web'])
  platform: string;
}

export const NOTIFICATION_CATEGORIES = ['shift', 'tasks', 'attendance', 'applications', 'disputes', 'system'] as const;
export type NotificationCategory = (typeof NOTIFICATION_CATEGORIES)[number];

export class NotificationPrefsDto {
  @ApiProperty({
    example: { shift: { push: true, inApp: true }, tasks: { push: false, inApp: true } },
    description: `Per category: ${NOTIFICATION_CATEGORIES.join(', ')}`,
  })
  @IsObject()
  prefs: Record<string, { push?: boolean; inApp?: boolean }>;
}

