import {
  FRIEND_CHALLENGE_DURATIONS,
  FRIEND_CHALLENGE_MAX_INVITES,
  FRIEND_CHALLENGE_MESSAGE_MAX_LENGTH,
} from '@carlys/api-contracts';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ChallengeMetric } from '@prisma/client';
import { Transform } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsEmail,
  IsEnum,
  IsIn,
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
import { trimmed } from '../../../../../common/transforms/trimmed';
import { IsRecentDayKey } from '../../../../../common/validators/is-recent-day-key';
import { MaxCodePoints } from '../../../../../common/validators/max-code-points';

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

/**
 * Corps de `POST /community/friend-challenges`.
 *
 * `endsAt` n'y figure pas, et c'est délibéré : le serveur le calcule depuis
 * la durée. Une fin fournie par l'appelant est un défi éternel en une
 * requête.
 */
export class CreateFriendChallengeDto {
  @ApiProperty({ description: 'UUID généré par l’appareil (création idempotente)' })
  @IsUUID()
  id!: string;

  @ApiProperty({ minLength: 1, maxLength: 80 })
  @Transform(trimmed)
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  title!: string;

  @ApiProperty({ enum: ChallengeMetric })
  @IsEnum(ChallengeMetric)
  metric!: ChallengeMetric;

  @ApiPropertyOptional({
    nullable: true,
    description: 'Objectif commun, ou absent pour un « qui en fait le plus »',
  })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(10_000_000)
  target?: number | null;

  @ApiProperty({ enum: FRIEND_CHALLENGE_DURATIONS })
  @IsIn([...FRIEND_CHALLENGE_DURATIONS])
  durationDays!: number;

  // `type: String` explicite : sous `strictNullChecks`, TypeScript émet
  // `design:type Object` pour `string | null`, et Swagger annonçait un objet.
  @ApiPropertyOptional({
    type: String,
    nullable: true,
    maxLength: FRIEND_CHALLENGE_MESSAGE_MAX_LENGTH,
    description:
      'Le mot du créateur à ses invités, facultatif. Découpé des blancs ' +
      'autour AVANT d’être mesuré, puis compté en points de code (un émoji ' +
      'simple vaut un, un émoji composé plusieurs) ; vide après découpage, ' +
      'il vaut « pas de message ». Visible des seuls membres, jamais dans la ' +
      'notification. Un rejeu de la création (même id) ne le modifie pas.',
  })
  @IsOptional()
  @Transform(trimmed)
  @IsString()
  @MaxCodePoints(FRIEND_CHALLENGE_MESSAGE_MAX_LENGTH)
  message?: string | null;

  @ApiProperty({ type: [String], maxItems: FRIEND_CHALLENGE_MAX_INVITES })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(FRIEND_CHALLENGE_MAX_INVITES)
  @IsUUID('4', { each: true })
  invitedUserIds!: string[];
}
