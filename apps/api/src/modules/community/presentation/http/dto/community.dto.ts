import { ApiProperty } from '@nestjs/swagger';
import { IsBoolean, IsEmail, IsString, IsUUID, MaxLength, MinLength } from 'class-validator';

export class FriendRequestDto {
  @ApiProperty({
    description:
      'Adresse e-mail EXACTE de la personne à ajouter. La réponse est ' +
      'volontairement opaque : elle ne révèle jamais si un compte existe.',
  })
  @IsEmail()
  @MaxLength(254)
  email!: string;
}

export class EncourageDto {
  @ApiProperty({ description: 'Identifiant utilisateur d’un AMI accepté' })
  @IsUUID()
  recipientUserId!: string;

  @ApiProperty({ minLength: 1, maxLength: 280 })
  @IsString()
  @MinLength(1)
  @MaxLength(280)
  message!: string;
}

export class UpdateCommunityProfileDto {
  @ApiProperty({
    description:
      'Partager sa série et ses séances de la semaine avec ses amis. ' +
      'Faux : les amis ne voient que le nom (« Profil privé »).',
  })
  @IsBoolean()
  sharesProgress!: boolean;
}
