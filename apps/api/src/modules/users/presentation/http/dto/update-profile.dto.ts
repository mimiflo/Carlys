import {
  AGE_YEARS_MAX,
  AGE_YEARS_MIN,
  DISPLAY_NAME_MAX_LENGTH,
  HEIGHT_CM_DECIMALS,
  HEIGHT_CM_MAX,
  HEIGHT_CM_MIN,
  LOCALE_PATTERN,
  birthDateRange,
} from '@carlys/api-contracts';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { ActivityLevel, BiologicalSex, CarlysProfile, NutritionGoal } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  IsDate,
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  Length,
  Matches,
  Max,
  MaxDate,
  Min,
  MinDate,
} from 'class-validator';
import { IsIanaTimeZone } from '../../../../../common/validators/is-iana-time-zone';

export class UpdateProfileDto {
  @ApiPropertyOptional({ example: 'Camille' })
  @IsOptional()
  @IsString()
  @Length(1, DISPLAY_NAME_MAX_LENGTH)
  displayName?: string;

  @ApiPropertyOptional({ example: 'fr', description: 'Code langue BCP 47' })
  @IsOptional()
  @IsString()
  @Matches(LOCALE_PATTERN, { message: 'Locale invalide (ex. fr, fr-FR).' })
  locale?: string;

  @ApiPropertyOptional({ example: 'Europe/Paris', description: 'Fuseau IANA' })
  @IsOptional()
  @IsString()
  @Length(1, 60)
  // Un vrai identifiant IANA, reconnu par ICU. Sans cette garde, n'importe
  // quelle chaîne atteignait la colonne, et la lecture des statistiques —
  // qui découpe les journées `AT TIME ZONE` ce fuseau — échouait en base.
  @IsIanaTimeZone()
  timezone?: string;

  @ApiPropertyOptional({
    enum: CarlysProfile,
    description: 'Profil Carlys — une identité d’usage, jamais un niveau',
  })
  @IsOptional()
  @IsEnum(CarlysProfile)
  carlysProfile?: CarlysProfile;

  // ── Profil métabolique (nutrition) ──────────────────────────────────────

  @ApiPropertyOptional({ enum: BiologicalSex })
  @IsOptional()
  @IsEnum(BiologicalSex)
  sex?: BiologicalSex;

  // L'intervalle vient du CONTRAT, comme la taille juste en dessous, et il
  // est réévalué à CHAQUE requête : figer les deux dates au chargement du
  // module ferait vieillir la borne avec le processus, et un serveur resté
  // debout un an refuserait les quinze ans de l'année suivante.
  @ApiPropertyOptional({
    description: `Date de naissance, UTC (ISO 8601) — de ${AGE_YEARS_MIN} à ${AGE_YEARS_MAX} ans`,
  })
  @IsOptional()
  @Type(() => Date)
  @IsDate()
  @MinDate(() => birthDateRange(new Date()).earliest, {
    message: `L’âge ne peut pas dépasser ${AGE_YEARS_MAX} ans.`,
  })
  @MaxDate(() => birthDateRange(new Date()).latest, {
    message: `Carlys s’adresse aux personnes d’au moins ${AGE_YEARS_MIN} ans.`,
  })
  birthDate?: Date;

  // Les bornes viennent du CONTRAT (`packages/api-contracts/src/users.ts`),
  // pas de chiffres recopiés ici : c'est ce qui manquait, et les clients
  // devinaient. L'écran mobile vérifiait l'intervalle mais pas la précision.
  @ApiPropertyOptional({
    minimum: HEIGHT_CM_MIN,
    maximum: HEIGHT_CM_MAX,
    description: 'Taille en cm (une décimale au maximum)',
  })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: HEIGHT_CM_DECIMALS })
  @Min(HEIGHT_CM_MIN)
  @Max(HEIGHT_CM_MAX)
  heightCm?: number;

  @ApiPropertyOptional({ enum: ActivityLevel })
  @IsOptional()
  @IsEnum(ActivityLevel)
  activityLevel?: ActivityLevel;

  @ApiPropertyOptional({ enum: NutritionGoal })
  @IsOptional()
  @IsEnum(NutritionGoal)
  nutritionGoal?: NutritionGoal;
}
