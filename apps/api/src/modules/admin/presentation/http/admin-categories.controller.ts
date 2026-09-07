import { type AdminMuscleGroup, type Equipment } from '@carlys/api-contracts';
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
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Public } from '../../../../common/decorators/public.decorator';
import { type RequestWithId } from '../../../../common/types/request-with-id';
import { AdminCategoriesService } from '../../application/admin-categories.service';
import { CurrentAdmin } from '../decorators/current-admin.decorator';
import { AdminAuthGuard, type AdminPrincipal } from '../guards/admin-auth.guard';
import { AdminPermissionsGuard, RequirePermissions } from '../guards/admin-permissions.guard';
import { actorOf } from './catalog-actor';
import { CreateMuscleGroupDto, UpdateMuscleGroupDto } from './dto/catalog.dto';

/** Les CATÉGORIES du catalogue — les groupes musculaires. */
@ApiTags('admin')
@ApiBearerAuth()
@Public()
@UseGuards(AdminAuthGuard, AdminPermissionsGuard)
@Controller('admin')
export class AdminCategoriesController {
  constructor(private readonly categories: AdminCategoriesService) {}

  @Get('muscle-groups')
  @RequirePermissions('exercise:read')
  @ApiOperation({ summary: 'Catégories, avec le nombre d’exercices rattachés' })
  list(): Promise<AdminMuscleGroup[]> {
    return this.categories.list();
  }

  @Get('equipment')
  @RequirePermissions('exercise:read')
  @ApiOperation({ summary: 'Référentiel des matériels (pour l’éditeur de catégories)' })
  listEquipment(): Promise<Equipment[]> {
    return this.categories.listEquipment();
  }

  @Post('muscle-groups')
  @RequirePermissions('exercise:write')
  @ApiOperation({ summary: 'Créer une catégorie' })
  create(
    @Body() dto: CreateMuscleGroupDto,
    @CurrentAdmin() admin: AdminPrincipal,
    @Req() request: RequestWithId,
  ): Promise<AdminMuscleGroup> {
    return this.categories.create(dto, actorOf(admin, request));
  }

  @Patch('muscle-groups/:id')
  @RequirePermissions('exercise:write')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Renommer une catégorie ou changer son rang' })
  async update(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: UpdateMuscleGroupDto,
    @CurrentAdmin() admin: AdminPrincipal,
    @Req() request: RequestWithId,
  ): Promise<void> {
    await this.categories.update(id, dto, actorOf(admin, request));
  }

  @Delete('muscle-groups/:id')
  @RequirePermissions('exercise:write')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({
    summary: 'Supprimer une catégorie',
    description:
      'Refusé (409) tant qu’elle est le groupe PRINCIPAL d’un exercice : la ' +
      'contrainte de base est en cascade, la suppression passerait en silence ' +
      'et laisserait ces exercices introuvables dans la bibliothèque.',
  })
  async remove(
    @Param('id', new ParseUUIDPipe()) id: string,
    @CurrentAdmin() admin: AdminPrincipal,
    @Req() request: RequestWithId,
  ): Promise<void> {
    await this.categories.remove(id, actorOf(admin, request));
  }
}
