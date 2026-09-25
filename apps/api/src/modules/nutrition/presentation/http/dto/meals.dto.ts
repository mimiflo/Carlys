import { MEAL_COMPONENTS_MAX } from '@carlys/api-contracts';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { MealMoment, MealQuantityUnit } from '@prisma/client';
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
  MaxDate,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
  ValidateNested,
} from 'class-validator';
import { nowWithClockSkew } from '../../../../../common/validators/clock-skew';
import {
  MEAL_KCAL_MAX,
  MEAL_KCAL_MIN,
  MEAL_MACRO_MAX_G,
  MEAL_QUANTITY_MAX,
  MEAL_QUANTITY_MIN,
} from '../../../domain/meal-bounds';
import { MealComponentInputDto } from './meal-component.dto';

/**
 * Ce qu'on peut dire d'une quantité mangée : un nombre et son unité.
 *
 * Bornée à 9 999,99 comme la colonne (`Decimal(7, 2)`) : au-delà, Postgres
 * refuserait l'écriture et la personne recevrait un 500 pour une saisie que
 * l'API aurait dû refuser elle-même. Strictement positive, parce que « 0 g »
 * n'est pas une quantité — c'est l'absence de repas.
 */
const QUANTITY_MIN = MEAL_QUANTITY_MIN;
const QUANTITY_MAX = MEAL_QUANTITY_MAX;

/** Des aliments à calculer : une liste NON VIDE (la vide veut dire « aucun »). */
function hasComposition(dto: { components?: unknown }): boolean {
  return Array.isArray(dto.components) && dto.components.length > 0;
}

const COMPONENTS_DESCRIPTION =
  'Aliments du repas, dans l’ordre, chaque ligne sous un UUID de l’appareil. ' +
  'Non vide : le serveur CALCULE kcal, macros et quantité (en grammes) depuis ' +
  'la base, et refuse en 400 un corps qui porterait aussi kcal, proteinG, ' +
  'carbsG, fatG, quantity ou quantityUnit.';

/**
 * Nouveau repas : SAISI À LA MAIN (`kcal` obligatoire, le reste facultatif)
 * ou COMPOSÉ d'aliments de la base (`components` non vide, aucun total).
 */
export class CreateMealDto {
  @ApiProperty({ description: 'UUID généré côté client (création idempotente)' })
  @IsUUID()
  id!: string;

  @ApiProperty({ minLength: 1, maxLength: 120 })
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  name!: string;

  @ApiPropertyOptional({
    enum: MealMoment,
    nullable: true,
    description: 'Moment de la journée ; absent ou null : le client le déduira de l’heure',
  })
  @IsOptional()
  @IsEnum(MealMoment)
  moment?: MealMoment | null;

  @ApiPropertyOptional({
    minimum: MEAL_KCAL_MIN,
    maximum: MEAL_KCAL_MAX,
    description: 'Obligatoire pour un repas saisi à la main ; interdit avec des aliments',
  })
  // Validé dès qu'il est envoyé, ou exigé quand rien d'autre ne dira les
  // calories. Envoyé AVEC des aliments, c'est le service qui le refuse, avec
  // un message qui dit pourquoi.
  @ValidateIf((dto: CreateMealDto) => dto.kcal !== undefined || !hasComposition(dto))
  @IsInt()
  @Min(MEAL_KCAL_MIN)
  @Max(MEAL_KCAL_MAX)
  kcal?: number;

