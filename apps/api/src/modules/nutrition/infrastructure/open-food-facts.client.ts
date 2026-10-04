import { Injectable } from '@nestjs/common';
import { OPEN_FOOD_FACTS_FIELDS } from '../domain/open-food-facts';

const BASE_URL = 'https://world.openfoodfacts.org';
/** Open Food Facts demande que chaque application se nomme. */
const USER_AGENT = 'Carlys/1.0 (application de fitness)';
/** Au-delà, la base est tenue pour injoignable : l'écran propose la saisie. */
const TIMEOUT_MS = 5_000;
/** Une fiche filtrée par `fields` pèse quelques Kio : au-delà, on ne lit pas. */
const MAX_BYTES = 256 * 1024;

/** Open Food Facts refuse ou tombe (429, 5xx) : de quoi faire une pause. */
export class OpenFoodFactsUnavailable extends Error {}

/**
 * Le SEUL endroit du dépôt qui parle à Open Food Facts. Sans SDK : une route
 * en lecture, un `GET`. Rend la fiche brute (`product`), `null` si la base ne
 * connaît pas le code ; lève si elle ne répond pas.
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
    // Un code inconnu : 404, avec `status: 0` dans le corps.
    if (response.status === 404) return null;
    if (!response.ok) {
      throw new OpenFoodFactsUnavailable(`Open Food Facts a répondu ${response.status}`);
    }
    const text = await response.text();
    if (text.length > MAX_BYTES) {
      throw new OpenFoodFactsUnavailable('Réponse d’Open Food Facts trop lourde');
    }
    const body = JSON.parse(text) as { status?: unknown; product?: unknown };
    return body.status === 1 ? (body.product ?? null) : null;
  }
}
