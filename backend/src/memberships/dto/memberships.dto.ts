import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { MembershipStatus, Role } from '@prisma/client';
import { Transform } from 'class-transformer';
import { ArrayMaxSize, IsArray, IsBoolean, IsEnum, IsIn, IsOptional, IsString, IsUUID, Length, MaxLength } from 'class-validator';
import { PaginationQuery } from '../../common/dto/pagination.dto';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

export class AddMemberDto {
  @ApiProperty({ example: '+998901234567' })
  @IsString()
  @MaxLength(32)
  phone: string;

  @ApiPropertyOptional({ example: 'Aziz Karimov', description: 'Used only if the user has no name yet' })
  @IsOptional()
  @Transform(trim)
  @IsString()
  @Length(2, 120)
  fullName?: string;

  @ApiProperty({ enum: Role, example: Role.WORKER })
  @IsEnum(Role)
  role: Role;

  @ApiPropertyOptional({ example: "G'isht teruvchi" })
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(80)
  title?: string;

  @ApiPropertyOptional({ type: [String], description: 'Sites to assign immediately (required for foremen adding workers)' })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsUUID('all', { each: true })
  siteIds?: string[];

  @ApiPropertyOptional({ description: 'Worker lives on site (GPS presence ≠ work)' })
  @IsOptional()
  @IsBoolean()
  isResident?: boolean;
}

export class UpdateMemberDto {
  @ApiPropertyOptional({ enum: Role })
  @IsOptional()
  @IsEnum(Role)
  role?: Role;

  @ApiPropertyOptional({ enum: [MembershipStatus.ACTIVE, MembershipStatus.SUSPENDED] })
  @IsOptional()
  @IsIn([MembershipStatus.ACTIVE, MembershipStatus.SUSPENDED])
  status?: MembershipStatus;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(80)
  title?: string;
}

export class ListMembersQuery extends PaginationQuery {
  @ApiPropertyOptional({ enum: Role })
  @IsOptional()
  @IsEnum(Role)
  role?: Role;

  @ApiPropertyOptional({ enum: MembershipStatus, default: MembershipStatus.ACTIVE })
  @IsOptional()
  @IsEnum(MembershipStatus)
  status?: MembershipStatus;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  siteId?: string;

  @ApiPropertyOptional({ description: 'Name or phone fragment' })
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(60)
  search?: string;
}

export class BlockWorkerDto {
  @ApiProperty()
  @IsUUID()
  userId: string;

  @ApiProperty({ description: 'Reason is required — no blocking without explanation' })
  @Transform(trim)
  @IsString()
  @Length(5, 500)
  reason: string;
}

