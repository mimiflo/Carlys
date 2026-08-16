import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsUUID, MaxLength, MinLength } from 'class-validator';

export class CreateCheckoutDto {
  @ApiProperty({
    description:
      'Identifiant fourni par l’appareil. Rejouer la demande rend la MÊME page de paiement.',
    format: 'uuid',
  })
  @IsUUID()
  id!: string;

  @ApiProperty({ description: 'Identifiant de l’offre du catalogue' })
  @IsString()
  @MinLength(1)
  @MaxLength(64)
  offerId!: string;
}
