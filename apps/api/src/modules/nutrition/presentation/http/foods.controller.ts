import { type ApiSuccessEnvelope, type Food, type FoodSourceMeta } from '@carlys/api-contracts';
import { Controller, Get, Param, ParseIntPipe, Query, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { type RequestWithId } from '../../../../common/types/request-with-id';
import { enveloped } from '../../../../common/utilities/enveloped';
import { FoodsService } from '../../application/foods.service';
import { FOOD_SEARCH_DEFAULT_LIMIT, SearchFoodsQuery } from './dto/foods.dto';

/**
 * La base d'aliments (table CIQUAL de l'Anses), en lecture seule.
 *
 * Chaque réponse porte dans `meta.source` la mention que la licence exige
 * d'afficher à côté des valeurs (« Source : Anses, Table de composition
 * nutritionnelle des aliments Ciqual ») et la version chargée.
 */
@ApiTags('nutrition')
@ApiBearerAuth()
@Controller('nutrition/foods')
export class FoodsController {
  constructor(private readonly foods: FoodsService) {}

  @Get()
  @ApiOperation({
    summary:
      'Chercher un aliment (valeurs pour 100 g). Chaque mot doit figurer dans le ' +
      'nom ; aliments retirés exclus ; meta.source = mention à afficher',
  })
  async search(
    @Query() query: SearchFoodsQuery,
    @Req() request: RequestWithId,
  ): Promise<ApiSuccessEnvelope<Food[], FoodSourceMeta>> {
    const result = await this.foods.search(query.q, query.limit ?? FOOD_SEARCH_DEFAULT_LIMIT);
    return enveloped(result.items, { source: result.source }, request);
  }

  @Get(':code')
  @ApiOperation({ summary: 'Fiche d’un aliment (404 s’il est inconnu ou retiré)' })
  async detail(
    @Param('code', ParseIntPipe) code: number,
    @Req() request: RequestWithId,
  ): Promise<ApiSuccessEnvelope<Food, FoodSourceMeta>> {
    const result = await this.foods.detail(code);
    return enveloped(result.food, { source: result.source }, request);
  }
}
