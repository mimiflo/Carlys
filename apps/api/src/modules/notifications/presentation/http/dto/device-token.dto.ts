import { ApiProperty } from '@nestjs/swagger';
import { DevicePlatform } from '@prisma/client';
import { IsEnum, IsString, MaxLength, MinLength } from 'class-validator';

export class RegisterDeviceTokenDto {
  @ApiProperty({ description: "Jeton d'enregistrement FCM de l'appareil" })
  @IsString()
  @MinLength(1)
  @MaxLength(512)
  token!: string;

  @ApiProperty({ enum: DevicePlatform })
  @IsEnum(DevicePlatform)
  platform!: DevicePlatform;
}

export class ForgetDeviceTokenDto {
  @ApiProperty({ description: 'Jeton FCM à oublier (déconnexion)' })
  @IsString()
  @MinLength(1)
  @MaxLength(512)
  token!: string;
}
