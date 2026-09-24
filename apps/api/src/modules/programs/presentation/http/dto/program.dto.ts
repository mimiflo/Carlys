import { PROGRAM_MAX_DAYS, PROGRAM_MAX_WEEKS } from '@carlys/api-contracts';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
  ValidateNested,
} from 'class-validator';
import { trimmed } from '../../../../../common/transforms/trimmed';
import { IsDayKey } from '../../../../../common/validators/is-day-key';

/** Semaine demandée au calendrier. Absente : celle d'aujourd'hui. */
export class CalendarWeekQuery {
  @ApiPropertyOptional({
    minimum: 1,
    maximum: PROGRAM_MAX_WEEKS,
    description: 'Semaine du programme. Absente : celle qui contient aujourd’hui.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(PROGRAM_MAX_WEEKS)
  week?: number;
}

export class ListProgramsQuery {
  @ApiPropertyOptional({ description: 'Curseur : id du dernier élément servi' })
  @IsOptional()
  @IsUUID()
  cursor?: string;

  @ApiPropertyOptional({ default: 20, maximum: 100 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit: number = 20;
}

export class SaveProgramDayDto {
  @ApiProperty({ description: 'UUID fourni par l’appareil' })
  @IsUUID()
  id!: string;

  @ApiProperty({ minimum: 1, maximum: PROGRAM_MAX_WEEKS })
  @IsInt()
  @Min(1)
  @Max(PROGRAM_MAX_WEEKS)
  weekNumber!: number;

  @ApiProperty({ minimum: 1, maximum: 7, description: '1 = lundi … 7 = dimanche' })
  @IsInt()
  @Min(1)
  @Max(7)
  dayOfWeek!: number;

  // `type` explicite : sous `strictNullChecks`, TypeScript émet
  // `design:type Object` pour `string | null`, et Swagger annonçait un
  // objet vide (garde : `app/openapi-document.spec.ts`).
  @ApiPropertyOptional({ type: String, format: 'uuid', nullable: true })
  @IsOptional()
  @IsUUID()
  templateId?: string | null;

  @ApiPropertyOptional({ description: 'Déduit du contexte s’il est absent' })
  @IsOptional()
  @Transform(trimmed)
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  label?: string;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isRest?: boolean;
}

/** Corps du `PUT` : l'état COMPLET du programme, pas un correctif. */
export class SaveProgramDto {
  // Élagués AVANT d'être mesurés, comme le contrat Zod publié
  // (`saveProgramRequestSchema` : `z.string().trim().min(1).max(120)`) et
  // comme le module jumeau des modèles. Sans cela `@MinLength(1)` acceptait
  // trois espaces — un programme sans nom, enregistré tel quel — et un nom
  // de 120 caractères suivi d'un espace était refusé pour 121.
  @ApiProperty()
  @Transform(trimmed)
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  name!: string;

  @ApiPropertyOptional({ type: String, nullable: true, maxLength: 2000 })
  @IsOptional()
  @Transform(trimmed)
  @IsString()
  @MaxLength(2000)
  description?: string | null;

  @ApiProperty({ minimum: 1, maximum: PROGRAM_MAX_WEEKS })
  @IsInt()
  @Min(1)
  @Max(PROGRAM_MAX_WEEKS)
  weeksCount!: number;

  @ApiPropertyOptional({ description: 'Programme suivi en ce moment (un seul)' })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @ApiPropertyOptional({
    type: String,
    format: 'date',
    nullable: true,
    example: '2026-09-21',
    description:
      'Premier jour du plan, jour civil YYYY-MM-DD. Absent vaut « pas de ' +
      'calendrier » : le corps décrit l’état complet.',
  })
  @IsOptional()
  // Une CHAÎNE, pas un `Date` : un jour civil converti en instant recule
  // d'un jour à l'ouest de Greenwich, et aucune borne de futur ne s'y
  // applique — commencer lundi prochain est le cas normal.
  @IsDayKey()
  startsOn?: string | null;

  @ApiProperty({ type: [SaveProgramDayDto], maxItems: PROGRAM_MAX_DAYS })
  @IsArray()
  @ArrayMaxSize(PROGRAM_MAX_DAYS)
  @ValidateNested({ each: true })
  @Type(() => SaveProgramDayDto)
  days!: SaveProgramDayDto[];
}

/**
 * Corps de `PUT /programs/:id/calendar/days/:dayId/session`.
 *
 * `null` est une VALEUR, pas une absence : c'est l'état « cette case ne
 * reconnaît plus aucune séance ». Le champ est donc requis, et le pipe
 * global (`whitelist` + `forbidNonWhitelisted`) refuse un corps vide en 400
 * plutôt que de délier par défaut.
 */
export class LinkCalendarSessionDto {
  @ApiProperty({
    type: String,
    format: 'uuid',
    nullable: true,
    description: 'Séance TERMINÉE qui honore cette case, ou null pour l’en détacher',
  })
  @ValidateIf((_, value) => value !== null)
  @IsUUID()
  sessionId!: string | null;
}
