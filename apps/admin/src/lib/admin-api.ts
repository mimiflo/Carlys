import {
  adminAuditLogSchema,
  adminExerciseSummarySchema,
  adminLoginChallengeSchema,
  adminLoginResultSchema,
  adminMeSchema,
  adminMuscleGroupSchema,
  adminOverviewSchema,
  managedUserDetailSchema,
  managedUserSummarySchema,
  equipmentSchema,
  mediaAssetSchema,
  PREMIUM_ENTITLEMENT_KEYS,
  type AdminAuditLog,
  type AdminExerciseSummary,
  type AdminLoginChallenge,
  type AdminLoginResult,
  type AdminMe,
  type AdminMuscleGroup,
  type AdminOverview,
  type Equipment,
  type SetExerciseCategoriesInput,
  type EntitlementKey,
  type ManagedEntitlementDecision,
  type SetManagedEntitlement,
  type ManagedUserDetail,
  type ManagedUserSummary,
  type MediaAsset,
  type MediaKind,
} from '@carlys/api-contracts';
import { z } from 'zod';
import { call, callUpload, parseData, parsePage, query, type Page } from './admin-api-client';
import { communityApi } from './admin-community-api';
import { ApiError, requestJson } from './api-transport';

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

/** L'erreur commune du transport, ré-exportée : les pages n'importent qu'ici. */
export { ApiError };
export {
  EMPTY_PERMISSIONS,
  adminPermissions,
  adminToken,
  parseData,
  parsePage,
  type Page,
} from './admin-api-client';

/**
 * La même décision sur chaque droit du plan premium, l'un APRÈS l'autre : la
 * dernière réponse porte donc l'état complet. La route décide droit par
 * droit, sans transaction commune : un échec en cours de route laisse les
 * premiers droits décidés, et le geste, idempotent, se rejoue tel quel.
 */
async function eachPremiumKey(
  apply: (key: EntitlementKey) => Promise<ManagedUserDetail>,
): Promise<ManagedUserDetail> {
  let detail: ManagedUserDetail | undefined;
  for (const key of PREMIUM_ENTITLEMENT_KEYS) {
    detail = await apply(key);
  }
  if (detail === undefined) {
    throw new Error('Le plan premium n’ouvre aucun droit.');
  }
  return detail;
}

export const adminApi = {
  // Signalements de la communauté — voir `admin-community-api.ts`.
  ...communityApi,

  /**
   * Sans jeton, jamais : un jeton périmé resté dans l'onglet ferait lire le
   * 401 d'un mot de passe faux comme une fin de session.
   */
  async login(email: string, password: string): Promise<AdminLoginChallenge> {
    const body = await requestJson(
      '/admin/auth/login',
      { method: 'POST', body: JSON.stringify({ email, password }) },
      null,
    );
    return parseData(body, adminLoginChallengeSchema);
  },

  /** Seconde étape : le code à 6 chiffres de l'appli ouvre la session. */
  async verifyTotp(challengeToken: string, code: string): Promise<AdminLoginResult> {
    const body = await requestJson(
      '/admin/auth/totp',
      { method: 'POST', body: JSON.stringify({ challengeToken, code }) },
      null,
    );
    return parseData(body, adminLoginResultSchema);
  },

  async me(): Promise<AdminMe> {
    return parseData(await call('/admin/auth/me'), adminMeSchema);
  },

  async overview(): Promise<AdminOverview> {
    return parseData(await call('/admin/overview'), adminOverviewSchema);
  },

  /**
   * Terme et curseur partent dans le CORPS d'un POST, jamais dans l'URL : la
   * recherche porte souvent une adresse e-mail, et une URL finit dans les
   * journaux d'accès et l'historique du navigateur.
   */
  async listUsers(search?: string, cursor?: string): Promise<Page<ManagedUserSummary>> {
    const body = await call('/admin/users/search', {
      method: 'POST',
      body: JSON.stringify({ search, cursor }),
    });
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

  /**
   * Décision MANUELLE sur un droit : `isActive: true` l'offre, `false` le
   * coupe. Une coupure survit à tout paiement ET bloque les achats ; elle
   * part avec sa raison, OBLIGATOIRE (le type l'exige, l'API rend 400 sans
   * elle), journalisée dans l'audit.
   */
  async setEntitlement(id: string, input: SetManagedEntitlement): Promise<ManagedUserDetail> {
    const body = await call(`/admin/users/${id}/entitlements`, {
      method: 'PUT',
      body: JSON.stringify(input),
    });
    return parseData(body, managedUserDetailSchema);
  },

  /**
   * Rend la main à l'abonnement : la décision manuelle disparaît et le droit
   * suit de nouveau les paiements (ouvert s'il est payé, fermé sinon).
   */
  async releaseEntitlement(id: string, key: EntitlementKey): Promise<ManagedUserDetail> {
    const body = await call(`/admin/users/${id}/entitlements/${key}`, { method: 'DELETE' });
    return parseData(body, managedUserDetailSchema);
  },

  /**
   * « Premium », au back-office, c'est TOUT le plan : chaque droit de
   * `PREMIUM_ENTITLEMENT_KEYS`. Ne viser que `premium_exercises` laissait,
   * après « Couper l'accès », le coach IA et les programmes illimités d'un
   * abonné ouverts, et « Offrir le premium » ne les ouvrait pas.
   */
  async setPremium(id: string, input: ManagedEntitlementDecision): Promise<ManagedUserDetail> {
    return eachPremiumKey((key) => adminApi.setEntitlement(id, { ...input, key }));
  },

  async releasePremium(id: string): Promise<ManagedUserDetail> {
    return eachPremiumKey((key) => adminApi.releaseEntitlement(id, key));
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
