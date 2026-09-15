import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { BodyMetricType } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  IsDate,
  IsEnum,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsUUID,
  Max,
  MaxDate,
  Min,
} from 'class-validator';
import { nowWithClockSkew } from '../../../../../common/validators/clock-skew';

export const PROGRESS_PERIODS = ['week', 'month', 'year'] as const;
export type ProgressPeriodValue = (typeof PROGRESS_PERIODS)[number];

export class OverviewQuery {
  @ApiPropertyOptional({ enum: PROGRESS_PERIODS, default: 'week' })
  @IsOptional()
  @IsIn(PROGRESS_PERIODS)
  period: ProgressPeriodValue = 'week';
}

export class CreateBodyMetricDto {
  @ApiProperty({ description: 'UUID généré côté client (création idempotente)' })
  @IsUUID()
  id!: string;

  @ApiProperty({ enum: BodyMetricType })
  @IsEnum(BodyMetricType)
  metricType!: BodyMetricType;

  @ApiProperty({ minimum: 1, maximum: 500 })
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(1)
  @Max(500)
  value!: number;

  @ApiProperty({ description: 'Date de mesure, UTC (ISO 8601) — pas dans le futur' })
  @Type(() => Date)
  @IsDate()
  // La date choisit QUELLE mesure fait foi : `latestWeightKg` prend la plus
  // récente par `measuredAt`, et ce poids alimente tout le rapport
  // métabolique. Une pesée datée de l'an prochain devenait donc le poids de
  // référence, définitivement. L'écran mobile l'interdit déjà (« on ne se
  // pèse pas demain ») ; l'API ne s'appuie pas sur l'écran pour valider.
  @MaxDate(nowWithClockSkew, { message: 'La date de mesure est dans le futur.' })
  measuredAt!: Date;
}

/**
 * Correction d'une mesure : la valeur, la date, ou les deux.
 *
 * Le TYPE est absent volontairement — un poids ne devient pas un taux de
 * masse grasse. Cette erreur-là se répare en supprimant puis recréant, ce
 * que l'API sait déjà faire.
 *
 * Les deux champs sont facultatifs, mais un corps entièrement vide est
 * refusé par le service : ce n'est pas une correction.
 */
export class UpdateBodyMetricDto {
  @ApiPropertyOptional({ minimum: 1, maximum: 500 })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(1)
  @Max(500)
  value?: number;

  @ApiPropertyOptional({ description: 'Date de mesure, UTC (ISO 8601) — pas dans le futur' })
  @IsOptional()
  @Type(() => Date)
  @IsDate()
  // Même borne qu'à la création : sans elle, la correction rouvrait la porte
  // que la création vient de fermer.
  @MaxDate(nowWithClockSkew, { message: 'La date de mesure est dans le futur.' })
  measuredAt?: Date;
}

export class ListBodyMetricsQuery {
  @ApiPropertyOptional({ enum: BodyMetricType, default: BodyMetricType.WEIGHT_KG })
  @IsOptional()
  @IsEnum(BodyMetricType)
  metricType: BodyMetricType = BodyMetricType.WEIGHT_KG;

  @ApiPropertyOptional({ default: 90, maximum: 365 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(365)
  limit: number = 90;
}
