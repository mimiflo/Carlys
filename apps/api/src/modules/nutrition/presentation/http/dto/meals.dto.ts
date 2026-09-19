import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { MealQuantityUnit } from '@prisma/client';
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
  MaxDate,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
} from 'class-validator';
import { nowWithClockSkew } from '../../../../../common/validators/clock-skew';

/**
 * Ce qu'on peut dire d'une quantité mangée : un nombre et son unité.
 *
 * Bornée à 9 999,99 comme la colonne (`Decimal(7, 2)`) : au-delà, Postgres
 * refuserait l'écriture et la personne recevrait un 500 pour une saisie que
 * l'API aurait dû refuser elle-même. Strictement positive, parce que « 0 g »
 * n'est pas une quantité — c'est l'absence de repas.
 */
const QUANTITY_MIN = 0.01;
const QUANTITY_MAX = 9_999.99;

export class CreateMealDto {
  @ApiProperty({ description: 'UUID généré côté client (création idempotente)' })
  @IsUUID()
  id!: string;

  @ApiProperty({ minLength: 1, maxLength: 120 })
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  name!: string;

  @ApiProperty({ minimum: 1, maximum: 10000 })
  @IsInt()
  @Min(1)
  @Max(10_000)
  kcal!: number;

  @ApiPropertyOptional({
    minimum: QUANTITY_MIN,
    maximum: QUANTITY_MAX,
    description:
      'Quantité mangée — DESCRIPTIVE : elle ne multiplie ni les kcal ni ' +
      'les macros, qui restent le total consommé. Va par paire avec l’unité.',
  })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(QUANTITY_MIN)
  @Max(QUANTITY_MAX)
  quantity?: number;

  @ApiPropertyOptional({ enum: MealQuantityUnit })
  @IsOptional()
  @IsEnum(MealQuantityUnit)
  quantityUnit?: MealQuantityUnit;

  @ApiPropertyOptional({ minimum: 0, maximum: 1000 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(1_000)
  proteinG?: number;

  @ApiPropertyOptional({ minimum: 0, maximum: 1000 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(1_000)
  carbsG?: number;

  @ApiPropertyOptional({ minimum: 0, maximum: 1000 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(1_000)
  fatG?: number;

  @ApiProperty({ description: 'Instant de consommation, UTC (ISO 8601) — pas dans le futur' })
  @Type(() => Date)
  @IsDate()
  // Un repas se journalise APRÈS l'avoir mangé. Sans cette borne, une date
  // d'événement posée par l'horloge du téléphone — ou par une faute de
  // frappe sur l'année — sortait du jour courant pour toujours : le total
  // « consommé » de l'accueil ne la voyait plus, et la personne cherchait un
  // repas qu'elle avait pourtant bien enregistré. La pesée porte la même
  // borne depuis `CreateBodyMetricDto` ; le repas ne l'avait pas.
  @MaxDate(nowWithClockSkew, { message: 'La date du repas est dans le futur.' })
  eatenAt!: Date;
}

/**
 * Correction d'un repas déjà journalisé.
 *
 * TOUT est facultatif, et l'absence ne veut pas dire la même chose que
 * `null` : un champ ABSENT reste tel qu'il est, un champ à `null` EFFACE ce
 * qu'on croyait savoir. Cette distinction n'est pas décorative — sans elle,
 * corriger les calories effacerait les macros au passage.
 *
 * Les champs qui ne peuvent PAS valoir `null` en base (`name`, `kcal`,
 * `eatenAt`) refusent un `null` explicite : `@IsOptional()` laisserait
 * passer, et Prisma répondrait par un 500 à ce qui est une erreur de saisie.
 * `@ValidateIf` ne saute la validation que pour un champ vraiment absent.
 */
export class UpdateMealDto {
  @ApiPropertyOptional({ minLength: 1, maxLength: 120 })
  @ValidateIf((_, value) => value !== undefined)
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  name?: string;

  @ApiPropertyOptional({ minimum: 1, maximum: 10000 })
  @ValidateIf((_, value) => value !== undefined)
  @IsInt()
  @Min(1)
  @Max(10_000)
  kcal?: number;

  @ApiPropertyOptional({ minimum: QUANTITY_MIN, maximum: QUANTITY_MAX, nullable: true })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(QUANTITY_MIN)
  @Max(QUANTITY_MAX)
  quantity?: number | null;

  @ApiPropertyOptional({ enum: MealQuantityUnit, nullable: true })
  @IsOptional()
  @IsEnum(MealQuantityUnit)
  quantityUnit?: MealQuantityUnit | null;

  @ApiPropertyOptional({ minimum: 0, maximum: 1000, nullable: true })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(1_000)
  proteinG?: number | null;

  @ApiPropertyOptional({ minimum: 0, maximum: 1000, nullable: true })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(1_000)
  carbsG?: number | null;

  @ApiPropertyOptional({ minimum: 0, maximum: 1000, nullable: true })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(1_000)
  fatG?: number | null;

  @ApiPropertyOptional({ description: 'Instant de consommation, UTC — pas dans le futur' })
  @ValidateIf((_, value) => value !== undefined)
  @Type(() => Date)
  @IsDate()
  // Même borne qu'à la création : sans elle, la correction rouvrirait la
  // porte que la création vient de fermer.
  @MaxDate(nowWithClockSkew, { message: 'La date du repas est dans le futur.' })
  eatenAt?: Date;
}

export class ListMealsQuery {
  @ApiProperty({ description: 'Borne basse (incluse), UTC' })
  @Type(() => Date)
  @IsDate()
  from!: Date;

  @ApiProperty({ description: 'Borne haute (exclue), UTC' })
  @Type(() => Date)
  @IsDate()
  to!: Date;
}
