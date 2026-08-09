import {
  type AdminAuditLog,
  type AdminExerciseSummary,
  type AdminOverview,
  type ApiSuccessEnvelope,
  type CursorPaginationMeta,
} from '@carlys/api-contracts';
import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
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
import { AdminPlatformService } from '../../application/admin-platform.service';
import { CurrentAdmin } from '../decorators/current-admin.decorator';
import { AdminAuthGuard, type AdminPrincipal } from '../guards/admin-auth.guard';
import { AdminPermissionsGuard, RequirePermissions } from '../guards/admin-permissions.guard';
import { ListAdminExercisesQuery, ListAuditLogsQuery, SetPublicationDto } from './dto/admin.dto';

/** Synthèse plateforme, journal d'audit, modération du catalogue. */
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

  @Get('exercises')
  @RequirePermissions('exercise:read')
  @ApiOperation({
    summary: 'Catalogue vu du back-office — publiés ET non publiés',
    description:
      'Le catalogue mobile ne sert que le publié : sans cette route, un ' +
      'exercice dépublié n’apparaîtrait nulle part et ne pourrait plus être ' +
      'republié.',
  })
  async exercises(
    @Query() query: ListAdminExercisesQuery,
    @Req() request: RequestWithId,
  ): Promise<ApiSuccessEnvelope<AdminExerciseSummary[], CursorPaginationMeta>> {
    const page = await this.platform.listExercises(query.limit, query.search, query.cursor);
    return enveloped(page.items, { nextCursor: page.nextCursor, hasMore: page.hasMore }, request);
  }

  @Patch('exercises/:id/publication')
  @RequirePermissions('exercise:publish')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Publier / dépublier un exercice (cache catalogue invalidé)' })
  async setPublication(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: SetPublicationDto,
    @CurrentAdmin() admin: AdminPrincipal,
    @Req() request: RequestWithId,
  ): Promise<void> {
    await this.platform.setExercisePublication(id, dto.isPublished, {
      adminUserId: admin.adminUserId,
      ipAddress: request.ip,
      requestId: requestIdOf(request),
    });
  }
}
