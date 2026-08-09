import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsUUID, MaxLength, MinLength } from 'class-validator';

/**
 * Entrées du coach. Les identifiants sont des UUID générés sur l'appareil :
 * l'envoi est rejouable, et un message composé hors ligne garde son identité
 * quand il finit par partir.
 */

export class CreateCoachConversationDto {
  @ApiProperty({ description: 'UUID du fil, généré sur l’appareil.' })
  @IsUUID()
  id!: string;
}

export class SendCoachMessageDto {
  @ApiProperty({ description: 'UUID du message, généré sur l’appareil.' })
  @IsUUID()
  id!: string;

  @ApiProperty({ maxLength: 2000 })
  @IsString()
  @MinLength(1)
  @MaxLength(2000)
  content!: string;
}

export class AcceptCoachProposalDto {
  @ApiProperty({ description: 'Séance née sur l’appareil depuis cette proposition.' })
  @IsUUID()
  sessionId!: string;
}
