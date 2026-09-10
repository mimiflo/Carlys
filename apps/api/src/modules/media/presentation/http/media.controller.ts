import { MEDIA_TRANSPORT_HARD_CAP_BYTES, type MediaAsset } from '@carlys/api-contracts';
import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
  Query,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { MulterOptions } from '@nestjs/platform-express/multer/interfaces/multer-options.interface';
import { ApiBearerAuth, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Public } from '../../../../common/decorators/public.decorator';
import { requestIdOf, type RequestWithId } from '../../../../common/types/request-with-id';
import { CurrentAdmin } from '../../../admin/presentation/decorators/current-admin.decorator';
import {
  AdminAuthGuard,
  type AdminPrincipal,
} from '../../../admin/presentation/guards/admin-auth.guard';
import {
  AdminPermissionsGuard,
  RequirePermissions,
} from '../../../admin/presentation/guards/admin-permissions.guard';
import { type MediaActor, MediaService } from '../../application/media.service';
import { AttachExerciseMediaDto, ListMediaQuery, UploadMediaDto } from './dto/media.dto';

/** Acteur d'une action de média, reconstitué depuis la requête HTTP. */
function actorOf(admin: AdminPrincipal, request: RequestWithId): MediaActor {
  return {
    adminUserId: admin.adminUserId,
    requestId: requestIdOf(request),
    ipAddress: request.ip,
  };
}

// `fieldArrayIndexLimit: 0` ARME le correctif de GHSA-535w-7cp7-47q4. multer
// 2.3.0 le livre ÉTEINT (défaut `Infinity`) : l'audit de sécurité passe au
// vert sans que la protection existe. Sans elle, un nom de champ
// `a[999999999]` fait allouer un tableau creux de cette taille pendant
// l'analyse du multipart. Zéro, parce qu'aucun champ de cette route n'utilise
// la syntaxe tableau.
//
// Le type est ÉLARGI localement : @types/multer s'arrête à 2.2.0, qui ignore
// cette limite — les types sont en retard sur l'exécutable (résolu : multer
// 2.3.0, vérifié). L'intersection reste assignable au `limits` de Nest sans
// cast ni `any`, et cette déclaration disparaîtra quand @types/multer ≥ 2.3
// existera.
const LIMITES_TELEVERSEMENT: NonNullable<MulterOptions['limits']> & {
  fieldArrayIndexLimit: number;
} = {
  files: 1,
  fileSize: MEDIA_TRANSPORT_HARD_CAP_BYTES,
  fieldArrayIndexLimit: 0,
};

/**
 * Bibliothèque de médias — **la seule porte d'entrée des fichiers**.
 *
 * Photo d'exercice aujourd'hui, maillage 3D demain : même dépôt, même
 * stockage, même URL. Réservé à l'administration, avec permission dédiée.
 */
@ApiTags('admin')
@ApiBearerAuth()
@Public()
@UseGuards(AdminAuthGuard, AdminPermissionsGuard)
@Controller('admin/media')
export class MediaController {
  constructor(private readonly media: MediaService) {}

  @Post()
  @RequirePermissions('media:write')
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Dépose un fichier (rejouable : l’id vient de l’admin)' })
  @UseInterceptors(
    // Un seul fichier, coupé pendant la réception : le plafond métier
    // (MEDIA_MAX_UPLOAD_BYTES) s'applique ensuite, dans le service.
    FileInterceptor('file', { limits: LIMITES_TELEVERSEMENT }),
  )
  async upload(
    @UploadedFile() file: Express.Multer.File | undefined,
    @Body() body: UploadMediaDto,
    @CurrentAdmin() admin: AdminPrincipal,
    @Req() request: RequestWithId,
  ): Promise<MediaAsset> {
    if (file === undefined) {
      throw new BadRequestException('Aucun fichier reçu.');
    }
    return this.media.upload({
      id: body.id,
      kind: body.kind,
      mimeType: file.mimetype,
      originalName: file.originalname,
      content: file.buffer,
      actor: actorOf(admin, request),
    });
  }

  @Get()
  @RequirePermissions('media:read')
  @ApiOperation({ summary: 'Médias déposés, du plus récent au plus ancien' })
  list(@Query() query: ListMediaQuery): Promise<MediaAsset[]> {
    return this.media.list(query.kind);
  }

  @Delete(':id')
  @RequirePermissions('media:write')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({
    summary: 'Supprime un média',
    description:
      'Refusé tant qu’un exercice le référence : une photo ne doit pas ' +
      'disparaître des applications déjà installées sans décision explicite.',
  })
  remove(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentAdmin() admin: AdminPrincipal,
    @Req() request: RequestWithId,
  ): Promise<void> {
    return this.media.remove(id, actorOf(admin, request));
  }
}

/** Rattachement d'un média à un exercice. Verbe séparé du dépôt. */
@ApiTags('admin')
@ApiBearerAuth()
@Public()
@UseGuards(AdminAuthGuard, AdminPermissionsGuard)
@Controller('admin/exercises')
export class AdminExerciseMediaController {
  constructor(private readonly media: MediaService) {}

  @Put(':id/image')
  @RequirePermissions('exercise:write')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Rattache (ou détache avec `null`) la photo' })
  setImage(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: AttachExerciseMediaDto,
    @CurrentAdmin() admin: AdminPrincipal,
    @Req() request: RequestWithId,
  ): Promise<void> {
    return this.media.attachToExercise(id, 'image', body.mediaId, actorOf(admin, request));
  }

  @Put(':id/mesh')
  @RequirePermissions('exercise:write')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Rattache (ou détache) le maillage 3D' })
  setMesh(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: AttachExerciseMediaDto,
    @CurrentAdmin() admin: AdminPrincipal,
    @Req() request: RequestWithId,
  ): Promise<void> {
    return this.media.attachToExercise(id, 'mesh', body.mediaId, actorOf(admin, request));
  }
}
