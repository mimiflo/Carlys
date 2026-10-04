import { type FoodSource, type MealScan, type MealScanItem } from '@carlys/api-contracts';
import {
  ConflictException,
  HttpException,
  HttpStatus,
  Injectable,
  NotFoundException,
  UnsupportedMediaTypeException,
} from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { AppConfigService } from '../../../config/app-config.service';
import { RedisService } from '../../../infrastructure/cache/redis.service';
import { FoodsService } from '../../nutrition/application/foods.service';
import { acceptMealPhoto, type PhotoUpload } from '../../nutrition/application/meal-photo-upload';
import { UserFacingUnavailableException } from '../../../common/filters/user-facing-unavailable.exception';
import { readJpegFrame } from '../../media/application/image-size';
import {
  MealImageRejectedError,
  MealVisionClient,
  VISION_TIMEOUT_MS,
} from '../infrastructure/meal-vision.client';
import { CoachAvailability } from './coach.availability';
import { CoachGateway } from './coach-gateway';
import { CoachMetrics } from '../infrastructure/coach-metrics';

/** Un scan se relit pendant une heure : de quoi revenir sur l'écran. */
const SCAN_TTL_S = 3_600;

interface StoredScan {
  readonly userId: string;
  readonly status: MealScan['status'];
  readonly items: MealScanItem[];
  readonly error: string | null;
  /** Au-delà, un scan encore « en cours » est tenu pour perdu (API relancée). */
  readonly deadline: number;
  /** Le compteur du jour où le scan a été compté : c'est lui qu'un échec rend. */
  readonly quota: string;
}

/** Le décodeur des workers lit le JPEG de base et le progressif, en 8 bits. */
const READABLE_FRAMES = new Set([0xc0, 0xc1, 0xc2]);
/** L'appli envoie 768 px ; au-delà de 4 096, une « bombe » de pixels. */
const MAX_SIDE_PX = 4_096;

/**
 * Une photo que le modèle saura lire, sans exploser sa mémoire : refusée
 * AVANT la file, elle n'occupe ni créneau ni worker.
 */
function assertVisionReadable(jpeg: Buffer): void {
  const frame = readJpegFrame(jpeg);
  const readable =
    frame !== null &&
    READABLE_FRAMES.has(frame.marker) &&
    frame.precision === 8 &&
    frame.width > 0 &&
    frame.height > 0 &&
    Math.max(frame.width, frame.height) <= MAX_SIDE_PX;
  if (!readable) {
    throw new UnsupportedMediaTypeException(
      'Photo non prise en charge par le scan : un JPEG standard de 4 096 px au plus.',
    );
  }
}

/** L'IA travaille déjà pour cette personne (le coach, ou un autre scan). */
const BUSY_MESSAGE =
  'L’IA travaille déjà pour toi (une réponse du coach ou un autre scan). Réessaie quand elle a fini.';

const FAILED_MESSAGE =
  'L’analyse de la photo n’a pas abouti. Réessaie, ou saisis le repas à la main.';

/**
 * Le scan d'une assiette (ADR 0015) : la photo, lue par le modèle de VISION
 * de nos workers, devient une liste d'aliments et de grammes ; la base CIQUAL
 * en donne les valeurs. Le modèle reconnaît, la base calcule — il n'invente
 * aucun chiffre nutritionnel.
 *
 * Le travail tourne EN FOND, dans la file du coach : sur un processeur, une
 * analyse prend des dizaines de secondes, plus que ce qu'une requête tient
 * sous nginx. Le client relit le scan (`read`) jusqu'à son résultat ; il est
 * gardé une heure dans Redis, partagé par tous les exemplaires de l'API.
 */
@Injectable()
export class MealScansService {
  constructor(
    private readonly availability: CoachAvailability,
    private readonly gateway: CoachGateway,
    private readonly vision: MealVisionClient,
    private readonly foods: FoodsService,
    private readonly redis: RedisService,
    private readonly config: AppConfigService,
    private readonly metrics: CoachMetrics,
    @InjectPinoLogger(MealScansService.name) private readonly logger: PinoLogger,
  ) {}

  /**
   * Lance le scan [id] (né sur l'appareil) : rejoué, il rend le MÊME scan,
   * sans nouvelle analyse ni tour de quota.
   */
  async start(
    userId: string,
    id: string,
    upload: PhotoUpload,
  ): Promise<{ scan: MealScan; source: FoodSource }> {
    const model = await this.availability.assertVisionAvailable(userId);
    const jpeg = acceptMealPhoto(upload);
    assertVisionReadable(jpeg);
    const existing = await this.stored(id);
    if (existing !== null) return this.present(userId, id, existing);

    const { queueTimeoutMs } = this.config.coachGateway;
    const pending: StoredScan = {
      userId,
      status: 'PENDING',
      items: [],
      error: null,
      deadline: Date.now() + queueTimeoutMs + VISION_TIMEOUT_MS + 30_000,
      quota: this.quotaKey(userId),
    };
    // L'identifiant se réserve AVANT le quota : deux envois simultanés du
    // même scan n'en comptent qu'un, et le second rend le scan du premier.
    const client = this.redis.getClient();
    const created = await client.set(this.key(id), JSON.stringify(pending), 'EX', SCAN_TTL_S, 'NX');
    if (created === null) {
      const raced = await this.stored(id);
      if (raced !== null) return this.present(userId, id, raced);
      throw new ConflictException('Scan déjà lancé, réessaie.');
    }
    try {
      await this.consumeQuota(pending.quota);
    } catch (error) {
      await client.del(this.key(id));
      throw error;
    }
    void this.run(id, model, jpeg, pending);
    return this.present(userId, id, pending);
  }

