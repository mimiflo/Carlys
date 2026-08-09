import { MEDIA_ALLOWED_MIME_TYPES, type MediaKind } from '@carlys/api-contracts';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional, IsUUID, ValidateIf } from 'class-validator';

const KINDS = Object.keys(MEDIA_ALLOWED_MIME_TYPES) as MediaKind[];

export class UploadMediaDto {
  @ApiProperty({ description: 'UUID fourni par l’admin : le dépôt est rejouable.' })
  @IsUUID()
  id!: string;

  @ApiProperty({ enum: KINDS })
  @IsIn(KINDS)
  kind!: MediaKind;
}

export class ListMediaQuery {
  @ApiPropertyOptional({ enum: KINDS })
  @IsOptional()
  @IsIn(KINDS)
  kind?: MediaKind;
}

export class AttachExerciseMediaDto {
  @ApiProperty({ nullable: true, description: '`null` détache le média.' })
  @ValidateIf((_, value) => value !== null)
  @IsUUID()
  mediaId!: string | null;
}
