import { WORKOUT_LIMITS, WORKOUT_TEMPLATE_LIMITS } from '@carlys/api-contracts';
import { DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE } from '@carlys/shared-config';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { WorkoutSetKind } from '@prisma/client';
import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

const trimmed = ({ value }: { value: unknown }): unknown =>
  typeof value === 'string' ? value.trim() : value;

/** Série prévue : des CIBLES facultatives, jamais des mesures. */
export class PlannedSetDto {
  @ApiProperty({ description: "UUID généré sur l'appareil" })
  @IsUUID()
  id!: string;

  @ApiPropertyOptional({ enum: WorkoutSetKind, default: WorkoutSetKind.NORMAL })
  @IsOptional()
  @IsEnum(WorkoutSetKind)
  kind?: WorkoutSetKind | null;

  @ApiPropertyOptional({ maximum: WORKOUT_LIMITS.repsMax })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(WORKOUT_LIMITS.repsMax)
  targetReps?: number | null;

  @ApiPropertyOptional({ maximum: WORKOUT_LIMITS.weightKgMax })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(WORKOUT_LIMITS.weightKgMax)
  targetWeightKg?: number | null;

  @ApiPropertyOptional({ maximum: WORKOUT_LIMITS.restSecondsMax })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(WORKOUT_LIMITS.restSecondsMax)
  restSeconds?: number | null;
}

/** Ligne d'exercice : sa position vient de l'ordre du tableau, jamais du corps. */
export class TemplateExerciseDto {
  @ApiProperty({ description: "UUID généré sur l'appareil" })
  @IsUUID()
  id!: string;

  @ApiPropertyOptional({ description: 'Exercice du catalogue' })
  @IsOptional()
  @IsUUID()
  exerciseId?: string | null;

  @ApiPropertyOptional({ description: 'Nom libre si hors catalogue' })
  @IsOptional()
  @IsString()
  @Transform(trimmed)
  @MaxLength(WORKOUT_LIMITS.nameMax)
  exerciseName?: string | null;

  @ApiPropertyOptional({ maxLength: WORKOUT_LIMITS.notesMax })
  @IsOptional()
  @IsString()
  @MaxLength(WORKOUT_LIMITS.notesMax)
  notes?: string | null;

  @ApiProperty({ type: [PlannedSetDto], maxItems: WORKOUT_TEMPLATE_LIMITS.setsPerExerciseMax })
  @IsArray()
  @ArrayMaxSize(WORKOUT_TEMPLATE_LIMITS.setsPerExerciseMax)
  @ValidateNested({ each: true })
  @Type(() => PlannedSetDto)
  sets!: PlannedSetDto[];
}

/** Corps du PUT : l'état COMPLET du modèle après écriture. */
export class SaveWorkoutTemplateDto {
  @ApiProperty({ maxLength: WORKOUT_LIMITS.nameMax })
  @IsString()
  @Transform(trimmed)
  @MaxLength(WORKOUT_LIMITS.nameMax)
  name!: string;

  @ApiPropertyOptional({ maxLength: WORKOUT_LIMITS.notesMax })
  @IsOptional()
  @IsString()
  @MaxLength(WORKOUT_LIMITS.notesMax)
  notes?: string | null;

  @ApiPropertyOptional({
    description: "Saisie de l'utilisateur — jamais calculée par le serveur",
    minimum: 1,
    maximum: WORKOUT_TEMPLATE_LIMITS.estimatedDurationMinutesMax,
  })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(WORKOUT_TEMPLATE_LIMITS.estimatedDurationMinutesMax)
  estimatedDurationMinutes?: number | null;

  @ApiProperty({
    type: [TemplateExerciseDto],
    minItems: 1,
    maxItems: WORKOUT_TEMPLATE_LIMITS.exercisesMax,
  })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(WORKOUT_TEMPLATE_LIMITS.exercisesMax)
  @ValidateNested({ each: true })
  @Type(() => TemplateExerciseDto)
  exercises!: TemplateExerciseDto[];
}

export class ListWorkoutTemplatesQuery {
  @ApiPropertyOptional({ description: 'Curseur (id du dernier modèle servi)' })
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
