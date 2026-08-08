import { WORKOUT_LIMITS, WORKOUT_TEMPLATE_LIMITS } from '@carlys/api-contracts';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { WorkoutSetKind } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsDate,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE } from '@carlys/shared-config';

/**
 * Série PRÉVUE transmise au lancement d'une séance issue d'un modèle.
 *
 * `exerciseName` est obligatoire même avec un `exerciseId` : c'est le repli
 * qui garantit qu'une séance n'échoue jamais à cause d'un exercice inconnu
 * (le serveur dégrade alors la prévision en exercice libre).
 */
export class CreateWorkoutSessionPlanItemDto {
  @ApiProperty({ description: "UUID généré sur l'appareil" })
  @IsUUID()
  id!: string;

  @ApiProperty({ description: "Rang de l'exercice dans la séance, à partir de 0" })
  @IsInt()
  @Min(0)
  @Max(WORKOUT_TEMPLATE_LIMITS.exercisesMax)
  exercisePosition!: number;

  @ApiPropertyOptional({ description: 'Exercice du catalogue' })
  @IsOptional()
  @IsUUID()
  exerciseId?: string;

  @ApiProperty({ maxLength: WORKOUT_LIMITS.nameMax })
  @IsString()
  @MinLength(1)
  @MaxLength(WORKOUT_LIMITS.nameMax)
  exerciseName!: string;

  @ApiProperty({ description: "Rang de la série DANS l'exercice, à partir de 0" })
  @IsInt()
  @Min(0)
  @Max(WORKOUT_TEMPLATE_LIMITS.setsPerExerciseMax)
  setPosition!: number;

  @ApiPropertyOptional({ enum: WorkoutSetKind })
  @IsOptional()
  @IsEnum(WorkoutSetKind)
  kind?: WorkoutSetKind;

  @ApiPropertyOptional({ maximum: WORKOUT_LIMITS.repsMax })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(WORKOUT_LIMITS.repsMax)
  targetReps?: number;

  @ApiPropertyOptional({ maximum: WORKOUT_LIMITS.weightKgMax })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(WORKOUT_LIMITS.weightKgMax)
  targetWeightKg?: number;

  @ApiPropertyOptional({ maximum: WORKOUT_LIMITS.restSecondsMax })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(WORKOUT_LIMITS.restSecondsMax)
  restSeconds?: number;
}

export class SkipWorkoutSessionPlanItemsDto {
  @ApiProperty({
    description: 'Prévisions à passer — celles déjà honorées sont ignorées',
    type: [String],
  })
  @IsArray()
  @ArrayMaxSize(WORKOUT_LIMITS.planItemsMax)
  @IsUUID('4', { each: true })
  planItemIds!: string[];
}

export class CreateWorkoutSessionDto {
  @ApiProperty({ description: "UUID généré sur l'appareil (création idempotente)" })
  @IsUUID()
  id!: string;

  @ApiPropertyOptional({ maxLength: WORKOUT_LIMITS.nameMax })
  @IsOptional()
  @IsString()
  @MaxLength(WORKOUT_LIMITS.nameMax)
  name?: string;

  @ApiPropertyOptional({ maxLength: WORKOUT_LIMITS.notesMax })
  @IsOptional()
  @IsString()
  @MaxLength(WORKOUT_LIMITS.notesMax)
  notes?: string;

  @ApiProperty({ description: 'Début de séance, UTC (ISO 8601)' })
  @Type(() => Date)
  @IsDate()
  startedAt!: Date;

  @ApiPropertyOptional({
    description: 'Modèle lancé — ignoré s’il est inconnu, jamais bloquant',
  })
  @IsOptional()
  @IsUUID()
  templateId?: string;

  @ApiPropertyOptional({
    description: 'Nom du modèle conservé par le client, utilisé en secours',
    maxLength: WORKOUT_LIMITS.nameMax,
  })
  @IsOptional()
  @IsString()
  @MaxLength(WORKOUT_LIMITS.nameMax)
  templateName?: string;

