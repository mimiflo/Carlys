import { ApiProperty } from '@nestjs/swagger';
import { IsUUID } from 'class-validator';

export class StartMealScanDto {
  @ApiProperty({ description: 'Identifiant né sur l’appareil : le même rend le même scan.' })
  @IsUUID()
  id!: string;
}
