import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, Length, Matches } from 'class-validator';

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
}
