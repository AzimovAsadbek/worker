import { ApiProperty, ApiPropertyOptional, OmitType, PartialType } from '@nestjs/swagger';
import { SiteStatus } from '@prisma/client';
import { Transform } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsLatitude,
  IsLongitude,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { HHMM_RE } from '../../common/utils/time';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

export class CreateSiteDto {
  @ApiProperty()
  @IsUUID()
  projectId: string;

  @ApiProperty({ example: 'Blok A' })
  @Transform(trim)
  @IsString()
  @Length(2, 160)
  name: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(255)
  address?: string;

  @ApiProperty({ example: 41.0011 })
  @IsLatitude()
  latitude: number;

  @ApiProperty({ example: 71.6726 })
  @IsLongitude()
  longitude: number;

  @ApiPropertyOptional({ default: 200, minimum: 20, maximum: 5000 })
  @IsOptional()
  @IsInt()
  @Min(20)
  @Max(5000)
  radiusMeters?: number;

  @ApiPropertyOptional({ default: 'Asia/Tashkent' })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  timezone?: string;

  @ApiPropertyOptional({ example: '08:00' })
  @IsOptional()
  @Matches(HHMM_RE, { message: 'shiftStart must be HH:mm' })
  shiftStart?: string;

  @ApiPropertyOptional({ example: '18:00' })
  @IsOptional()
  @Matches(HHMM_RE, { message: 'shiftEnd must be HH:mm' })
  shiftEnd?: string;

  @ApiPropertyOptional({ default: 15 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(180)
  lateGraceMinutes?: number;

  @ApiPropertyOptional({ type: [Number], example: [1, 2, 3, 4, 5, 6], description: 'ISO weekdays 1=Mon..7=Sun' })
  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(7)
  @IsInt({ each: true })
  @Min(1, { each: true })
  @Max(7, { each: true })
  workDays?: number[];
}

export class UpdateSiteDto extends PartialType(OmitType(CreateSiteDto, ['projectId'] as const)) {
  @ApiPropertyOptional({ enum: SiteStatus })
  @IsOptional()
  @IsEnum(SiteStatus)
  status?: SiteStatus;
}

export class AssignDto {
  @ApiProperty({ description: 'User id of an active company member (worker or foreman)' })
  @IsUUID()
  userId: string;

  @ApiPropertyOptional({ description: 'Worker lives on site' })
  @IsOptional()
  @IsBoolean()
  isResident?: boolean;
}

export class UpdateAssignmentDto {
  @ApiProperty()
  @IsBoolean()
  isResident: boolean;
}
