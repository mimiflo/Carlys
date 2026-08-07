import {
  type ApiSuccessEnvelope,
  type CursorPaginationMeta,
  type ManagedUserDetail,
  type ManagedUserSummary,
} from '@carlys/api-contracts';
import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Put,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Public } from '../../../../common/decorators/public.decorator';
import { requestIdOf, type RequestWithId } from '../../../../common/types/request-with-id';
import { enveloped } from '../../../../common/utilities/enveloped';
import { AdminUsersService } from '../../application/admin-users.service';
import { CurrentAdmin } from '../decorators/current-admin.decorator';
import { AdminAuthGuard, type AdminPrincipal } from '../guards/admin-auth.guard';
import { AdminPermissionsGuard, RequirePermissions } from '../guards/admin-permissions.guard';
import { ListManagedUsersQuery, SetEntitlementDto, SetUserStatusDto } from './dto/admin.dto';

/** Gestion des comptes mobiles — RBAC par permission, tout est audité. */
@ApiTags('admin')
@ApiBearerAuth()
@Public()
@UseGuards(AdminAuthGuard, AdminPermissionsGuard)
@Controller('admin/users')
export class AdminUsersController {
  constructor(private readonly users: AdminUsersService) {}

  @Get()
  @RequirePermissions('user:read')
  @ApiOperation({ summary: 'Utilisateurs (recherche, pagination par curseur)' })
  async list(
    @Query() query: ListManagedUsersQuery,
    @Req() request: RequestWithId,
  ): Promise<ApiSuccessEnvelope<ManagedUserSummary[], CursorPaginationMeta>> {
    const page = await this.users.listUsers(
      query.search === '' ? undefined : query.search,
      query.limit,
      query.cursor,
    );
    return enveloped(page.items, { nextCursor: page.nextCursor, hasMore: page.hasMore }, request);
  }

  @Get(':id')
  @RequirePermissions('user:read')
  @ApiOperation({ summary: "Fiche d'un utilisateur (activité, droits)" })
  detail(@Param('id', new ParseUUIDPipe()) id: string): Promise<ManagedUserDetail> {
    return this.users.userDetail(id);
  }

  @Patch(':id/status')
  @RequirePermissions('user:update')
  @ApiOperation({ summary: 'Suspendre / réactiver (suspension = sessions révoquées)' })
  setStatus(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: SetUserStatusDto,
    @CurrentAdmin() admin: AdminPrincipal,
    @Req() request: RequestWithId,
  ): Promise<ManagedUserSummary> {
    return this.users.setUserStatus(id, dto.status, {
      adminUserId: admin.adminUserId,
      ipAddress: request.ip,
      requestId: requestIdOf(request),
    });
  }

  @Put(':id/entitlements')
  @RequirePermissions('entitlement:grant')
  @ApiOperation({ summary: 'Attribution manuelle d’un droit (auditée)' })
  setEntitlement(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: SetEntitlementDto,
    @CurrentAdmin() admin: AdminPrincipal,
    @Req() request: RequestWithId,
  ): Promise<ManagedUserDetail> {
    return this.users.setEntitlement(
      id,
      dto.key,
      { isActive: dto.isActive, expiresAt: dto.expiresAt ?? null },
      {
        adminUserId: admin.adminUserId,
        ipAddress: request.ip,
        requestId: requestIdOf(request),
      },
    );
  }
}
