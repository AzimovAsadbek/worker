import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsIn, IsOptional, IsString, Length, Matches, MaxLength } from 'class-validator';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

export const INDUSTRIES = ['CONSTRUCTION', 'DELIVERY', 'TRANSPORT', 'CLEANING', 'MANUFACTURING', 'WAREHOUSE', 'AGRICULTURE', 'SERVICES', 'OTHER'];

export class CreateCompanyDto {
  @ApiProperty({ example: 'Taraqqiyot Construction' })
  @Transform(trim)
  @IsString()
  @Length(2, 160)
  name: string;

  @ApiPropertyOptional({ enum: INDUSTRIES, default: 'CONSTRUCTION' })
  @IsOptional()
  @IsIn(INDUSTRIES)
  industry?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(2000)
  description?: string;

  @ApiPropertyOptional({ example: '+998712000000' })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  phone?: string;

  @ApiPropertyOptional({ example: 'Namangan viloyati' })
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(80)
  region?: string;

  @ApiPropertyOptional({ example: 'Namangan' })
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(80)
  city?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(255)
  address?: string;
}

export class UpdateCompanyDto extends CreateCompanyDto {
  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @Length(2, 160)
  declare name: string;
}

export class VerificationRequestDto {
  @ApiProperty({ example: '301234567', description: 'Company STIR (9 digits)' })
  @Matches(/^\d{9}$/, { message: 'registrationNumber must be a 9-digit STIR' })
  registrationNumber: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}

export class VerificationDecisionDto {
  @ApiProperty({ enum: ['VERIFIED', 'REJECTED'] })
  @IsIn(['VERIFIED', 'REJECTED'])
  decision: 'VERIFIED' | 'REJECTED';

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}
