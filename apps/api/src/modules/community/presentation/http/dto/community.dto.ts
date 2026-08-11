import { ApiProperty } from '@nestjs/swagger';
import {
  IsBoolean,
  IsEmail,
  IsString,
  IsUUID,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';

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

export class QuizAnswerDto {
  @ApiProperty({ description: 'Identifiant de la leçon du pack embarqué' })
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  lessonId!: string;

  @ApiProperty({
    description:
      'Jour LOCAL de l’appareil (YYYY-MM-DD) — le serveur ne découpe pas ' +
      'les journées. Une seule réponse comptée par leçon et par jour.',
    example: '2026-08-11',
  })
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  answeredOn!: string;

  @ApiProperty()
  @IsBoolean()
  correct!: boolean;
}
