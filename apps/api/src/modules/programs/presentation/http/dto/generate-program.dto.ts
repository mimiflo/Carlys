import { ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { trimmed } from '../../../../../common/transforms/trimmed';

/**
 * Corps de `PUT /programs/:id/generate`.
 *
 * AUCUNE entrée de profil ici, et c'est délibéré : l'objectif, le niveau, le
 * rythme, la durée et le matériel sont déjà publiés par `GET /users/me/training`
 * et modifiés par `PATCH /users/me`. Les accepter une seconde fois ouvrirait
 * deux sources pour la même donnée, donc une divergence — et rendrait
 * impossible de dire, quand un programme déçoit, lequel des deux profils l'a
 * produit. Le pipe global (`whitelist` + `forbidNonWhitelisted`) refuse en 400
 * tout champ non déclaré, donc un client qui essaie l'apprend tout de suite.
 */
export class GenerateProgramDto {
  @ApiPropertyOptional({
    maxLength: 120,
    description: 'Nom du programme. Par défaut, celui que la génération propose.',
  })
  @IsOptional()
  @Transform(trimmed)
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  name?: string;
}
