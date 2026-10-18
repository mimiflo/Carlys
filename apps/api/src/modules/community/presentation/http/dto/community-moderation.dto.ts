import {
  COMMUNITY_REPORT_DETAILS_MAX_LENGTH,
  COMMUNITY_REPORT_NOTE_MAX_LENGTH,
  type CommunityReportDecision,
  type CommunityReportReason,
  communityReportReasonSchema,
  type CommunityReportStatus,
  communityReportStatusSchema,
} from '@carlys/api-contracts';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsIn, IsOptional, IsString, IsUUID } from 'class-validator';
import { CursorPageQuery } from '../../../../../common/dto/cursor-page.query';
import { MaxCodePoints } from '../../../../../common/validators/max-code-points';

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

  // Compté en POINTS DE CODE, comme le contrat (`createCommunityReportSchema`).
  @ApiPropertyOptional({ maxLength: COMMUNITY_REPORT_DETAILS_MAX_LENGTH })
  @IsOptional()
  @IsString()
  @MaxCodePoints(COMMUNITY_REPORT_DETAILS_MAX_LENGTH)
  details?: string;
}

export class ListCommunityReportsQuery extends CursorPageQuery {
  @ApiPropertyOptional({
    enum: communityReportStatusSchema.options,
    description: 'Absent : tous les statuts',
  })
  @IsOptional()
  @IsIn(communityReportStatusSchema.options)
  status?: CommunityReportStatus;

  @ApiPropertyOptional({
    enum: communityReportReasonSchema.options,
    description: 'Absent : tous les motifs',
  })
  @IsOptional()
  @IsIn(communityReportReasonSchema.options)
  reason?: CommunityReportReason;

  @ApiPropertyOptional({ format: 'uuid', description: 'Les signalements visant cette personne' })
  @IsOptional()
  @IsUUID()
  reportedUserId?: string;
}

export class UpdateCommunityReportDto {
  @ApiProperty({ enum: communityReportStatusSchema.options })
  @IsIn(communityReportStatusSchema.options)
  status!: CommunityReportStatus;
}

/**
 * La décision sur un signalement ouvert. La règle « note obligatoire pour
 * suspendre » est celle du contrat (`communityReportDecisionSchema`) ; le
 * service l'applique après découpe des blancs, avec la permission
 * `user:update` qu'exige la suspension.
 */
export class CommunityReportDecisionDto implements CommunityReportDecision {
  @ApiProperty({
    description:
      'Retirer le contenu visé : l’encouragement est supprimé, le mot du défi ' +
      'effacé (son titre reste). 400 si le signalement vise la personne en ' +
      'général, 409 si le contenu n’existe plus.',
  })
  @IsBoolean()
  removeContent!: boolean;

  @ApiProperty({
    description:
      'Suspendre la personne signalée (sessions révoquées). Exige la ' +
      'permission user:update (403) et une note non vide (400).',
  })
  @IsBoolean()
  suspendUser!: boolean;

  // Compté en POINTS DE CODE, comme le contrat.
  @ApiPropertyOptional({ maxLength: COMMUNITY_REPORT_NOTE_MAX_LENGTH })
  @IsOptional()
  @IsString()
  @MaxCodePoints(COMMUNITY_REPORT_NOTE_MAX_LENGTH)
  note?: string;
}
