import { ApiPropertyOptional } from '@nestjs/swagger';
import { ActivityLevel, BiologicalSex, NutritionGoal } from '@prisma/client';
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

export class UpdateProfileDto {
  @ApiPropertyOptional({ example: 'Camille' })
  @IsOptional()
  @IsString()
  @Length(1, 60)
  displayName?: string;

  @ApiPropertyOptional({ example: 'fr', description: 'Code langue BCP 47' })
  @IsOptional()
  @IsString()
  @Matches(/^[a-z]{2}(-[A-Z]{2})?$/, { message: 'Locale invalide (ex. fr, fr-FR).' })
  locale?: string;

  @ApiPropertyOptional({ example: 'Europe/Paris', description: 'Fuseau IANA' })
  @IsOptional()
  @IsString()
  @Length(1, 60)
  timezone?: string;

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

  @ApiPropertyOptional({ minimum: 80, maximum: 250, description: 'Taille en cm' })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 1 })
  @Min(80)
  @Max(250)
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
