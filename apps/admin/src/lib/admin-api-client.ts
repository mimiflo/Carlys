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
const PERMISSIONS_KEY = 'carlys-admin-permissions';

export const adminToken = {
  get(): string | null {
    return typeof window === 'undefined' ? null : window.sessionStorage.getItem(TOKEN_KEY);
  },
  set(token: string): void {
    window.sessionStorage.setItem(TOKEN_KEY, token);
  },
  clear(): void {
    window.sessionStorage.removeItem(TOKEN_KEY);
    window.sessionStorage.removeItem(PERMISSIONS_KEY);
  },
};

/**
 * Les permissions de l'administrateur connecté, telles que la CONNEXION les a
 * rendues (`adminLoginResultSchema.admin.permissions`).
 *
 * La page de connexion n'en gardait que le jeton et les jetait. La navigation
 * était alors en dur : un administrateur « content-manager », qui n'a ni
 * `user:read` ni `audit:read` ni `community:moderate`, arrivait sur
 * « Utilisateurs » — la page d'accueil du back-office — et n'y voyait qu'un
 * message d'erreur lui conseillant de se reconnecter. Se reconnecter n'y
 * changeait rien : c'est son rôle, pas sa session.
 *
 * Ce n'est PAS un contrôle d'accès — celui-ci reste entièrement côté serveur,
 * sur chaque requête, où il ne peut pas être contourné. C'est de
 * l'ergonomie : ne pas proposer une porte qu'on sait fermée.
 */
export const EMPTY_PERMISSIONS: readonly string[] = Object.freeze([]);

/**
 * MÉMOÏSATION OBLIGATOIRE, pas une optimisation. `AdminShell` lit ces
 * permissions par `useSyncExternalStore`, qui compare les instantanés PAR
 * IDENTITÉ : rendre un tableau neuf à chaque appel fait conclure à React que
 * la source a changé à chaque rendu, et il coupe la boucle en levant « The
 * result of getSnapshot should be cached to avoid an infinite loop ». La
 * chaîne brute du stockage sert de clé — deux lectures de la même chaîne
 * rendent donc le même tableau, et une écriture change la chaîne.
 */
let brutEnCache: string | null = null;
let luEnCache: readonly string[] = EMPTY_PERMISSIONS;

export const adminPermissions = {
  get(): readonly string[] {
    if (typeof window === 'undefined') {
      return EMPTY_PERMISSIONS;
    }
    const brut = window.sessionStorage.getItem(PERMISSIONS_KEY);
    if (brut === brutEnCache) {
      return luEnCache;
    }
    brutEnCache = brut;
    luEnCache = brut === null ? EMPTY_PERMISSIONS : lire(brut);
    return luEnCache;
  },
  set(permissions: readonly string[]): void {
    window.sessionStorage.setItem(PERMISSIONS_KEY, JSON.stringify(permissions));
  },
};

function lire(brut: string): readonly string[] {
  try {
    const lu: unknown = JSON.parse(brut);
    return Array.isArray(lu)
      ? lu.filter((x): x is string => typeof x === 'string')
      : EMPTY_PERMISSIONS;
  } catch {
    // Stockage corrompu : on n'affiche rien de plus que le strict nécessaire
    // plutôt que de deviner.
    return EMPTY_PERMISSIONS;
  }
}

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
