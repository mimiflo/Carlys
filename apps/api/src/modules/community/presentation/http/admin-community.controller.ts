import {
  type AdminCommunityReport,
  type ApiSuccessEnvelope,
  type CursorPaginationMeta,
} from '@carlys/api-contracts';
import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Public } from '../../../../common/decorators/public.decorator';
import { type RequestWithId } from '../../../../common/types/request-with-id';
import { enveloped } from '../../../../common/utilities/enveloped';
import { actorOf } from '../../../admin/presentation/http/admin-actor';
import { CurrentAdmin } from '../../../admin/presentation/decorators/current-admin.decorator';
import {
  AdminAuthGuard,
  type AdminPrincipal,
} from '../../../admin/presentation/guards/admin-auth.guard';
import {
  AdminPermissionsGuard,
  RequirePermissions,
} from '../../../admin/presentation/guards/admin-permissions.guard';
import { CommunityModerationDecisionService } from '../../application/community-moderation-decision.service';
import { CommunityModerationService } from '../../application/community-moderation.service';
import {
  CommunityReportDecisionDto,
  ListCommunityReportsQuery,
  UpdateCommunityReportDto,
} from './dto/community-moderation.dto';

/**
 * Signalements de la communauté, côté back-office. Même RBAC et même audit
 * que le reste de l'administration (gardes d'`AdminAccessModule`), avec une
 * permission dédiée : lire des signalements, c'est lire des conflits entre
 * personnes, pas gérer un catalogue.
 */
@ApiTags('admin')
@ApiBearerAuth()
@Public()
@UseGuards(AdminAuthGuard, AdminPermissionsGuard)
@Controller('admin/community')
export class AdminCommunityController {
  constructor(
    private readonly moderation: CommunityModerationService,
    private readonly decisions: CommunityModerationDecisionService,
  ) {}

  @Get('reports')
  @RequirePermissions('community:moderate')
  @ApiOperation({
    summary:
      'Signalements (filtres `status`, `reason`, `reportedUserId`, pagination ' +
      'par curseur), plus récents d’abord, avec les compteurs de la personne visée',
  })
  async list(
    @Query() query: ListCommunityReportsQuery,
    @Req() request: RequestWithId,
  ): Promise<ApiSuccessEnvelope<AdminCommunityReport[], CursorPaginationMeta>> {
    const page = await this.moderation.listReports(
      { status: query.status, reason: query.reason, reportedUserId: query.reportedUserId },
      query.limit,
      query.cursor,
    );
    return enveloped(page.items, { nextCursor: page.nextCursor, hasMore: page.hasMore }, request);
  }

  @Patch('reports/:id')
  @RequirePermissions('community:moderate')
  @ApiOperation({ summary: 'Résoudre (ou rouvrir) un signalement — audité' })
  setStatus(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: UpdateCommunityReportDto,
    @CurrentAdmin() admin: AdminPrincipal,
    @Req() request: RequestWithId,
  ): Promise<AdminCommunityReport> {
    return this.moderation.setReportStatus(id, dto.status, actorOf(admin, request));
  }

  @Post('reports/:id/decision')
  @HttpCode(200)
  @RequirePermissions('community:moderate')
  @ApiOperation({
    summary:
      'Trancher un signalement ouvert (retirer le contenu, suspendre, ou classer) ' +
      'et le résoudre — les signalements ouverts du même contenu retiré aussi. ' +
      'Suspendre exige aussi user:update et une note. Audité.',
  })
  decide(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: CommunityReportDecisionDto,
    @CurrentAdmin() admin: AdminPrincipal,
    @Req() request: RequestWithId,
  ): Promise<AdminCommunityReport> {
    return this.decisions.decide(id, dto, {
      ...actorOf(admin, request),
      permissions: admin.permissions,
    });
  }
}
