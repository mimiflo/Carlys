import { DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE } from '@carlys/shared-config';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { ExerciseDifficulty, ExerciseType } from '@prisma/client';
import { Transform, Type } from 'class-transformer';
import {
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

const SLUG_PATTERN = /^[a-z0-9-]+$/;

export class ListExercisesQuery {
  @ApiPropertyOptional({ description: 'Recherche sur le nom ou un tag', maxLength: 100 })
  @IsOptional()
  @IsString()
  @Transform(({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value))
  @MaxLength(100)
  search?: string;

  @ApiPropertyOptional({ description: 'Slug du groupe musculaire', example: 'pectoraux' })
  @IsOptional()
  @IsString()
  @Matches(SLUG_PATTERN)
  muscleGroup?: string;

  @ApiPropertyOptional({ description: "Slug de l'équipement", example: 'halteres' })
  @IsOptional()
  @IsString()
  @Matches(SLUG_PATTERN)
  equipment?: string;

  @ApiPropertyOptional({ enum: ExerciseDifficulty })
  @IsOptional()
  @IsEnum(ExerciseDifficulty)
  difficulty?: ExerciseDifficulty;

  @ApiPropertyOptional({ enum: ExerciseType })
  @IsOptional()
  @IsEnum(ExerciseType)
  type?: ExerciseType;

  @ApiPropertyOptional({ description: 'Curseur de pagination (id du dernier élément)' })
  @IsOptional()
  @IsUUID()
  cursor?: string;

  @ApiPropertyOptional({ default: DEFAULT_PAGE_SIZE, maximum: MAX_PAGE_SIZE })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(MAX_PAGE_SIZE)
  limit: number = DEFAULT_PAGE_SIZE;
}
