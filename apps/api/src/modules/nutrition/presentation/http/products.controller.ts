import {
  type ApiSuccessEnvelope,
  type PackagedFood,
  type PackagedFoodMeta,
} from '@carlys/api-contracts';
import { Controller, Get, Param, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { type RequestWithId } from '../../../../common/types/request-with-id';
import { enveloped } from '../../../../common/utilities/enveloped';
import { ProductsService } from '../../application/products.service';

/** Un scan par seconde en continu, pas une aspiration de la base d'autrui. */
const PRODUCT_THROTTLE = { default: { limit: 60, ttl: 60_000 } };

/** Les produits emballés, par code-barres (Open Food Facts), en lecture seule. */
@ApiTags('nutrition')
@ApiBearerAuth()
@Controller('nutrition/products')
export class ProductsController {
  constructor(private readonly products: ProductsService) {}

  @Get(':barcode')
  @Throttle(PRODUCT_THROTTLE)
  @ApiOperation({
    summary: 'Un produit emballé par son code-barres (valeurs pour 100 g ou 100 ml)',
    description:
      'EAN-13, EAN-8, UPC-A ou GTIN-14, chiffre de contrôle vérifié (400 sinon). Lu dans ' +
      'Open Food Facts par l’API et gardé en cache ; 404 si la base ne le connaît ' +
      'pas ou ne donne pas son énergie, 503 si elle ne répond pas. ' +
      'meta.source = mention ODbL à afficher près des valeurs.',
  })
  async byBarcode(
    @Param('barcode') barcode: string,
    @Req() request: RequestWithId,
  ): Promise<ApiSuccessEnvelope<PackagedFood, PackagedFoodMeta>> {
    const result = await this.products.byBarcode(barcode);
    return enveloped(result.product, { source: result.source }, request);
  }
}
