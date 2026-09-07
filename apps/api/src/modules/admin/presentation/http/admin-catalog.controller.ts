import {
  type AdminExerciseSummary,
  type ApiSuccessEnvelope,
  type CursorPaginationMeta,
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
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Public } from '../../../../common/decorators/public.decorator';
import { type RequestWithId } from '../../../../common/types/request-with-id';
import { enveloped } from '../../../../common/utilities/enveloped';
import { AdminCatalogService } from '../../application/admin-catalog.service';
import { CurrentAdmin } from '../decorators/current-admin.decorator';
import { AdminAuthGuard, type AdminPrincipal } from '../guards/admin-auth.guard';
import { AdminPermissionsGuard, RequirePermissions } from '../guards/admin-permissions.guard';
import { actorOf } from './catalog-actor';
import { ListAdminExercisesQuery, SetPublicationDto } from './dto/admin.dto';
import { SetExerciseCategoriesDto } from './dto/catalog.dto';

/** Le catalogue vu du back-office : modération, suppression, classement. */
@ApiTags('admin')
@ApiBearerAuth()
@Public()
@UseGuards(AdminAuthGuard, AdminPermissionsGuard)
@Controller('admin/exercises')
export class AdminCatalogController {
  constructor(private readonly catalog: AdminCatalogService) {}

  @Get()
  @RequirePermissions('exercise:read')
  @ApiOperation({
    summary: 'Catalogue vu du back-office — publiés ET non publiés',
    description:
      'Le catalogue mobile ne sert que le publié : sans cette route, un ' +
      'exercice dépublié n’apparaîtrait nulle part et ne pourrait plus être ' +
      'republié. Les supprimés sont masqués sauf `includeDeleted`.',
  })
  async list(
    @Query() query: ListAdminExercisesQuery,
    @Req() request: RequestWithId,
  ): Promise<ApiSuccessEnvelope<AdminExerciseSummary[], CursorPaginationMeta>> {
    const page = await this.catalog.listExercises(
      query.limit,
      query.search,
      query.cursor,
      query.includeDeleted,
    );
    return enveloped(page.items, { nextCursor: page.nextCursor, hasMore: page.hasMore }, request);
  }

  @Patch(':id/publication')
  @RequirePermissions('exercise:publish')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Publier / dépublier un exercice (cache catalogue invalidé)' })
  async setPublication(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: SetPublicationDto,
    @CurrentAdmin() admin: AdminPrincipal,
    @Req() request: RequestWithId,
  ): Promise<void> {
    await this.catalog.setExercisePublication(id, dto.isPublished, actorOf(admin, request));
  }

  @Patch(':id/categories')
  @RequirePermissions('exercise:write')
  @ApiOperation({
    summary: 'Reclasser un exercice (groupes musculaires et matériels)',
    description:
      'Les listes remplacent les rattachements existants : l’appel est ' +
      'idempotent, le rejouer ne dédouble rien.',
  })
  setCategories(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: SetExerciseCategoriesDto,
    @CurrentAdmin() admin: AdminPrincipal,
    @Req() request: RequestWithId,
  ): Promise<AdminExerciseSummary> {
    return this.catalog.setExerciseCategories(id, dto, actorOf(admin, request));
  }

  @Delete(':id')
  @RequirePermissions('exercise:write')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({
    summary: 'Retirer un exercice du catalogue',
    description:
      'Suppression DOUCE : les séries déjà réalisées et les records citent ' +
      'l’exercice. Il disparaît de partout, l’historique reste intact, et ' +
      '`POST /restore` le remet.',
  })
  async remove(
    @Param('id', new ParseUUIDPipe()) id: string,
    @CurrentAdmin() admin: AdminPrincipal,
    @Req() request: RequestWithId,
  ): Promise<void> {
    await this.catalog.deleteExercise(id, actorOf(admin, request));
  }

  @Post(':id/restore')
  @RequirePermissions('exercise:write')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Restaurer un exercice supprimé (il revient dépublié)' })
  async restore(
    @Param('id', new ParseUUIDPipe()) id: string,
    @CurrentAdmin() admin: AdminPrincipal,
    @Req() request: RequestWithId,
  ): Promise<void> {
    await this.catalog.restoreExercise(id, actorOf(admin, request));
  }
}
