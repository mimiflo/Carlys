import { Injectable } from '@nestjs/common';
import { z } from 'zod';
import { AppConfigService } from '../../../config/app-config.service';
import { CoachWorkerPool } from './coach-worker-pool';

/**
 * Le worker a REFUSÉ la photo (4xx) : la faute à l'image, pas au worker. Il
 * reste en service, et le scan, compté.
 */
export class MealImageRejectedError extends Error {}

/** Ce que le modèle a vu : un nom d'aliment et sa masse estimée. */
export interface SeenFood {
  readonly name: string;
  readonly grams: number;
}

/** Au-delà, une assiette n'est plus une assiette : le reste est ignoré. */
const MAX_FOODS = 8;
const MAX_GRAMS = 2_000;
/** Une liste courte, en JSON : quelques centaines de jetons suffisent. */
const MAX_OUTPUT_TOKENS = 400;
/**
 * Plafond d'UNE analyse, file non comprise : 130 s au pire au banc, modèle à
 * charger compris ; sous les 300 s où le `fetch` de Node renonce de lui-même
 * à attendre des en-têtes.
 */
export const VISION_TIMEOUT_MS = 240_000;

const PROMPT =
  'Tu analyses la photo d’un repas pour un journal alimentaire. Liste chaque aliment ' +
  'VISIBLE dans l’assiette, avec un nom court et générique en français, tel qu’il ' +
  'apparaît dans une table de composition nutritionnelle (ex. « Poulet, filet, grillé », ' +
  '« Riz blanc, cuit », « Brocoli, cuit »), et estime sa masse en grammes d’après une ' +
  'assiette standard de 26 cm. N’invente rien qui ne se voie pas ; si la photo ne ' +
  'montre pas de repas, rends une liste vide. Réponds uniquement en JSON.';

/** Le format imposé au modèle (sortie structurée, appliquée par Ollama). */
const SCHEMA = {
  type: 'object',
  properties: {
    aliments: {
      type: 'array',
      maxItems: MAX_FOODS,
      items: {
        type: 'object',
        properties: {
          nom: { type: 'string' },
          grammes: { type: 'integer', minimum: 1, maximum: MAX_GRAMS },
        },
        required: ['nom', 'grammes'],
      },
    },
  },
  required: ['aliments'],
};

/** Ce qui revient se relit sans confiance : le modèle peut s'en écarter. */
const answerSchema = z.object({
  aliments: z
    .array(z.object({ nom: z.string(), grammes: z.number() }).catch({ nom: '', grammes: 0 }))
    .catch([]),
});

/**
 * La photo d'un repas, lue par le modèle de VISION de nos workers (ADR 0015)
 * — les mêmes machines que le coach, par la même API compatible OpenAI. Le
 * créneau, lui, se prend dans la file du coach (`CoachGateway.withSlot`).
 */
@Injectable()
export class MealVisionClient {
  constructor(
    private readonly config: AppConfigService,
    private readonly pool: CoachWorkerPool,
  ) {}

  async see(model: string, jpeg: Buffer, signal: AbortSignal): Promise<SeenFood[]> {
    const worker = this.pool.acquire();
    let failed = true;
    const bounded = AbortSignal.any([signal, AbortSignal.timeout(VISION_TIMEOUT_MS)]);
    try {
      const { apiKey } = this.config.coachProvider;
      const response = await fetch(`${worker.url.replace(/\/+$/, '')}/chat/completions`, {
        method: 'POST',
        signal: bounded,
        headers: {
          'Content-Type': 'application/json',
          ...(apiKey === undefined ? {} : { Authorization: `Bearer ${apiKey}` }),
        },
        body: JSON.stringify({
          model,
          temperature: 0,
          max_tokens: MAX_OUTPUT_TOKENS,
          response_format: { type: 'json_schema', json_schema: { name: 'repas', schema: SCHEMA } },
          messages: [
            {
              role: 'user',
              content: [
                { type: 'text', text: PROMPT },
                {
                  type: 'image_url',
                  image_url: { url: `data:image/jpeg;base64,${jpeg.toString('base64')}` },
                },
              ],
            },
          ],
        }),
      });
      if (response.status >= 400 && response.status < 500) {
        failed = false;
        throw new MealImageRejectedError(`Modèle de vision : ${response.status}`);
      }
      if (!response.ok) throw new Error(`Modèle de vision : ${response.status}`);
      const body = (await response.json()) as {
        choices?: { message?: { content?: unknown } }[];
      };
      failed = false;
      return parseSeenFoods(body.choices?.[0]?.message?.content);
    } finally {
      // Une annulation ou un délai dépassé (processeur lent) ne disent rien
      // du worker : seule une panne l'écarte.
      this.pool.release(worker, failed && !bounded.aborted);
    }
  }
}

/** La réponse du modèle, bornée : noms non vides, grammes entiers de 1 à 2 000. */
export function parseSeenFoods(content: unknown): SeenFood[] {
  let raw: unknown;
  try {
    raw = typeof content === 'string' ? JSON.parse(content) : null;
  } catch {
    return [];
  }
  const parsed = answerSchema.safeParse(raw);
  if (!parsed.success) return [];
  return parsed.data.aliments
    .map((item) => ({
      name: item.nom
        .replace(/[\p{Cc}\p{Cf}]/gu, ' ')
        .trim()
        .replace(/\s+/g, ' ')
        .slice(0, 80),
      grams: Math.round(item.grammes),
    }))
    .filter((item) => item.name !== '' && item.grams >= 1 && item.grams <= MAX_GRAMS)
    .slice(0, MAX_FOODS);
}
