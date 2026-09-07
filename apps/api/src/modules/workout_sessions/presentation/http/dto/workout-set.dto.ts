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

/**
 * Les SÉRIES : ce qui a été réellement fait.
 *
 * Séparées des séances comme le sont leur contrôleur et leur service. Deux
 * champs y sont particuliers : `planned*`, la cible AFFICHÉE à l'instant de
 * la validation, acceptée à la création et jamais à la correction — c'est un
 * fait historique, pas un réglage.
 */
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
