import {
  type ApiSuccessEnvelope,
  MEAL_PHOTO_MAX_BYTES,
  type MealEntry,
  type MealMeta,
} from '@carlys/api-contracts';
import {
  BadRequestException,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Put,
  Req,
  Res,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import {
  ApiBearerAuth,
  ApiBody,
  ApiConsumes,
  ApiOperation,
  ApiProduces,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { type Response } from 'express';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import { type AuthenticatedPrincipal } from '../../../../common/types/authenticated-request';
import { requestIdOf, type RequestWithId } from '../../../../common/types/request-with-id';
import {
  singleFileLimits,
  UploadErrorsInFrench,
} from '../../../../common/uploads/single-file-upload';
import { enveloped } from '../../../../common/utilities/enveloped';
import { MEAL_PHOTO_TOO_LARGE } from '../../application/meal-photo-upload';
import { mealMeta } from '../../application/meal-presenter';
import { MealPhotosService } from '../../application/meal-photos.service';

/**
 * Plus serré que le plafond global : un dépôt coûte une analyse, un filtre
 * et une écriture dans le stockage. Vingt par minute couvrent largement une
 * file hors ligne qui se vide ; au-delà, c'est une boucle ou un abus.
 */
const PHOTO_UPLOAD_THROTTLE = { default: { limit: 20, ttl: 60_000 } };

const NOT_FOUND = 'Repas inconnu, supprimé ou d’autrui (en lecture : aussi un repas sans photo)';

/**
 * La photo d'un repas. Authentifiée (garde JWT globale), réservée à la
 * personne qui a enregistré le repas : pour toute autre, 404.
 */
@ApiTags('nutrition')
@ApiBearerAuth()
@Controller('nutrition/meals/:id/photo')
export class MealPhotosController {
  constructor(private readonly photos: MealPhotosService) {}

  @Put()
  @Throttle(PHOTO_UPLOAD_THROTTLE)
  @ApiOperation({
    summary: 'Poser ou remplacer la photo du repas (JPEG, 5 Mo au plus, métadonnées retirées)',
    description:
      'multipart/form-data, champ « file », un seul fichier déclaré image/jpeg. Les octets ' +
      'doivent être un JPEG (signature et structure vérifiées) ; EXIF (position GPS comprise), ' +
      'XMP, IPTC et commentaires sont retirés avant stockage, dans un bucket privé. Le client ' +
      'redresse les pixels avant l’envoi : l’orientation EXIF part avec le reste. Rend le repas.',
  })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['file'],
      properties: { file: { type: 'string', format: 'binary', description: 'La photo, en JPEG' } },
    },
  })
  @ApiResponse({
    status: HttpStatus.OK,
    description:
      'Le repas, `photo.updatedAt` renouvelé (meta.source comme GET /nutrition/meals/:id)',
  })
  @ApiResponse({ status: HttpStatus.NOT_FOUND, description: NOT_FOUND })
  @ApiResponse({ status: HttpStatus.PAYLOAD_TOO_LARGE, description: 'Plus de 5 Mo' })
  @ApiResponse({ status: HttpStatus.UNSUPPORTED_MEDIA_TYPE, description: 'Pas un JPEG lisible' })
  @UseInterceptors(
    new UploadErrorsInFrench(MEAL_PHOTO_TOO_LARGE),
    // Coupé PENDANT la réception à 5 Mo ; aucun champ texte admis à côté.
    FileInterceptor('file', { limits: singleFileLimits(MEAL_PHOTO_MAX_BYTES, 0) }),
  )
  async replace(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
    @UploadedFile() file: Express.Multer.File | undefined,
    @Req() request: RequestWithId,
  ): Promise<ApiSuccessEnvelope<MealEntry, MealMeta>> {
    if (file === undefined) {
      throw new BadRequestException('Aucune photo reçue : envoie-la dans le champ « file ».');
    }
    const meal = await this.photos.replace(
      user.userId,
      id,
      { mimeType: file.mimetype, content: file.buffer },
      requestIdOf(request),
    );
    return enveloped(meal, mealMeta([meal]), request);
  }

  @Get()
  @ApiOperation({
    summary: 'Les octets de la photo (image/jpeg, Cache-Control private, ETag)',
    description:
      'Réponse binaire, sans enveloppe. `If-None-Match` avec l’ETag reçu rend 304 sans corps.',
  })
  @ApiProduces('image/jpeg')
  @ApiResponse({
    status: HttpStatus.OK,
    description: 'La photo',
    content: { 'image/jpeg': { schema: { type: 'string', format: 'binary' } } },
  })
  @ApiResponse({ status: HttpStatus.NOT_MODIFIED, description: 'Inchangée depuis cet ETag' })
  @ApiResponse({ status: HttpStatus.NOT_FOUND, description: NOT_FOUND })
  async read(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Req() request: RequestWithId,
    @Res() response: Response,
  ): Promise<void> {
    const photo = await this.photos.read(user.userId, id, requestIdOf(request));
    // `send` compare l'ETag à `If-None-Match` et répond 304 tout seul.
    // `private, no-cache` : aucun cache partagé ne la garde, et le client
    // revalide à chaque lecture — l'adresse ne change pas quand la photo
    // change, seul l'ETag le dit.
    response
      .set({
        'Content-Type': 'image/jpeg',
        'Cache-Control': 'private, no-cache',
        ETag: photo.etag,
        'Last-Modified': photo.updatedAt.toUTCString(),
      })
      .send(photo.bytes);
  }

  @Delete()
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Retirer la photo (idempotent : sans photo, 204 aussi)' })
  @ApiResponse({ status: HttpStatus.NO_CONTENT, description: 'Le repas n’a plus de photo' })
  @ApiResponse({ status: HttpStatus.NOT_FOUND, description: 'Repas inconnu, supprimé ou d’autrui' })
  remove(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Req() request: RequestWithId,
  ): Promise<void> {
    return this.photos.remove(user.userId, id, requestIdOf(request));
  }
}