  /** Le scan [id], s'il est à cette personne (sinon : introuvable, rien de plus). */
  async read(userId: string, id: string): Promise<{ scan: MealScan; source: FoodSource }> {
    const stored = await this.stored(id);
    // Le scan d'un autre se lit comme un identifiant inconnu : rien de plus.
    if (stored === null || stored.userId !== userId) {
      throw new NotFoundException('Scan introuvable.');
    }
    return this.present(userId, id, stored);
  }

  private async run(id: string, model: string, jpeg: Buffer, pending: StoredScan): Promise<void> {
    const { userId, deadline } = pending;
    const signal = AbortSignal.timeout(Math.max(1, deadline - Date.now()));
    this.metrics.workOpen.inc();
    let result: StoredScan;
    try {
      const seen = await this.gateway.withSlot(userId, signal, () =>
        this.vision.see(model, jpeg, signal),
      );
      const items = await Promise.all(
        seen.map(async (food) => ({
          seen: food.name,
          grams: food.grams,
          food: await this.foods.closest(food.name),
        })),
      );
      result = { ...pending, status: 'DONE', items };
      this.logger.info(
        { scanId: id, foods: items.length, matched: items.filter((i) => i.food).length },
        'Scan d’assiette : terminé',
      );
    } catch (error) {
      this.logger.warn({ err: error, scanId: id }, 'Scan d’assiette : échec');
      // Une file pleine dit déjà quoi faire ; le reste se résume pour la personne.
      const message =
        error instanceof UserFacingUnavailableException
          ? error.message
          : error instanceof HttpException && error.getStatus() === 429
            ? BUSY_MESSAGE
            : FAILED_MESSAGE;
      result = { ...pending, status: 'FAILED', error: message };
      // Une image que le modèle refuse reste comptée : sinon, la renvoyer en
      // boucle ne coûterait rien.
      if (!(error instanceof MealImageRejectedError)) await this.refundQuota(pending.quota);
    }
    await this.redis
      .getClient()
      .set(this.key(id), JSON.stringify(result), 'EX', SCAN_TTL_S)
      .catch((error: unknown) =>
        this.logger.error({ err: error, scanId: id }, 'Scan d’assiette : résultat perdu'),
      )
      .finally(() => this.metrics.workOpen.dec());
  }

  private async present(
    userId: string,
    id: string,
    stored: StoredScan,
  ): Promise<{ scan: MealScan; source: FoodSource }> {
    // Relancer l'identifiant d'un autre : une collision, jamais son résultat.
    if (stored.userId !== userId) throw new ConflictException('Identifiant de scan déjà utilisé.');
    const lost = stored.status === 'PENDING' && Date.now() > stored.deadline;
    if (lost) await this.refundLost(id, stored.quota);
    return {
      scan: {
        id,
        status: lost ? 'FAILED' : stored.status,
        items: stored.items,
        error: lost ? FAILED_MESSAGE : stored.error,
      },
      source: await this.foods.source(),
    };
  }

  private async stored(id: string): Promise<StoredScan | null> {
    const raw = await this.redis.getClient().get(this.key(id));
    return raw === null ? null : (JSON.parse(raw) as StoredScan);
  }

  private key(id: string): string {
    return `coach:meal-scan:${id}`;
  }

  private quotaKey(userId: string): string {
    return `coach:meal-scans:${userId}:${new Date().toISOString().slice(0, 10)}`;
  }

  private async consumeQuota(key: string): Promise<void> {
    const client = this.redis.getClient();
    const used = await client.incr(key);
    if (used === 1) await client.expire(key, 2 * 24 * 3_600);
    const scansPerDay = this.config.coachGateway.mealScansPerDay;
    if (used > scansPerDay) {
      await client.decr(key);
      throw new HttpException(
        `Tu as fait tes ${scansPerDay} scans d’assiette du jour. Ils reviennent demain.`,
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }

  /** Un scan qui échoue (file pleine, panne) ne compte pas. */
  private async refundQuota(key: string): Promise<void> {
    await this.redis
      .getClient()
      .decr(key)
      .catch((error: unknown) => this.logger.warn({ err: error }, 'Quota de scan non rendu'));
  }

  /** Un scan perdu (API relancée en cours d'analyse) rend son quota, une fois. */
  private async refundLost(id: string, quota: string): Promise<void> {
    const first = await this.redis
      .getClient()
      .set(`${this.key(id)}:rendu`, '1', 'EX', SCAN_TTL_S, 'NX');
    if (first !== null) await this.refundQuota(quota);
  }
}
