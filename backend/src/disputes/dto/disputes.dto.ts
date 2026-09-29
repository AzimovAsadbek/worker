import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { DisputeStatus } from '@prisma/client';
import { Transform } from 'class-transformer';
import { IsBoolean, IsEnum, IsISO8601, IsOptional, IsString, Length } from 'class-validator';
import { PaginationQuery } from '../../common/dto/pagination.dto';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

export class OpenDisputeDto {
  @ApiProperty({ example: "Men 18:00 gacha ishladim, lekin 17:00 deb yozilgan." })
  @Transform(trim)
  @IsString()
  @Length(5, 1000)
  reason: string;

  @ApiPropertyOptional({ description: 'What the worker claims the start was' })
  @IsOptional()
  @IsISO8601({ strict: true })
  claimedStart?: string;

  @ApiPropertyOptional({ description: 'What the worker claims the end was' })
  @IsOptional()
  @IsISO8601({ strict: true })
  claimedEnd?: string;
}

export class ResolveDisputeDto {
  @ApiProperty({ description: 'true → apply the claimed (or overridden) times and verify; false → keep the record' })
  @IsBoolean()
  accept: boolean;

  @ApiProperty({ description: "Employer's statement — stored next to the worker's claim" })
  @Transform(trim)
  @IsString()
  @Length(3, 1000)
  resolution: string;

  @ApiPropertyOptional() @IsOptional() @IsISO8601({ strict: true }) correctedStart?: string;
  @ApiPropertyOptional() @IsOptional() @IsISO8601({ strict: true }) correctedEnd?: string;
}

export class DisputesQuery extends PaginationQuery {
  @ApiPropertyOptional({ enum: DisputeStatus })
  @IsOptional()
  @IsEnum(DisputeStatus)
  status?: DisputeStatus;
}
