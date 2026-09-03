import { z } from 'zod';
import { publicEnv } from './env';

/**
 * Transport HTTP commun à tout ce qui parle à l'API depuis cette
 * application : le back-office (avec son jeton d'administration) et les
 * pages publiques ouvertes depuis un e-mail (sans aucun jeton).
 *
 * Un seul endroit construit l'URL, lit le corps et traduit l'enveloppe
 * d'erreur : les deux clients ne diffèrent que par ce qu'ils mettent dans
 * `Authorization`.
 */
export class ApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
  }
}

const errorEnvelopeSchema = z.object({
  error: z.object({ message: z.string() }),
});

/** Base versionnée de l'API : `/api/v1` + chemin de la route. */
export function apiUrl(path: string): string {
  return `${publicEnv.apiBaseUrl}/api/v1${path}`;
}

function errorMessageOf(body: unknown, status: number): string {
  const envelope = errorEnvelopeSchema.safeParse(body);
  return envelope.success ? envelope.data.error.message : `Erreur ${status}`;
}

/**
 * Lit le corps (jamais sur 204 : il n'y en a pas) et convertit un statut
 * d'échec en `ApiError` porteuse du message serveur et du statut HTTP.
 */
export async function unwrapResponse(response: Response): Promise<unknown> {
  const body: unknown = response.status === 204 ? null : await response.json().catch(() => null);
  if (!response.ok) {
    throw new ApiError(errorMessageOf(body, response.status), response.status);
  }
  return body;
}

/** Requête JSON ; `token` à `null` = aucun en-tête `Authorization`. */
export async function requestJson(
  path: string,
  init: RequestInit,
  token: string | null,
): Promise<unknown> {
  const response = await fetch(apiUrl(path), {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(token === null ? {} : { Authorization: `Bearer ${token}` }),
      ...init.headers,
    },
    cache: 'no-store',
  });
  return unwrapResponse(response);
}

/**
 * Vrai quand l'échec n'est PAS une réponse de l'API : serveur injoignable,
 * coupure réseau, CORS. Le message à montrer n'est alors pas le même.
 */
export function isNetworkFailure(cause: unknown): boolean {
  return !(cause instanceof ApiError);
}