  @ApiPropertyOptional({
    description:
      'Plan copié du modèle au lancement — transmis À LA CRÉATION seulement, ' +
      'ce qui permet de reprendre la séance sur un autre appareil',
    type: [CreateWorkoutSessionPlanItemDto],
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(WORKOUT_LIMITS.planItemsMax)
  @ValidateNested({ each: true })
  @Type(() => CreateWorkoutSessionPlanItemDto)
  plan?: CreateWorkoutSessionPlanItemDto[];
}

export class UpdateWorkoutSessionDto {
  @ApiPropertyOptional({ maxLength: WORKOUT_LIMITS.nameMax })
  @IsOptional()
  @IsString()
  @MaxLength(WORKOUT_LIMITS.nameMax)
  name?: string;

  @ApiPropertyOptional({ maxLength: WORKOUT_LIMITS.notesMax })
  @IsOptional()
  @IsString()
  @MaxLength(WORKOUT_LIMITS.notesMax)
  notes?: string;
}

export class CloseWorkoutSessionDto {
  @ApiPropertyOptional({ description: 'Fin de séance, UTC (ISO 8601)' })
  @IsOptional()
  @Type(() => Date)
  @IsDate()
  endedAt?: Date;

  @ApiPropertyOptional({ maximum: WORKOUT_LIMITS.durationSecondsMax })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(WORKOUT_LIMITS.durationSecondsMax)
  durationSeconds?: number;
}

export class CreateWorkoutSetDto {
  @ApiProperty({ description: "UUID généré sur l'appareil (upsert idempotent)" })
  @IsUUID()
  id!: string;

  @ApiPropertyOptional({ description: 'Exercice du catalogue' })
  @IsOptional()
  @IsUUID()
  exerciseId?: string;

  @ApiPropertyOptional({ description: 'Nom libre si hors catalogue' })
  @IsOptional()
  @IsString()
  @MaxLength(WORKOUT_LIMITS.nameMax)
  exerciseName?: string;

  @ApiProperty({ description: 'Ordre dans la séance' })
  @IsInt()
  @Min(0)
  @Max(10_000)
  position!: number;

  @ApiPropertyOptional({ enum: WorkoutSetKind })
  @IsOptional()
  @IsEnum(WorkoutSetKind)
  kind?: WorkoutSetKind;

  @ApiPropertyOptional({ maximum: WORKOUT_LIMITS.repsMax })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(WORKOUT_LIMITS.repsMax)
  reps?: number;

  @ApiPropertyOptional({ maximum: WORKOUT_LIMITS.weightKgMax })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(WORKOUT_LIMITS.weightKgMax)
  weightKg?: number;

  @ApiPropertyOptional({ maximum: WORKOUT_LIMITS.durationSecondsMax })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(WORKOUT_LIMITS.durationSecondsMax)
  durationSeconds?: number;

  @ApiPropertyOptional({ maximum: WORKOUT_LIMITS.distanceMetersMax })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(WORKOUT_LIMITS.distanceMetersMax)
  distanceMeters?: number;

  @ApiPropertyOptional({ minimum: WORKOUT_LIMITS.rpeMin, maximum: WORKOUT_LIMITS.rpeMax })
  @IsOptional()
  @IsInt()
  @Min(WORKOUT_LIMITS.rpeMin)
  @Max(WORKOUT_LIMITS.rpeMax)
  rpe?: number;

  @ApiPropertyOptional({ maximum: WORKOUT_LIMITS.restSecondsMax })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(WORKOUT_LIMITS.restSecondsMax)
  restSeconds?: number;

  @ApiPropertyOptional({
    description: 'Répétitions PRÉVUES affichées à la validation (jamais modifiables ensuite)',
    maximum: WORKOUT_LIMITS.repsMax,
  })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(WORKOUT_LIMITS.repsMax)
  plannedReps?: number;

  @ApiPropertyOptional({
    description: 'Charge PRÉVUE affichée à la validation (jamais modifiable ensuite)',
    maximum: WORKOUT_LIMITS.weightKgMax,
  })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(WORKOUT_LIMITS.weightKgMax)
  plannedWeightKg?: number;

  @ApiPropertyOptional({
    description: 'Prévision du plan honorée par cette série — ignorée si inconnue ou déjà honorée',
  })
  @IsOptional()
  @IsUUID()
  planItemId?: string;

  @ApiProperty({ description: 'Fin de la série, UTC (ISO 8601)' })
  @Type(() => Date)
  @IsDate()
  completedAt!: Date;
}

export class UpdateWorkoutSetDto {
  @ApiPropertyOptional({ enum: WorkoutSetKind })
  @IsOptional()
  @IsEnum(WorkoutSetKind)
  kind?: WorkoutSetKind;

  @ApiPropertyOptional({ maximum: WORKOUT_LIMITS.repsMax })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(WORKOUT_LIMITS.repsMax)
  reps?: number;

  @ApiPropertyOptional({ maximum: WORKOUT_LIMITS.weightKgMax })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(WORKOUT_LIMITS.weightKgMax)
  weightKg?: number;

  @ApiPropertyOptional({ maximum: WORKOUT_LIMITS.durationSecondsMax })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(WORKOUT_LIMITS.durationSecondsMax)
  durationSeconds?: number;

  @ApiPropertyOptional({ maximum: WORKOUT_LIMITS.distanceMetersMax })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(WORKOUT_LIMITS.distanceMetersMax)
  distanceMeters?: number;

  @ApiPropertyOptional({ minimum: WORKOUT_LIMITS.rpeMin, maximum: WORKOUT_LIMITS.rpeMax })
  @IsOptional()
  @IsInt()
  @Min(WORKOUT_LIMITS.rpeMin)
  @Max(WORKOUT_LIMITS.rpeMax)
  rpe?: number;

  @ApiPropertyOptional({ maximum: WORKOUT_LIMITS.restSecondsMax })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(WORKOUT_LIMITS.restSecondsMax)
  restSeconds?: number;

  @ApiPropertyOptional({ description: 'Fin de la série, UTC (ISO 8601)' })
  @IsOptional()
  @Type(() => Date)
  @IsDate()
  completedAt?: Date;
}

export class ListWorkoutSessionsQuery {
  @ApiPropertyOptional({ description: 'Curseur (id de la dernière séance servie)' })
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
