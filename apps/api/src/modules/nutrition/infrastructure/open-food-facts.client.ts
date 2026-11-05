import { Injectable } from '@nestjs/common';
import { OPEN_FOOD_FACTS_FIELDS } from '../domain/open-food-facts';

const BASE_URL = 'https://world.openfoodfacts.org';
/** Open Food Facts demande que chaque application se nomme. */
const USER_AGENT = 'Carlys/1.0 (application de fitness)';
/** Au-delà, la base est tenue pour injoignable : l'écran propose la saisie. */
const TIMEOUT_MS = 5_000;
/** Une fiche filtrée par `fields` pèse quelques Kio : au-delà, on ne lit pas. */
const MAX_BYTES = 256 * 1024;

/**
 * Open Food Facts ne répond pas. [saturated] : il le DIT (429, 503), de quoi
 * le laisser respirer ; sinon (autre 5xx), une panne à compter.
 */
export class OpenFoodFactsUnavailable extends Error {
  constructor(
    message: string,
    readonly saturated: boolean,
  ) {
    super(message);
  }
}

/** La base a répondu, mais la fiche ne se lit pas (trop lourde, pas du JSON). */
export class OpenFoodFactsUnreadable extends Error {}

/**
 * Le SEUL endroit du dépôt qui parle à Open Food Facts. Sans SDK : une route
 * en lecture, un `GET`. Rend la fiche brute (`product`), `null` si la base ne
 * connaît pas le code ; lève [OpenFoodFactsUnavailable] si elle ne répond
 * pas, [OpenFoodFactsUnreadable] si sa réponse ne se lit pas. Un délai
 * dépassé ou une coupure réseau remontent tels quels.
 */
@Injectable()
export class OpenFoodFactsClient {
  async product(barcode: string): Promise<unknown> {
    const response = await fetch(
      `${BASE_URL}/api/v2/product/${barcode}?fields=${OPEN_FOOD_FACTS_FIELDS}`,
      {
        headers: { 'User-Agent': USER_AGENT, Accept: 'application/json' },
        signal: AbortSignal.timeout(TIMEOUT_MS),
        // L'hôte est une constante : une redirection n'est jamais attendue.
        redirect: 'error',
      },
    );
    if (!response.ok) {
      await response.body?.cancel();
      // Un code inconnu : 404, avec `status: 0` dans le corps.
      if (response.status === 404) return null;
      throw new OpenFoodFactsUnavailable(
        `Open Food Facts a répondu ${response.status}`,
        response.status === 429 || response.status === 503,
      );
    }
    const body = parseObject(await readBounded(response));
    return body.status === 1 ? (body.product ?? null) : null;
  }
}

/**
 * Le corps, en n'en lisant jamais plus de [MAX_BYTES] OCTETS : refusé dès
 * l'en-tête quand il l'annonce, compté en flux sinon — et la lecture est
 * annulée au premier octet de trop.
 */
async function readBounded(response: Response): Promise<string> {
  const tooHeavy = () => new OpenFoodFactsUnreadable('Réponse d’Open Food Facts trop lourde');
  if (Number(response.headers.get('content-length')) > MAX_BYTES) {
    await response.body?.cancel();
    throw tooHeavy();
  }
  if (response.body === null) return '';
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  for (let read = await reader.read(); !read.done; read = await reader.read()) {
    size += read.value.byteLength;
    if (size > MAX_BYTES) {
      await reader.cancel();
      throw tooHeavy();
    }
    chunks.push(read.value);
  }
  return Buffer.concat(chunks).toString('utf8');
}

function parseObject(text: string): { status?: unknown; product?: unknown } {
  let body: unknown;
  try {
    body = JSON.parse(text);
  } catch (error) {
    throw new OpenFoodFactsUnreadable('Réponse d’Open Food Facts illisible', { cause: error });
  }
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    throw new OpenFoodFactsUnreadable('Réponse d’Open Food Facts sans objet');
  }
  return body;
}
