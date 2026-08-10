import {
  type AdminAuditLog,
  type AdminOverview,
  type ApiSuccessEnvelope,
  type CursorPaginationMeta,
} from '@carlys/api-contracts';
import { Controller, Get, Query, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Public } from '../../../../common/decorators/public.decorator';
import { type RequestWithId } from '../../../../common/types/request-with-id';
import { enveloped } from '../../../../common/utilities/enveloped';
import { AdminPlatformService } from '../../application/admin-platform.service';
import { AdminAuthGuard } from '../guards/admin-auth.guard';
import { AdminPermissionsGuard, RequirePermissions } from '../guards/admin-permissions.guard';
import { ListAuditLogsQuery } from './dto/admin.dto';

/** Synthèse plateforme et journal d'audit. Le catalogue a son contrôleur. */
@ApiTags('admin')
@ApiBearerAuth()
@Public()
@UseGuards(AdminAuthGuard, AdminPermissionsGuard)
@Controller('admin')
export class AdminPlatformController {
  constructor(private readonly platform: AdminPlatformService) {}

  @Get('overview')
  @RequirePermissions('user:read')
  @ApiOperation({ summary: 'Synthèse de la plateforme (comptes, séances, catalogue)' })
  overview(): Promise<AdminOverview> {
    return this.platform.overview();
  }

  @Get('audit-logs')
  @RequirePermissions('audit:read')
  @ApiOperation({ summary: "Journal d'audit (append-only, pagination par curseur)" })
  async auditLogs(
    @Query() query: ListAuditLogsQuery,
    @Req() request: RequestWithId,
  ): Promise<ApiSuccessEnvelope<AdminAuditLog[], CursorPaginationMeta>> {
    const page = await this.platform.auditLogs(query.limit, query.cursor);
    return enveloped(page.items, { nextCursor: page.nextCursor, hasMore: page.hasMore }, request);
  }
}
