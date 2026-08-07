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
  Min,
} from 'class-validator';

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

  @ApiProperty({ description: 'Date de mesure, UTC (ISO 8601)' })
  @Type(() => Date)
  @IsDate()
  measuredAt!: Date;
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
