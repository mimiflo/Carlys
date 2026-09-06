import {
  type AdminCommunityReport,
  type ApiSuccessEnvelope,
  type CursorPaginationMeta,
} from '@carlys/api-contracts';
import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Public } from '../../../../common/decorators/public.decorator';
import { requestIdOf, type RequestWithId } from '../../../../common/types/request-with-id';
import { enveloped } from '../../../../common/utilities/enveloped';
import { CurrentAdmin } from '../../../admin/presentation/decorators/current-admin.decorator';
import {
  AdminAuthGuard,
  type AdminPrincipal,
} from '../../../admin/presentation/guards/admin-auth.guard';
import {
  AdminPermissionsGuard,
  RequirePermissions,
} from '../../../admin/presentation/guards/admin-permissions.guard';
import { CommunityModerationService } from '../../application/community-moderation.service';
import {
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
  constructor(private readonly moderation: CommunityModerationService) {}

  @Get('reports')
  @RequirePermissions('community:moderate')
  @ApiOperation({
    summary: 'Signalements (filtre `status`, pagination par curseur), plus récents d’abord',
  })
  async list(
    @Query() query: ListCommunityReportsQuery,
    @Req() request: RequestWithId,
  ): Promise<ApiSuccessEnvelope<AdminCommunityReport[], CursorPaginationMeta>> {
    const page = await this.moderation.listReports(query.status, query.limit, query.cursor);
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
    return this.moderation.setReportStatus(id, dto.status, {
      adminUserId: admin.adminUserId,
      ipAddress: request.ip,
      requestId: requestIdOf(request),
    });
  }
}
