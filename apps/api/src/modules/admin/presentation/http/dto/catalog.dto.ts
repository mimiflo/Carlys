import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

/** Slug de catégorie : minuscules, chiffres, tirets simples. */
const SLUG = /^[a-z0-9]+(-[a-z0-9]+)*$/u;
const SLUG_MESSAGE = 'doit être en minuscules, sans accent, mots séparés par des tirets';

export class SetExerciseCategoriesDto {
  @ApiProperty({ example: 'pectoraux', description: 'Groupe musculaire PRINCIPAL' })
  @IsString()
  @Matches(SLUG, { message: `primaryMuscleGroupSlug ${SLUG_MESSAGE}` })
  primaryMuscleGroupSlug!: string;

  @ApiProperty({ type: [String], example: ['triceps', 'epaules'] })
  @IsArray()
  @ArrayMaxSize(8)
  @IsString({ each: true })
  @Matches(SLUG, { each: true, message: `secondaryMuscleGroupSlugs ${SLUG_MESSAGE}` })
  secondaryMuscleGroupSlugs!: string[];

  @ApiProperty({ type: [String], example: ['barre', 'banc'] })
  @IsArray()
  @ArrayMaxSize(8)
  @IsString({ each: true })
  @Matches(SLUG, { each: true, message: `equipmentSlugs ${SLUG_MESSAGE}` })
  equipmentSlugs!: string[];
}

export class CreateMuscleGroupDto {
  @ApiProperty({ example: 'trapezes' })
  @IsString()
  @MinLength(2)
  @MaxLength(48)
  @Matches(SLUG, { message: `slug ${SLUG_MESSAGE}` })
  slug!: string;

  @ApiProperty({ example: 'Trapèzes' })
  @IsString()
  @MinLength(2)
  @MaxLength(48)
  name!: string;

  @ApiPropertyOptional({ description: "Rang d'affichage dans la grille", default: 0 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(999)
  sortOrder?: number;
}

export class UpdateMuscleGroupDto {
  @ApiPropertyOptional({ example: 'Trapèzes' })
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(48)
  name?: string;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(999)
  sortOrder?: number;
}
