import {
  type ApiSuccessEnvelope,
  type CursorPaginationMeta,
  type ManagedUserDetail,
  type ManagedUserSummary,
} from '@carlys/api-contracts';
import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Put,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Public } from '../../../../common/decorators/public.decorator';
import { type RequestWithId } from '../../../../common/types/request-with-id';
import { enveloped } from '../../../../common/utilities/enveloped';
import { AdminUsersService } from '../../application/admin-users.service';
import { CurrentAdmin } from '../decorators/current-admin.decorator';
import { AdminAuthGuard, type AdminPrincipal } from '../guards/admin-auth.guard';
import { AdminPermissionsGuard, RequirePermissions } from '../guards/admin-permissions.guard';
import { actorOf } from './admin-actor';
import {
  ManagedEntitlementParams,
  SearchManagedUsersDto,
  SetEntitlementDto,
  SetUserStatusDto,
} from './dto/admin.dto';

/** Gestion des comptes mobiles — RBAC par permission, tout est audité. */
@ApiTags('admin')
@ApiBearerAuth()
@Public()
@UseGuards(AdminAuthGuard, AdminPermissionsGuard)
@Controller('admin/users')
export class AdminUsersController {
  constructor(private readonly users: AdminUsersService) {}

  @Post('search')
  @HttpCode(HttpStatus.OK)
  @RequirePermissions('user:read')
  @ApiOperation({
    summary: 'Utilisateurs (recherche, pagination par curseur)',
    description:
      'Terme et curseur voyagent dans le CORPS : une adresse e-mail ne doit jamais ' +
      'apparaître dans une URL, donc ni dans les journaux ni dans l’historique.',
  })
  async search(
    @Body() dto: SearchManagedUsersDto,
    @Req() request: RequestWithId,
  ): Promise<ApiSuccessEnvelope<ManagedUserSummary[], CursorPaginationMeta>> {
    const page = await this.users.listUsers(
      dto.search === '' ? undefined : dto.search,
      dto.limit,
      dto.cursor,
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
    return this.users.setUserStatus(id, dto.status, actorOf(admin, request));
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
      { isActive: dto.isActive, expiresAt: dto.expiresAt ?? null, reason: dto.reason },
      actorOf(admin, request),
    );
  }

  @Delete(':id/entitlements/:key')
  @RequirePermissions('entitlement:grant')
  @ApiOperation({
    summary: 'Rendre la main à l’abonnement : retire la décision manuelle (auditée)',
  })
  releaseEntitlement(
    @Param() params: ManagedEntitlementParams,
    @CurrentAdmin() admin: AdminPrincipal,
    @Req() request: RequestWithId,
  ): Promise<ManagedUserDetail> {
    return this.users.releaseEntitlement(params.id, params.key, actorOf(admin, request));
  }
}
