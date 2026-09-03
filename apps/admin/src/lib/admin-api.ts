import {
  adminAuditLogSchema,
  adminExerciseSummarySchema,
  adminLoginResultSchema,
  adminMeSchema,
  adminMuscleGroupSchema,
  adminOverviewSchema,
  managedUserDetailSchema,
  managedUserSummarySchema,
  equipmentSchema,
  mediaAssetSchema,
  type AdminAuditLog,
  type AdminExerciseSummary,
  type AdminLoginResult,
  type AdminMe,
  type AdminMuscleGroup,
  type AdminOverview,
  type Equipment,
  type SetExerciseCategoriesInput,
  type EntitlementKey,
  type ManagedUserDetail,
  type ManagedUserSummary,
  type MediaAsset,
  type MediaKind,
} from '@carlys/api-contracts';
import { z } from 'zod';
import { ApiError, apiUrl, requestJson, unwrapResponse } from './api-transport';

/**
 * Client de l'API d'administration : réponses VALIDÉES par les contrats Zod
 * partagés — un contrat cassé se voit immédiatement, jamais silencieusement.
 *
 * Le transport (URL, en-têtes, enveloppe d'erreur) vit dans `api-transport`,
 * partagé avec les pages publiques ; ici ne reste que ce qui est propre au
 * back-office : le jeton d'administration et les contrats.
 */

/** Nom historique du back-office pour l'erreur commune du transport. */
export { ApiError as AdminApiError };

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
function call(path: string, init: RequestInit = {}): Promise<unknown> {
  return requestJson(path, init, adminToken.get());
}

/**
 * Dépôt de fichier — transport séparé, et pour une bonne raison : `call` pose
 * `Content-Type: application/json`, alors qu'un envoi multipart doit laisser
 * le navigateur écrire lui-même son en-tête avec la frontière (`boundary`).
 * L'imposer à la main casse le décodage côté serveur.
 */
async function callUpload(path: string, form: FormData): Promise<unknown> {
  const token = adminToken.get();
  const response = await fetch(apiUrl(path), {
    method: 'POST',
    body: form,
    headers: token === null ? {} : { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
  return unwrapResponse(response);
}

function query(params: Record<string, string | undefined>): string {
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== '') {
      search.set(key, value);
    }
  }
  const encoded = search.toString();
  return encoded === '' ? '' : `?${encoded}`;
}

export const adminApi = {
  async login(email: string, password: string): Promise<AdminLoginResult> {
    const body = await call('/admin/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    });
    return parseData(body, adminLoginResultSchema);
  },

  async me(): Promise<AdminMe> {
    return parseData(await call('/admin/auth/me'), adminMeSchema);
  },

  async overview(): Promise<AdminOverview> {
    return parseData(await call('/admin/overview'), adminOverviewSchema);
  },

  async listUsers(search?: string, cursor?: string): Promise<Page<ManagedUserSummary>> {
    const body = await call(`/admin/users${query({ search, cursor })}`);
    return parsePage(body, managedUserSummarySchema);
  },

  async userDetail(id: string): Promise<ManagedUserDetail> {
    return parseData(await call(`/admin/users/${id}`), managedUserDetailSchema);
  },

  async setUserStatus(id: string, status: 'ACTIVE' | 'SUSPENDED'): Promise<ManagedUserSummary> {
    const body = await call(`/admin/users/${id}/status`, {
      method: 'PATCH',
      body: JSON.stringify({ status }),
    });
    return parseData(body, managedUserSummarySchema);
  },

  async setEntitlement(
    id: string,
    key: EntitlementKey,
    isActive: boolean,
  ): Promise<ManagedUserDetail> {
    const body = await call(`/admin/users/${id}/entitlements`, {
      method: 'PUT',
      body: JSON.stringify({ key, isActive }),
    });
    return parseData(body, managedUserDetailSchema);
  },

  async auditLogs(cursor?: string): Promise<Page<AdminAuditLog>> {
    const body = await call(`/admin/audit-logs${query({ cursor, limit: '50' })}`);
    return parsePage(body, adminAuditLogSchema);
  },

  // ── Catalogue et médias ────────────────────────────────────────────────

  async listExercises(
    search?: string,
    cursor?: string,
    includeDeleted = false,
  ): Promise<Page<AdminExerciseSummary>> {
    const body = await call(
      `/admin/exercises${query({ search, cursor, includeDeleted: includeDeleted ? 'true' : undefined })}`,
    );
    return parsePage(body, adminExerciseSummarySchema);
  },

  /** Retire l'exercice du catalogue — suppression douce, réversible. */
  async deleteExercise(id: string): Promise<void> {
    await call(`/admin/exercises/${id}`, { method: 'DELETE' });
  },

  async restoreExercise(id: string): Promise<void> {
    await call(`/admin/exercises/${id}/restore`, { method: 'POST' });
  },

  async setExerciseCategories(
    id: string,
    input: SetExerciseCategoriesInput,
  ): Promise<AdminExerciseSummary> {
    const body = await call(`/admin/exercises/${id}/categories`, {
      method: 'PATCH',
      body: JSON.stringify(input),
    });
    return parseData(body, adminExerciseSummarySchema);
  },

  // ── Catégories (groupes musculaires) ───────────────────────────────────

  async listMuscleGroups(): Promise<AdminMuscleGroup[]> {
    return parseData(await call('/admin/muscle-groups'), z.array(adminMuscleGroupSchema));
  },

  async createMuscleGroup(input: {
    slug: string;
    name: string;
    sortOrder?: number;
  }): Promise<AdminMuscleGroup> {
    const body = await call('/admin/muscle-groups', {
      method: 'POST',
      body: JSON.stringify(input),
    });
    return parseData(body, adminMuscleGroupSchema);
  },

  async updateMuscleGroup(id: string, input: { name?: string; sortOrder?: number }): Promise<void> {
    await call(`/admin/muscle-groups/${id}`, { method: 'PATCH', body: JSON.stringify(input) });
  },

  async deleteMuscleGroup(id: string): Promise<void> {
    await call(`/admin/muscle-groups/${id}`, { method: 'DELETE' });
  },

  /** Référentiel des matériels — l'éditeur de catégories en a besoin. */
  async listEquipment(): Promise<Equipment[]> {
    return parseData(await call('/admin/equipment'), z.array(equipmentSchema));
  },

  async setExercisePublication(id: string, isPublished: boolean): Promise<void> {
    await call(`/admin/exercises/${id}/publication`, {
      method: 'PATCH',
      body: JSON.stringify({ isPublished }),
    });
  },

  async listMedia(kind?: MediaKind): Promise<MediaAsset[]> {
    const body = await call(`/admin/media${query({ kind })}`);
    return parseData(body, z.array(mediaAssetSchema));
  },

  /**
   * L'identifiant est fabriqué ICI, pas par le serveur : c'est ce qui rend le
   * dépôt rejouable. Un envoi relancé après une coupure réseau retombe sur le
   * même média au lieu d'en créer un second.
   */
  async uploadMedia(file: File, kind: MediaKind, id: string): Promise<MediaAsset> {
    const form = new FormData();
    form.set('id', id);
    form.set('kind', kind);
    form.set('file', file);
    return parseData(await callUpload('/admin/media', form), mediaAssetSchema);
  },

  async deleteMedia(id: string): Promise<void> {
    await call(`/admin/media/${id}`, { method: 'DELETE' });
  },

  async setExerciseImage(exerciseId: string, mediaId: string | null): Promise<void> {
    await call(`/admin/exercises/${exerciseId}/image`, {
      method: 'PUT',
      body: JSON.stringify({ mediaId }),
    });
  },
};