  @ApiPropertyOptional({
    type: [MealComponentInputDto],
    maxItems: MEAL_COMPONENTS_MAX,
    description: COMPONENTS_DESCRIPTION,
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(MEAL_COMPONENTS_MAX)
  @ValidateNested({ each: true })
  @Type(() => MealComponentInputDto)
  components?: MealComponentInputDto[];

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

  @ApiPropertyOptional({ minimum: 0, maximum: MEAL_MACRO_MAX_G })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(MEAL_MACRO_MAX_G)
  proteinG?: number;

  @ApiPropertyOptional({ minimum: 0, maximum: MEAL_MACRO_MAX_G })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(MEAL_MACRO_MAX_G)
  carbsG?: number;

  @ApiPropertyOptional({ minimum: 0, maximum: MEAL_MACRO_MAX_G })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(MEAL_MACRO_MAX_G)
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
 * `components` suit la même règle : `null` n'est pas `[]`.
 */
export class UpdateMealDto {
  @ApiPropertyOptional({ minLength: 1, maxLength: 120 })
  @ValidateIf((_, value) => value !== undefined)
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  name?: string;

  @ApiPropertyOptional({
    enum: MealMoment,
    nullable: true,
    description: 'Moment de la journée ; null l’efface',
  })
  @IsOptional()
  @IsEnum(MealMoment)
  moment?: MealMoment | null;

  @ApiPropertyOptional({ minimum: MEAL_KCAL_MIN, maximum: MEAL_KCAL_MAX })
  @ValidateIf((_, value) => value !== undefined)
  @IsInt()
  @Min(MEAL_KCAL_MIN)
  @Max(MEAL_KCAL_MAX)
  kcal?: number;

  // `type` explicite sur les champs `number | null` : sous
  // `strictNullChecks`, TypeScript émet `design:type Object` pour une union
  // avec `null`, et Swagger annonçait un objet vide (garde :
  // `app/openapi-document.spec.ts`).
  @ApiPropertyOptional({
    type: Number,
    minimum: QUANTITY_MIN,
    maximum: QUANTITY_MAX,
    nullable: true,
  })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(QUANTITY_MIN)
  @Max(QUANTITY_MAX)
  quantity?: number | null;

  @ApiPropertyOptional({ enum: MealQuantityUnit, nullable: true })
  @IsOptional()
  @IsEnum(MealQuantityUnit)
  quantityUnit?: MealQuantityUnit | null;

  @ApiPropertyOptional({ type: 'integer', minimum: 0, maximum: MEAL_MACRO_MAX_G, nullable: true })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(MEAL_MACRO_MAX_G)
  proteinG?: number | null;

  @ApiPropertyOptional({ type: 'integer', minimum: 0, maximum: MEAL_MACRO_MAX_G, nullable: true })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(MEAL_MACRO_MAX_G)
  carbsG?: number | null;

  @ApiPropertyOptional({ type: 'integer', minimum: 0, maximum: MEAL_MACRO_MAX_G, nullable: true })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(MEAL_MACRO_MAX_G)
  fatG?: number | null;

  @ApiPropertyOptional({ description: 'Instant de consommation, UTC — pas dans le futur' })
  @ValidateIf((_, value) => value !== undefined)
  @Type(() => Date)
  @IsDate()
  // Même borne qu'à la création : sans elle, la correction rouvrirait la
  // porte que la création vient de fermer.
  @MaxDate(nowWithClockSkew, { message: 'La date du repas est dans le futur.' })
  eatenAt?: Date;

  @ApiPropertyOptional({
    type: [MealComponentInputDto],
    maxItems: MEAL_COMPONENTS_MAX,
    description:
      COMPONENTS_DESCRIPTION +
      ' La liste REMPLACE la composition : une ligne dont l’id est déjà dans le ' +
      'repas garde son instantané (même si l’aliment a quitté la base) et ne ' +
      'change que de quantité ou de place ; une ligne à id neuf lit la base. ' +
      'Absent : la composition ne bouge pas, et les totaux d’un repas composé ' +
      'ne se corrigent pas à la main (renvoyés à l’identique, ils sont ignorés ; ' +
      'changés, refusés en 400). Vide : la composition est retirée, le repas ' +
      'redevient saisi à la main et garde ses derniers totaux.',
  })
  // `null` n'est PAS « aucun aliment » : c'est `[]` qui le dit. Refusé en
  // 400 plutôt que confondu avec l'absence.
  @ValidateIf((_, value) => value !== undefined)
  @IsArray()
  @ArrayMaxSize(MEAL_COMPONENTS_MAX)
  @ValidateNested({ each: true })
  @Type(() => MealComponentInputDto)
  components?: MealComponentInputDto[];
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
