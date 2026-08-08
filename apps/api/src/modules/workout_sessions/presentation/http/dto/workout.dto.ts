import { WORKOUT_LIMITS } from '@carlys/api-contracts';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { WorkoutSetKind } from '@prisma/client';
import { Type } from 'class-transformer';
import {
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
} from 'class-validator';
import { DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE } from '@carlys/shared-config';

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
