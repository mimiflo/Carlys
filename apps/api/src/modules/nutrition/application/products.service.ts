import { type FoodAttribution, type PackagedFood } from '@carlys/api-contracts';
import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { UserFacingUnavailableException } from '../../../common/filters/user-facing-unavailable.exception';
import { RedisService } from '../../../infrastructure/cache/redis.service';
import { normalizeBarcode } from '../domain/barcode';
import { openFoodFactsAttribution, toPackagedFood } from '../domain/open-food-facts';
import { OpenFoodFactsClient } from '../infrastructure/open-food-facts.client';

/** Une fiche change rarement : un mois. Un code inconnu peut être ajouté : un jour. */
const FOUND_TTL_S = 30 * 24 * 3600;
const UNKNOWN_TTL_S = 24 * 3600;
/** La valeur gardée pour « inconnu » : distincte de toute fiche JSON. */
const UNKNOWN = '0';
/**
 * Open Food Facts limite chaque adresse (~100 lectures par minute), et toutes
 * les demandes partent de l'adresse du SERVEUR : le plafond est donc commun à
 * tous les comptes et à tous les exemplaires de l'API, compté dans Redis.
 */
const OUTBOUND_PER_MINUTE = 80;
/** Après un refus ou une panne de la base, on la laisse respirer. */
const PAUSE_S = 30;
const PAUSE_KEY = 'nutrition:product:pause';
const BUSY_MESSAGE =
  'La base des produits ne répond pas. Réessaie dans un instant, ou saisis le repas à la main.';

/**
 * Un produit emballé par son code-barres. Open Food Facts est interrogé par
 * l'API, jamais par l'appareil (son adresse ne part pas chez un tiers), et
 * chaque réponse — trouvé comme inconnu — est gardée dans Redis : un même
 * yaourt scanné par mille personnes n'est demandé qu'une fois.
 */
@Injectable()
export class ProductsService {
  constructor(
    private readonly openFoodFacts: OpenFoodFactsClient,
    private readonly redis: RedisService,
    @InjectPinoLogger(ProductsService.name) private readonly logger: PinoLogger,
  ) {}

  async byBarcode(raw: string): Promise<{ product: PackagedFood; source: FoodAttribution }> {
    const barcode = normalizeBarcode(raw);
    if (barcode === null) {
      throw new BadRequestException('Code-barres illisible : vérifie ses chiffres.');
    }
    const product = await this.lookup(barcode);
    if (product === null) {
      throw new NotFoundException('Produit inconnu de la base Open Food Facts.');
    }
    return { product, source: openFoodFactsAttribution() };
  }

  private async lookup(barcode: string): Promise<PackagedFood | null> {
    const key = `nutrition:product:v1:${barcode}`;
    const cached = await this.redis
      .getClient()
      .get(key)
      .catch((error: unknown) => {
        // Redis absent un instant : la base se lit sans cache, rien ne casse.
        this.logger.warn({ err: error }, 'Cache des produits illisible');
        return null;
      });
    if (cached === UNKNOWN) return null;
    if (cached !== null) {
      try {
        return JSON.parse(cached) as PackagedFood;
      } catch (error) {
        // Valeur abîmée : on relit la base plutôt que de servir un 500.
        this.logger.warn({ err: error, barcode }, 'Fiche de produit illisible en cache');
      }
    }

    await this.admitOutbound();
    let raw: unknown;
    try {
      raw = await this.openFoodFacts.product(barcode);
    } catch (error) {
      this.logger.warn({ err: error, barcode }, 'Open Food Facts injoignable');
      await this.redis
        .getClient()
        .set(PAUSE_KEY, '1', 'EX', PAUSE_S)
        .catch(() => undefined);
      throw new UserFacingUnavailableException(BUSY_MESSAGE);
    }
    const product = raw === null ? null : toPackagedFood(barcode, raw);
    await this.redis
      .getClient()
      .set(
        key,
        product === null ? UNKNOWN : JSON.stringify(product),
        'EX',
        product === null ? UNKNOWN_TTL_S : FOUND_TTL_S,
      )
      .catch((error: unknown) => this.logger.warn({ err: error }, 'Cache des produits non écrit'));
    return product;
  }

  /**
   * Une lecture de plus chez Open Food Facts est-elle permise ? Non pendant
   * une pause, ni au-delà du plafond de la minute : « très sollicité », que
   * le client propose de réessayer. Redis absent : la lecture passe (le
   * plafond est une politesse envers le tiers, pas une sécurité de Carlys).
   */
  private async admitOutbound(): Promise<void> {
    const client = this.redis.getClient();
    try {
      if ((await client.exists(PAUSE_KEY)) === 1) {
        throw new UserFacingUnavailableException(BUSY_MESSAGE, 'SERVICE_BUSY');
      }
      const slot = `nutrition:product:minute:${Math.floor(Date.now() / 60_000)}`;
      const count = await client.incr(slot);
      if (count === 1) await client.expire(slot, 60);
      if (count > OUTBOUND_PER_MINUTE) {
        throw new UserFacingUnavailableException(BUSY_MESSAGE, 'SERVICE_BUSY');
      }
    } catch (error) {
      if (error instanceof UserFacingUnavailableException) throw error;
      this.logger.warn({ err: error }, 'Plafond Open Food Facts illisible');
    }
  }
}
