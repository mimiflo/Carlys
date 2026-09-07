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
import { call, callUpload, parseData, parsePage, query, type Page } from './admin-api-client';
import { communityApi } from './admin-community-api';
import { ApiError } from './api-transport';

/**
 * Client de l'API d'administration : réponses VALIDÉES par les contrats Zod
 * partagés — un contrat cassé se voit immédiatement, jamais silencieusement.
 *
 * Le transport (URL, en-têtes, enveloppe d'erreur) vit dans `api-transport`,
 * partagé avec les pages publiques ; le jeton et la lecture des enveloppes
 * dans `admin-api-client` ; ici ne restent que les routes. La modération a
 * son propre fichier (`admin-community-api`), étalé dans `adminApi` : les
 * pages et leurs tests n'ont toujours qu'un seul objet à connaître.
 */

/** Nom historique du back-office pour l'erreur commune du transport. */
export { ApiError as AdminApiError };
export { adminToken, parseData, parsePage, type Page } from './admin-api-client';

export const adminApi = {
  // Signalements de la communauté — voir `admin-community-api.ts`.
  ...communityApi,

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
