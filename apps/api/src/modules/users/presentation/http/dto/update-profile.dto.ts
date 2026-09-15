import {
  DISPLAY_NAME_MAX_LENGTH,
  HEIGHT_CM_DECIMALS,
  HEIGHT_CM_MAX,
  HEIGHT_CM_MIN,
  LOCALE_PATTERN,
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

  @ApiPropertyOptional({ description: 'Date de naissance, UTC (ISO 8601)' })
  @IsOptional()
  @Type(() => Date)
  @IsDate()
  @MaxDate(() => new Date(), { message: 'La date de naissance est dans le futur.' })
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
