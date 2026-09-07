import { z } from 'zod';
import { ApiError, apiUrl, requestJson, unwrapResponse } from './api-transport';

/**
 * Socle du client d'administration : le jeton, l'appel authentifié et la
 * lecture des enveloppes de l'API (`{ data, meta }`).
 *
 * Il vit à part des routes pour qu'un domaine puisse avoir son propre
 * fichier (`admin-community-api.ts`) sans dépendre en retour de
 * `admin-api.ts`, qui les rassemble : la dépendance ne va que dans un sens.
 */

const TOKEN_KEY = 'carlys-admin-token';

export const adminToken = {
  get(): string | null {
    return typeof window === 'undefined' ? null : window.sessionStorage.getItem(TOKEN_KEY);
  },
  set(token: string): void {
    window.sessionStorage.setItem(TOKEN_KEY, token);
  },
  clear(): void {
    window.sessionStorage.removeItem(TOKEN_KEY);
  },
};

const successEnvelopeSchema = z.object({ data: z.unknown() });
const pageMetaSchema = z.object({
  nextCursor: z.string().nullable(),
  hasMore: z.boolean(),
});

export interface Page<T> {
  items: T[];
  nextCursor: string | null;
  hasMore: boolean;
}

/** Extrait `data` d'une enveloppe de succès et le valide. */
export function parseData<T>(body: unknown, schema: z.ZodType<T>): T {
  const envelope = successEnvelopeSchema.safeParse(body);
  if (!envelope.success) {
    throw new ApiError('Réponse inattendue du serveur.', 0);
  }
  const parsed = schema.safeParse(envelope.data.data);
  if (!parsed.success) {
    throw new ApiError('Réponse inattendue du serveur.', 0);
  }
  return parsed.data;
}

/** Variante paginée : `data` + `meta.nextCursor`/`meta.hasMore`. */
export function parsePage<T>(body: unknown, itemSchema: z.ZodType<T>): Page<T> {
  const items = parseData(body, z.array(itemSchema));
  const meta = pageMetaSchema.safeParse(
    (body as { meta?: unknown }).meta ?? { nextCursor: null, hasMore: false },
  );
  return {
    items,
    nextCursor: meta.success ? meta.data.nextCursor : null,
    hasMore: meta.success ? meta.data.hasMore : false,
  };
}

/** Requête JSON du back-office : le jeton d'administration, s'il existe, part avec. */
export function call(path: string, init: RequestInit = {}): Promise<unknown> {
  return requestJson(path, init, adminToken.get());
}

/**
 * Dépôt de fichier — transport séparé, et pour une bonne raison : `call` pose
 * `Content-Type: application/json`, alors qu'un envoi multipart doit laisser
 * le navigateur écrire lui-même son en-tête avec la frontière (`boundary`).
 * L'imposer à la main casse le décodage côté serveur.
 */
export async function callUpload(path: string, form: FormData): Promise<unknown> {
  const token = adminToken.get();
  const response = await fetch(apiUrl(path), {
    method: 'POST',
    body: form,
    headers: token === null ? {} : { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
  return unwrapResponse(response);
}

/** Chaîne de requête : les paramètres absents ou vides ne sont pas envoyés. */
export function query(params: Record<string, string | undefined>): string {
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== '') {
      search.set(key, value);
    }
  }
  const encoded = search.toString();
  return encoded === '' ? '' : `?${encoded}`;
}
