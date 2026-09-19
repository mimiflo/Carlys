import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsEmail,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
} from 'class-validator';
import { IsRecentDayKey } from '../../../../../common/validators/is-recent-day-key';

export class FriendRequestDto {
  @ApiPropertyOptional({
    description:
      'Adresse e-mail EXACTE de la personne à ajouter. La réponse est ' +
      'volontairement opaque : elle ne révèle jamais si un compte existe. ' +
      'Fournir email OU friendCode, jamais les deux.',
  })
  @ValidateIf((dto: FriendRequestDto) => dto.friendCode === undefined)
  @IsEmail()
  @MaxLength(254)
  email?: string;

  @ApiPropertyOptional({
    description:
      'Code ami de la personne (tapé ou scanné). Toutes les formes ' +
      'humaines sont acceptées : XXXX-XXXX, minuscules, charge utile de QR.',
  })
  @ValidateIf((dto: FriendRequestDto) => dto.email === undefined)
  @IsString()
  @MaxLength(64)
  friendCode?: string;
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
      'les journées. Une seule réponse comptée par leçon et par jour, et le ' +
      'jour doit être celui du serveur à un jour près (marge d’un fuseau).',
    example: '2026-08-11',
  })
  @IsRecentDayKey()
  answeredOn!: string;

  @ApiProperty()
  @IsBoolean()
  correct!: boolean;

  @ApiPropertyOptional({
    description:
      'Index du choix retenu (0 à 3). Facultatif : les clients déployés ' +
      'avant sa lecture serveur ne l’envoient pas — la réponse compte, le ' +
      'choix reste inconnu à la relecture.',
    minimum: 0,
    maximum: 3,
  })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(3)
  choiceIndex?: number;
}
