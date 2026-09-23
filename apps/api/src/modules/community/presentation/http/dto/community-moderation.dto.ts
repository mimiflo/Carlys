import {
  COMMUNITY_REPORT_DETAILS_MAX_LENGTH,
  type CommunityReportReason,
  communityReportReasonSchema,
  type CommunityReportStatus,
  communityReportStatusSchema,
} from '@carlys/api-contracts';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min } from 'class-validator';

export class CreateCommunityReportDto {
  @ApiProperty({ description: 'Personne signalée', format: 'uuid' })
  @IsUUID()
  reportedUserId!: string;

  // `type: String` explicite sur les deux cibles : sous `strictNullChecks`,
  // TypeScript émet `design:type Object` pour `string | null`, et Swagger
  // annonçait un objet là où l'API attend un uuid. `null` vaut « absent »,
  // comme dans le contrat Zod.
  @ApiPropertyOptional({
    type: String,
    format: 'uuid',
    nullable: true,
    description:
      'Encouragement visé. Il doit avoir été envoyé PAR la personne signalée ' +
      'AU signalant, sinon 404.',
  })
  @IsOptional()
  @IsUUID()
  encouragementId?: string | null;

  @ApiPropertyOptional({
    type: String,
    format: 'uuid',
    nullable: true,
    description:
      'Défi entre amis visé (son titre et son message). Le signalant doit en ' +
      'être membre, quel que soit son statut, et la personne signalée doit ' +
      'en être la créatrice, sinon 404. Exclusif avec encouragementId (400).',
  })
  @IsOptional()
  @IsUUID()
  friendChallengeId?: string | null;

  @ApiProperty({ enum: communityReportReasonSchema.options })
  @IsIn(communityReportReasonSchema.options)
  reason!: CommunityReportReason;

  @ApiPropertyOptional({ maxLength: COMMUNITY_REPORT_DETAILS_MAX_LENGTH })
  @IsOptional()
  @IsString()
  @MaxLength(COMMUNITY_REPORT_DETAILS_MAX_LENGTH)
  details?: string;
}

export class ListCommunityReportsQuery {
  @ApiPropertyOptional({
    enum: communityReportStatusSchema.options,
    description: 'Absent : tous les statuts',
  })
  @IsOptional()
  @IsIn(communityReportStatusSchema.options)
  status?: CommunityReportStatus;

  @ApiPropertyOptional({ description: 'Curseur : id du dernier élément servi' })
  @IsOptional()
  @IsUUID()
  cursor?: string;

  @ApiPropertyOptional({ default: 50, maximum: 200 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  limit: number = 50;
}

export class UpdateCommunityReportDto {
  @ApiProperty({ enum: communityReportStatusSchema.options })
  @IsIn(communityReportStatusSchema.options)
  status!: CommunityReportStatus;
}
