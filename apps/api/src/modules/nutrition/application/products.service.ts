import { type FoodAttribution, type PackagedFood, packagedFoodSchema } from '@carlys/api-contracts';
import { BadRequestException, HttpException, HttpStatus, Injectable } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { ProductNotFoundException } from '../../../common/filters/product-not-found.exception';
import { UserFacingUnavailableException } from '../../../common/filters/user-facing-unavailable.exception';
import { RedisService } from '../../../infrastructure/cache/redis.service';
import { normalizeBarcode } from '../domain/barcode';
import { openFoodFactsAttribution, toPackagedFood } from '../domain/open-food-facts';
import {
  OpenFoodFactsClient,
  OpenFoodFactsUnavailable,
  OpenFoodFactsUnreadable,
} from '../infrastructure/open-food-facts.client';

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
/**
 * La part d'une personne dans ce plafond, comptée seulement quand le cache
 * ne répond pas : un client qui envoie des codes jamais vus ne prive pas les
 * autres de produits nouveaux. Dix scans neufs par minute, c'est un caddie.
 */
const USER_PER_MINUTE = 10;
/** Pannes isolées (délai, réseau, 500) dans la minute avant de faire une pause. */
const FAILURES_BEFORE_PAUSE = 3;
/** Après un refus de la base, ou des pannes répétées, on la laisse respirer. */
const PAUSE_S = 30;
const PAUSE_KEY = 'nutrition:product:pause';
const BUSY_MESSAGE =
  'La base des produits ne répond pas. Réessaie dans un instant, ou saisis le repas à la main.';
const USER_BUDGET_MESSAGE =
  'Beaucoup de produits nouveaux d’un coup : réessaie dans une minute, ou saisis le repas à la main.';

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

  async byBarcode(
    raw: string,
    userId: string,
  ): Promise<{ product: PackagedFood; source: FoodAttribution }> {
    const barcode = normalizeBarcode(raw);
    if (barcode === null) {
      throw new BadRequestException('Code-barres illisible : vérifie ses chiffres.');
    }
    const product = await this.lookup(barcode, userId);
    if (product === null) {
      throw new ProductNotFoundException('Produit inconnu de la base Open Food Facts.');
    }
    return { product, source: openFoodFactsAttribution() };
  }

  private async lookup(barcode: string, userId: string): Promise<PackagedFood | null> {
    const key = `nutrition:product:v1:${barcode}`;
    const cached = await this.readCache(key, barcode);
    if (cached !== undefined) return cached;

    await this.admitOutbound(userId);
    let raw: unknown;
    try {
      raw = await this.openFoodFacts.product(barcode);
    } catch (error) {
      if (!(error instanceof OpenFoodFactsUnreadable)) {
        this.logger.warn({ err: error, barcode }, 'Open Food Facts injoignable');
        await this.noteFailure(error instanceof OpenFoodFactsUnavailable && error.saturated);
        throw new UserFacingUnavailableException(BUSY_MESSAGE);
      }
      // Une fiche qui ne se lit pas vaut « inconnu » : elle ne punit qu'elle.
      this.logger.warn({ err: error, barcode }, 'Fiche Open Food Facts inexploitable');
      raw = null;
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
   * Le produit gardé : la fiche, `null` pour « inconnu », `undefined` quand
   * rien d'utilisable n'est gardé (absent, Redis muet, valeur abîmée ou d'une
   * autre forme — on relit alors la base plutôt que de servir un 500).
   */
  private async readCache(key: string, barcode: string): Promise<PackagedFood | null | undefined> {
    const cached = await this.redis
      .getClient()
      .get(key)
      .catch((error: unknown) => {
        // Redis absent un instant : la base se lit sans cache, rien ne casse.
        this.logger.warn({ err: error }, 'Cache des produits illisible');
        return null;
      });
    if (cached === null) return undefined;
    if (cached === UNKNOWN) return null;
    const parsed = packagedFoodSchema.safeParse(parseJson(cached));
    if (parsed.success) return parsed.data;
    this.logger.warn({ barcode }, 'Fiche de produit illisible en cache');
    return undefined;
  }

  /**
   * Une lecture de plus chez Open Food Facts est-elle permise ? Non pendant
   * une pause, ni au-delà de la part de la personne (429), ni au-delà du
   * plafond commun de la minute (« très sollicité »). Redis absent : la
   * lecture passe (le plafond est une politesse envers le tiers, pas une
   * sécurité de Carlys).
   */
  private async admitOutbound(userId: string): Promise<void> {
    try {
      if ((await this.redis.getClient().exists(PAUSE_KEY)) === 1) {
        throw new UserFacingUnavailableException(BUSY_MESSAGE, 'SERVICE_BUSY');
      }
      if ((await this.countThisMinute(`nutrition:product:user:${userId}`)) > USER_PER_MINUTE) {
        throw new HttpException(USER_BUDGET_MESSAGE, HttpStatus.TOO_MANY_REQUESTS);
      }
      if ((await this.countThisMinute('nutrition:product:minute')) > OUTBOUND_PER_MINUTE) {
        throw new UserFacingUnavailableException(BUSY_MESSAGE, 'SERVICE_BUSY');
      }
    } catch (error) {
      if (error instanceof HttpException) throw error;
      this.logger.warn({ err: error }, 'Plafond Open Food Facts illisible');
    }
  }

  /**
   * Une panne de la base : une pause tout de suite si elle se dit saturée
   * (429, 503), sinon au bout de [FAILURES_BEFORE_PAUSE] dans la minute — un
   * délai dépassé isolé n'échoue que pour la personne qui l'a vécu.
   */
  private async noteFailure(saturated: boolean): Promise<void> {
    try {
      const failures = saturated
        ? FAILURES_BEFORE_PAUSE
        : await this.countThisMinute('nutrition:product:failures');
      if (failures >= FAILURES_BEFORE_PAUSE) {
        await this.redis.getClient().set(PAUSE_KEY, '1', 'EX', PAUSE_S);
      }
    } catch (error) {
      this.logger.warn({ err: error }, 'Pause Open Food Facts non écrite');
    }
  }

  /** `INCR` et `EXPIRE` d'un compteur de la minute, ensemble (`MULTI`). */
  private async countThisMinute(prefix: string): Promise<number> {
    const key = `${prefix}:${Math.floor(Date.now() / 60_000)}`;
    const replies = await this.redis.getClient().multi().incr(key).expire(key, 60).exec();
    const count = replies?.[0]?.[1];
    if (typeof count !== 'number') throw new Error(`Compteur ${key} illisible`);
    return count;
  }
}

/** Le JSON d'une valeur gardée, `undefined` s'il ne se lit pas. */
function parseJson(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    // Le refus se journalise chez l'appelant, avec le code concerné.
    return undefined;
  }
}
