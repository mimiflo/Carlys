import { BadRequestException } from '@nestjs/common';
import { timingSafeEqual } from 'node:crypto';

/**
 * Lecture d'un corps de webhook : JSON, puis le sous-ensemble validé par
 * `schema`. Rend aussi le JSON brut, gardé tel quel au journal des
 * événements. 400 sur un corps illisible ou invalide.
 */
export function parseWebhookBody<T>(
  rawBody: Buffer,
  schema: { safeParse: (value: unknown) => { success: boolean; data?: T } },
): { json: unknown; data: T } {
  let json: unknown;
  try {
    json = JSON.parse(rawBody.toString('utf8'));
  } catch {
    throw new BadRequestException('Corps de webhook illisible (JSON attendu).');
  }
  const result = schema.safeParse(json);
  if (!result.success || result.data === undefined) {
    throw new BadRequestException('Charge utile de webhook invalide.');
  }
  return { json, data: result.data };
}

/** L'en-tête `Authorization` porte-t-il le secret partagé ? Comparaison à temps constant. */
export function bearerMatches(authHeader: string | undefined, secret: string): boolean {
  if (authHeader === undefined) {
    return false;
  }
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : authHeader;
  const candidate = Buffer.from(token);
  const expected = Buffer.from(secret);
  return candidate.length === expected.length && timingSafeEqual(candidate, expected);
}
