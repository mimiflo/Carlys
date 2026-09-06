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

  @ApiPropertyOptional({
    description:
      'Encouragement visé. Il doit avoir été envoyé PAR la personne signalée ' +
      'AU signalant, sinon 404.',
    format: 'uuid',
  })
  @IsOptional()
  @IsUUID()
  encouragementId?: string;

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
