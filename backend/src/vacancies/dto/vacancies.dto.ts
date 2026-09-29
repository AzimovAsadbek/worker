import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { ApplicationStatus, PaymentPeriod, VacancyStatus } from '@prisma/client';
import { Transform, Type } from 'class-transformer';
import { IsBoolean, IsDateString, IsEnum, IsIn, IsInt, IsLatitude, IsLongitude, IsNumber, IsOptional, IsString, IsUUID, Length, Max, MaxLength, Min } from 'class-validator';
import { PaginationQuery } from '../../common/dto/pagination.dto';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

/** Construction-first trade catalogue (free text is not allowed, so filters stay useful). */
export const VACANCY_CATEGORIES = [
  'GENERAL_LABOR', // Oddiy ishchi (qora ish)
  'BRICKLAYER', // G'isht teruvchi
  'CONCRETE', // Betonchi
  'REBAR', // Armaturachi
  'CARPENTER', // Duradgor / opalubka
  'WELDER', // Payvandchi
  'ELECTRICIAN', // Elektrik
  'PLUMBER', // Santexnik
  'PLASTERER', // Suvoqchi
  'PAINTER', // Bo'yoqchi
  'TILER', // Kafelchi
  'ROOFER', // Tom yopuvchi
  'MACHINE_OPERATOR', // Texnika operatori
  'DRIVER', // Haydovchi
  'CRANE_OPERATOR', // Kran operatori
  'OTHER',
] as const;

export class CreateVacancyDto {
  @ApiProperty({ example: "G'isht teruvchi kerak" })
  @Transform(trim)
  @IsString()
  @Length(3, 160)
  title: string;

  @ApiProperty()
  @Transform(trim)
  @IsString()
  @Length(10, 4000)
  description: string;

  @ApiProperty({ enum: VACANCY_CATEGORIES })
  @IsIn(VACANCY_CATEGORIES)
  category: string;

  @ApiPropertyOptional() @IsOptional() @Transform(trim) @IsString() @MaxLength(80) region?: string;
  @ApiPropertyOptional() @IsOptional() @Transform(trim) @IsString() @MaxLength(80) city?: string;
  @ApiPropertyOptional() @IsOptional() @Transform(trim) @IsString() @MaxLength(255) address?: string;
  @ApiPropertyOptional() @IsOptional() @IsLatitude() latitude?: number;
  @ApiPropertyOptional() @IsOptional() @IsLongitude() longitude?: number;

  @ApiProperty({ example: 250000, description: 'Rate in UZS' })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(1_000_000_000)
  rateAmount: number;

  @ApiProperty({ enum: PaymentPeriod })
  @IsEnum(PaymentPeriod)
  paymentPeriod: PaymentPeriod;

  @ApiPropertyOptional({ default: 1 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(1000)
  workersNeeded?: number;

  @ApiPropertyOptional({ example: '2026-10-10' })
  @IsOptional()
  @IsDateString({ strict: true })
  startDate?: string;

  @ApiPropertyOptional({ example: 60 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(3650)
  durationDays?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(2000)
  requirements?: string;

  @ApiPropertyOptional({ description: 'Site this vacancy is for (required for foremen)' })
  @IsOptional()
  @IsUUID()
  siteId?: string;

  @ApiPropertyOptional({ description: 'Publish immediately (status OPEN)', default: false })
  @IsOptional()
  @IsBoolean()
  publish?: boolean;
}

export class UpdateVacancyDto extends PartialType(CreateVacancyDto) {}

export class VacancyStatusDto {
  @ApiProperty({ enum: [VacancyStatus.OPEN, VacancyStatus.PAUSED, VacancyStatus.CLOSED] })
  @IsIn([VacancyStatus.OPEN, VacancyStatus.PAUSED, VacancyStatus.CLOSED])
  status: VacancyStatus;
}

export class CompanyVacanciesQuery extends PaginationQuery {
  @ApiPropertyOptional({ enum: VacancyStatus })
  @IsOptional()
  @IsEnum(VacancyStatus)
  status?: VacancyStatus;
}

export class BrowseVacanciesQuery extends PaginationQuery {
  @ApiPropertyOptional({ enum: VACANCY_CATEGORIES }) @IsOptional() @IsIn(VACANCY_CATEGORIES) category?: string;
  @ApiPropertyOptional() @IsOptional() @Transform(trim) @IsString() @MaxLength(80) region?: string;
  @ApiPropertyOptional() @IsOptional() @Transform(trim) @IsString() @MaxLength(80) city?: string;
  @ApiPropertyOptional() @IsOptional() @Transform(trim) @IsString() @MaxLength(80) search?: string;
  @ApiPropertyOptional({ enum: ['newest', 'rate'] }) @IsOptional() @IsIn(['newest', 'rate']) sort?: 'newest' | 'rate';
}

export class ApplyDto {
  @ApiPropertyOptional({ example: "5 yillik tajribam bor, ertadan boshlay olaman." })
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(1000)
  coverNote?: string;
}

export class ApplicationStatusDto {
  @ApiProperty({ enum: [ApplicationStatus.SHORTLISTED, ApplicationStatus.ACCEPTED, ApplicationStatus.REJECTED] })
  @IsIn([ApplicationStatus.SHORTLISTED, ApplicationStatus.ACCEPTED, ApplicationStatus.REJECTED])
  status: ApplicationStatus;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(500)
  reason?: string;

  @ApiPropertyOptional({ description: 'On ACCEPTED: assign the new worker to this site' })
  @IsOptional()
  @IsUUID()
  siteId?: string;
}

export class ApplicationsQuery extends PaginationQuery {
  @ApiPropertyOptional({ enum: ApplicationStatus })
  @IsOptional()
  @IsEnum(ApplicationStatus)
  status?: ApplicationStatus;
}
