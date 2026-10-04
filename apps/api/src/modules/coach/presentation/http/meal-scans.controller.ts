import {
  type ApiSuccessEnvelope,
  type FoodSourceMeta,
  MEAL_PHOTO_MAX_BYTES,
  type MealScan,
} from '@carlys/api-contracts';
import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Req,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import { type AuthenticatedPrincipal } from '../../../../common/types/authenticated-request';
import { type RequestWithId } from '../../../../common/types/request-with-id';
import {
  singleFileLimits,
  UploadErrorsInFrench,
} from '../../../../common/uploads/single-file-upload';
import { enveloped } from '../../../../common/utilities/enveloped';
import { MEAL_PHOTO_TOO_LARGE } from '../../../nutrition/application/meal-photo-upload';
import { MealScansService } from '../../application/meal-scans.service';
import { StartMealScanDto } from './dto/meal-scan.dto';

/** Dix scans par minute au plus : chacun occupe le modèle des dizaines de secondes. */
const START_THROTTLE = { default: { limit: 10, ttl: 60_000 } };

/** Le scan d'une assiette par le modèle de vision (ADR 0015), en fond. */
@ApiTags('nutrition')
@ApiBearerAuth()
@Controller('nutrition/meal-scans')
export class MealScansController {
  constructor(private readonly scans: MealScansService) {}

  @Post()
  @HttpCode(HttpStatus.ACCEPTED)
  @Throttle(START_THROTTLE)
  @ApiConsumes('multipart/form-data')
  @ApiOperation({
    summary: 'Lance le scan d’une photo de repas (202, PENDING)',
    description:
      'Champ `file` : la photo en JPEG (5 Mo au plus) ; champ `id` : identifiant ' +
      'né sur l’appareil, rejouable (le même id rend le même scan). Réservé au ' +
      'droit `ai_coaching` (403) ; 503 sans modèle de vision ; 429 au-delà du ' +
      'quota du jour. Le résultat se relit par GET …/meal-scans/:id.',
  })
  @UseInterceptors(
    new UploadErrorsInFrench(MEAL_PHOTO_TOO_LARGE),
    // Coupé PENDANT la réception à 5 Mo ; un seul champ texte : l'identifiant.
    FileInterceptor('file', { limits: singleFileLimits(MEAL_PHOTO_MAX_BYTES, 1) }),
  )
  async start(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Body() body: StartMealScanDto,
    @UploadedFile() file: Express.Multer.File | undefined,
    @Req() request: RequestWithId,
  ): Promise<ApiSuccessEnvelope<MealScan, FoodSourceMeta>> {
    if (file === undefined) {
      throw new BadRequestException('Aucune photo reçue : envoie-la dans le champ « file ».');
    }
    const result = await this.scans.start(user.userId, body.id, {
      mimeType: file.mimetype,
      content: file.buffer,
    });
    return enveloped(result.scan, { source: result.source }, request);
  }

  @Get(':id')
  @ApiOperation({
    summary: 'Relit un scan : PENDING, puis DONE (aliments vus, grammes, aliment CIQUAL) ou FAILED',
  })
  async read(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', ParseUUIDPipe) id: string,
    @Req() request: RequestWithId,
  ): Promise<ApiSuccessEnvelope<MealScan, FoodSourceMeta>> {
    const result = await this.scans.read(user.userId, id);
    return enveloped(result.scan, { source: result.source }, request);
  }
}
