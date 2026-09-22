import {
  MILESTONES_IMPORT_MAX,
  TIMELINE_MAX_PAGE_SIZE,
  progressEventKindSchema,
} from '@carlys/api-contracts';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { BodyMetricType } from '@prisma/client';
import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsDate,
  IsEnum,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Max,
  MaxDate,
  Min,
  MinDate,
  ValidateNested,
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

/**
 * Un franchissement décidé par le MOBILE : une récompense, un titre.
 *
 * Les records ne passent pas par là — ils se dérivent des séries stockées,
 * et les accepter d'un client laisserait inventer un franchissement
 * qu'aucune série ne justifie.
 */
export class ImportedMilestoneDto {
  @ApiProperty({ enum: ['REWARD', 'TITLE'] })
  @IsIn(['REWARD', 'TITLE'])
  kind!: 'REWARD' | 'TITLE';

  @ApiProperty({ description: 'Clé du catalogue : `constance-4`, `titre-artisan`' })
  @IsString()
  @Length(1, 120)
  key!: string;

  @ApiProperty({
    description: 'Date du FAIT, UTC (ISO 8601) — ni future, ni antérieure au produit',
  })
  @Type(() => Date)
  @IsDate()
  // La règle d'import est « la plus ANCIENNE gagne » : sans borne basse, une
  // date de 1970 se poserait définitivement au pied de la frise, et rien ne
  // pourrait plus la remonter.
  @MinDate(new Date('2020-01-01T00:00:00Z'), {
    message: 'Cette date précède le produit.',
  })
  @MaxDate(nowWithClockSkew, { message: 'Un franchissement ne se date pas du futur.' })
  occurredAt!: Date;
}

export class ImportMilestonesDto {
  @ApiProperty({ type: [ImportedMilestoneDto], maxItems: MILESTONES_IMPORT_MAX })
  @IsArray()
  @ArrayMaxSize(MILESTONES_IMPORT_MAX)
  @ValidateNested({ each: true })
  @Type(() => ImportedMilestoneDto)
  milestones!: ImportedMilestoneDto[];
}

/**
 * Filtres de la frise.
 *
 * `kinds` est une liste séparée par des virgules — une frise de deux ans
 * sans filtre est illisible, et c'est aussi ce qui permet à un écran de
 * n'afficher que les records.
 */
export class TimelineQuery {
  @ApiPropertyOptional({ default: 30, maximum: TIMELINE_MAX_PAGE_SIZE })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(TIMELINE_MAX_PAGE_SIZE)
  limit: number = 30;

  @ApiPropertyOptional({ description: 'Curseur opaque de la page suivante' })
  @IsOptional()
  @IsString()
  @Length(1, 200)
  cursor?: string;

  @ApiPropertyOptional({
    description: 'Types retenus, séparés par des virgules. Vide = tous.',
    example: 'SESSION,RECORD',
  })
  @IsOptional()
  @Transform(({ value }: { value: unknown }) =>
    typeof value !== 'string'
      ? []
      : value
          .split(',')
          .map((part) => part.trim().toUpperCase())
          // Un type inconnu est IGNORÉ plutôt que refusé : un client d'une
          // version future qui en demande un de plus doit recevoir ce que
          // celle-ci sait servir, pas un 400.
          .filter((part) => progressEventKindSchema.safeParse(part).success),
  )
  @IsArray()
  kinds: string[] = [];
}
