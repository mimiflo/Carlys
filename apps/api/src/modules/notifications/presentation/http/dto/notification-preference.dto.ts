import { ApiProperty } from '@nestjs/swagger';
import { NotificationCategory } from '@prisma/client';
import { IsBoolean, IsEnum } from 'class-validator';

export class UpdateNotificationPreferenceDto {
  @ApiProperty({ enum: NotificationCategory })
  @IsEnum(NotificationCategory)
  category!: NotificationCategory;

  @ApiProperty({ description: 'Accepter (true) ou refuser (false) cette famille' })
  @IsBoolean()
  enabled!: boolean;
}
