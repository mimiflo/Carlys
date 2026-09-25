import { type ApiSuccessEnvelope, type MealEntry, type MealMeta } from '@carlys/api-contracts';
import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  Req,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import { type AuthenticatedPrincipal } from '../../../../common/types/authenticated-request';
import { requestIdOf, type RequestWithId } from '../../../../common/types/request-with-id';
import { enveloped } from '../../../../common/utilities/enveloped';
import { mealMeta } from '../../application/meal-presenter';
import { MealsService } from '../../application/meals.service';
import { CreateMealDto, ListMealsQuery, UpdateMealDto } from './dto/meals.dto';

/**
 * `meta.source` : la mention de la table CIQUAL, dès qu'un repas rendu porte
 * des aliments de la base (voir `mealMeta`) ; absente sinon.
 */
@ApiTags('nutrition')
@ApiBearerAuth()
@Controller('nutrition/meals')
export class MealsController {
  constructor(private readonly meals: MealsService) {}

  @Post()
  @HttpCode(201)
  @ApiOperation({
    summary:
      'Ajouter un repas (id client, création idempotente) : saisi à la main (kcal), ' +
      'ou composé d’aliments (components, chaque ligne sous un UUID de l’appareil) dont ' +
      'le serveur calcule les totaux ; meta.source = mention CIQUAL à afficher',
  })
  async add(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Body() dto: CreateMealDto,
    @Req() request: RequestWithId,
  ): Promise<ApiSuccessEnvelope<MealEntry, MealMeta>> {
    // Recopié tel quel, comme la correction : un champ calculé ENVOYÉ avec
    // des aliments (même à null) doit rester visible du service, qui le
    // refuse. Un `?? null` ici l'aurait confondu avec l'absence.
    const meal = await this.meals.add(user.userId, dto);
    return enveloped(meal, mealMeta([meal]), request);
  }

  @Get(':id')
  @ApiOperation({
    summary: 'Un repas, composants compris (404 s’il est inconnu, supprimé ou d’autrui)',
  })
  async get(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Req() request: RequestWithId,
  ): Promise<ApiSuccessEnvelope<MealEntry, MealMeta>> {
    const meal = await this.meals.get(user.userId, id);
    return enveloped(meal, mealMeta([meal]), request);
  }

  @Patch(':id')
  @ApiOperation({
    summary:
      'Corriger un repas : un champ absent reste tel quel, un champ à null ' +
      'efface ce qu’on croyait savoir ; components remplace (ou, vide, retire) la ' +
      'composition, une ligne désignée par son id gardant son instantané',
  })
  async update(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: UpdateMealDto,
    @Req() request: RequestWithId,
  ): Promise<ApiSuccessEnvelope<MealEntry, MealMeta>> {
    // Le DTO est recopié tel quel : `undefined` (« n'y touche pas ») et
    // `null` (« efface ») doivent traverser sans être confondus, ce qu'un
    // `?? null` ferait exactement.
    const meal = await this.meals.update(user.userId, id, dto);
    return enveloped(meal, mealMeta([meal]), request);
  }

  @Get()
  @ApiOperation({
    summary:
      'Repas entre deux instants UTC — le client envoie les bornes de SA ' +
      'journée locale, le serveur ne devine jamais le fuseau',
  })
  async list(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Query() query: ListMealsQuery,
    @Req() request: RequestWithId,
  ): Promise<ApiSuccessEnvelope<MealEntry[], MealMeta>> {
    const meals = await this.meals.list(user.userId, query.from, query.to);
    return enveloped(meals, mealMeta(meals), request);
  }

  @Delete(':id')
  @HttpCode(204)
  @ApiOperation({
    summary: 'Retirer un repas (suppression douce, idempotente) ; sa photo est effacée avec lui',
  })
  remove(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Req() request: RequestWithId,
  ): Promise<void> {
    return this.meals.remove(user.userId, id, requestIdOf(request));
  }
}
