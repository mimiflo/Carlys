import { PROGRAM_MAX_DAYS, PROGRAM_MAX_WEEKS } from '@carlys/api-contracts';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';

export class ListProgramsQuery {
  @ApiPropertyOptional({ description: 'Curseur : id du dernier élément servi' })
  @IsOptional()
  @IsUUID()
  cursor?: string;

  @ApiPropertyOptional({ default: 20, maximum: 100 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit: number = 20;
}

export class SaveProgramDayDto {
  @ApiProperty({ description: 'UUID fourni par l’appareil' })
  @IsUUID()
  id!: string;

  @ApiProperty({ minimum: 1, maximum: PROGRAM_MAX_WEEKS })
  @IsInt()
  @Min(1)
  @Max(PROGRAM_MAX_WEEKS)
  weekNumber!: number;

  @ApiProperty({ minimum: 1, maximum: 7, description: '1 = lundi … 7 = dimanche' })
  @IsInt()
  @Min(1)
  @Max(7)
  dayOfWeek!: number;

  @ApiPropertyOptional({ nullable: true })
  @IsOptional()
  @IsUUID()
  templateId?: string | null;

  @ApiPropertyOptional({ description: 'Déduit du contexte s’il est absent' })
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  label?: string;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isRest?: boolean;
}

/** Corps du `PUT` : l'état COMPLET du programme, pas un correctif. */
export class SaveProgramDto {
  @ApiProperty()
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  name!: string;

  @ApiPropertyOptional({ nullable: true })
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string | null;

  @ApiProperty({ minimum: 1, maximum: PROGRAM_MAX_WEEKS })
  @IsInt()
  @Min(1)
  @Max(PROGRAM_MAX_WEEKS)
  weeksCount!: number;

  @ApiPropertyOptional({ description: 'Programme suivi en ce moment (un seul)' })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @ApiProperty({ type: [SaveProgramDayDto], maxItems: PROGRAM_MAX_DAYS })
  @IsArray()
  @ArrayMaxSize(PROGRAM_MAX_DAYS)
  @ValidateNested({ each: true })
  @Type(() => SaveProgramDayDto)
  days!: SaveProgramDayDto[];
}
