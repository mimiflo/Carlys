import { z } from 'zod';
import { communityReportSchema, communityReportStatusSchema } from './community';
import { mediaAssetSchema } from './media';
import {
  entitlementKeySchema,
  entitlementSchema,
  paymentProviderSchema,
  subscriptionStatusSchema,
} from './subscriptions';

/** Contrats de l'administration (/api/v1/admin/*) — comptes SÉPARÉS. */

/**
 * Permissions granulaires `ressource:action`. Le code est la SOURCE DE
 * VÉRITÉ de cette liste : le seed matérialise ces valeurs en base.
 */
export const ADMIN_PERMISSIONS = [
  'user:read',
  'user:update',
  'entitlement:grant',
  'exercise:read',
  'exercise:publish',
  'exercise:write',
  'media:read',
  'media:write',
  'audit:read',
  /** Lire et résoudre les signalements de la communauté. */
  'community:moderate',
] as const;

export const adminPermissionSchema = z.enum(ADMIN_PERMISSIONS);
export type AdminPermission = z.infer<typeof adminPermissionSchema>;

export const adminMeSchema = z.object({
  id: z.string(),
  email: z.string(),
  displayName: z.string(),
  roles: z.array(z.string()),
  permissions: z.array(adminPermissionSchema),
});
export type AdminMe = z.infer<typeof adminMeSchema>;

export const adminLoginResultSchema = z.object({
  accessToken: z.string(),
  expiresInSeconds: z.number(),
  admin: adminMeSchema,
});
export type AdminLoginResult = z.infer<typeof adminLoginResultSchema>;

/**
 * Le mot de passe juste n'ouvre PAS la session : il ouvre la seconde étape,
 * le code de l'appli d'authentification (double authentification). Le
 * `challengeToken` vit cinq minutes. Le secret ne passe jamais par ici : il
 * s'émet sur le terminal du serveur (`admin-bootstrap`).
 */
export const adminLoginChallengeSchema = z.object({ challengeToken: z.string() });
export type AdminLoginChallenge = z.infer<typeof adminLoginChallengeSchema>;

/** Utilisateur GÉRÉ (compte mobile), vu du back-office. */
export const managedUserStatusSchema = z.enum(['ACTIVE', 'SUSPENDED', 'DELETED']);
export type ManagedUserStatus = z.infer<typeof managedUserStatusSchema>;

export const managedUserSummarySchema = z.object({
  id: z.string(),
  email: z.string(),
  displayName: z.string().nullable(),
  status: managedUserStatusSchema,
  emailVerified: z.boolean(),
  isPremium: z.boolean(),
  createdAt: z.string(),
});
export type ManagedUserSummary = z.infer<typeof managedUserSummarySchema>;

/**
 * D'où vient l'état d'un droit, vu du back-office.
 *
 * - `SUBSCRIPTION` : l'état suit un abonnement (ouvert tant qu'il est payé,
 *   fermé quand il s'arrête) ; `provider` dit lequel.
 * - `MANUAL_GRANT` : offert à la main par l'administration. Il survit à la
 *   fin de tout abonnement.
 * - `MANUAL_REVOCATION` : coupé à la main par l'administration. Il survit à
 *   tout paiement, et BLOQUE les achats (`POST /subscriptions/checkout` rend
 *   403) : couper l'accès n'arrête pas une facturation déjà en cours.
 * - `NONE` : aucune ligne, le droit n'a jamais été ouvert.
 *
 * Les deux décisions manuelles se lèvent par
 * `DELETE /admin/users/:id/entitlements/:key`, qui rend la main à
 * l'abonnement.
 */
export const managedEntitlementSourceSchema = z.enum([
  'SUBSCRIPTION',
  'MANUAL_GRANT',
  'MANUAL_REVOCATION',
  'NONE',
]);
export type ManagedEntitlementSource = z.infer<typeof managedEntitlementSourceSchema>;

export const managedEntitlementSchema = entitlementSchema.extend({
  source: managedEntitlementSourceSchema,
  /** Fournisseur de l'abonnement, pour `source === 'SUBSCRIPTION'` seulement. */
  provider: paymentProviderSchema.optional(),
});
export type ManagedEntitlement = z.infer<typeof managedEntitlementSchema>;

/**
 * L'abonnement qui ouvre l'accès AUJOURD'HUI (essai, actif, ou période déjà
 * payée qui court encore), quelle que soit la décision manuelle posée
 * par-dessus. C'est lui qui dit « un paiement est en cours » : après une
 * coupure manuelle, les droits portent `MANUAL_REVOCATION` et ne nomment
 * plus de fournisseur, alors que la facturation, elle, continue.
 * `null` : aucun abonnement n'ouvre l'accès.
 */
export const managedPaidSubscriptionSchema = z.object({
  provider: paymentProviderSchema,
  status: subscriptionStatusSchema,
  currentPeriodEnd: z.string().nullable(),
  cancelAtPeriodEnd: z.boolean(),
});
export type ManagedPaidSubscription = z.infer<typeof managedPaidSubscriptionSchema>;

export const managedUserDetailSchema = managedUserSummarySchema.extend({
  sessionsCount: z.number(),
  completedWorkoutsCount: z.number(),
  entitlements: z.array(managedEntitlementSchema),
  /** Facultatif pour un client antérieur ; le serveur le renseigne toujours. */
  paidSubscription: managedPaidSubscriptionSchema.nullable().optional(),
});
export type ManagedUserDetail = z.infer<typeof managedUserDetailSchema>;

/** Longueur maximale de la raison d'une décision manuelle, mesurée sans les espaces autour. */
export const MANUAL_ENTITLEMENT_REASON_MAX = 500;

const manualDecisionReasonSchema = z.string().trim().min(1).max(MANUAL_ENTITLEMENT_REASON_MAX);
/** Expiration UTC ; absente = sans expiration. */
const manualDecisionExpirySchema = z.string().datetime().optional();

/**
 * La décision MANUELLE sur un droit, sans le droit visé : `isActive: true`
 * l'offre, `isActive: false` le coupe (et bloque les achats). `reason` part
 * dans l'audit. Facultative pour offrir, elle est OBLIGATOIRE pour couper
 * (400 sinon) : une coupure prive un membre d'un accès parfois payé, et
 * l'audit doit dire pourquoi.
 */
export const managedEntitlementDecisionSchema = z.discriminatedUnion('isActive', [
  z.object({
    isActive: z.literal(true),
    expiresAt: manualDecisionExpirySchema,
    reason: manualDecisionReasonSchema.optional(),
  }),
  z.object({
    isActive: z.literal(false),
    expiresAt: manualDecisionExpirySchema,
    reason: manualDecisionReasonSchema,
  }),
]);
export type ManagedEntitlementDecision = z.infer<typeof managedEntitlementDecisionSchema>;

/** PUT /admin/users/:id/entitlements — la décision, et le droit qu'elle vise. */
export const setManagedEntitlementSchema = z
  .object({ key: entitlementKeySchema })
  .and(managedEntitlementDecisionSchema);
export type SetManagedEntitlement = z.infer<typeof setManagedEntitlementSchema>;

export const adminActorTypeSchema = z.enum(['USER', 'ADMIN', 'SYSTEM']);
export type AdminActorType = z.infer<typeof adminActorTypeSchema>;

export const adminAuditLogSchema = z.object({
  id: z.string(),
  actorType: adminActorTypeSchema,
  action: z.string(),
  userId: z.string().nullable(),
  adminUserId: z.string().nullable(),
  resourceType: z.string().nullable(),
  resourceId: z.string().nullable(),
  ipAddress: z.string().nullable(),
  metadata: z.unknown().nullable(),
  createdAt: z.string(),
});
export type AdminAuditLog = z.infer<typeof adminAuditLogSchema>;

export const adminOverviewSchema = z.object({
  usersCount: z.number(),
  premiumUsersCount: z.number(),
  workoutSessionsCount: z.number(),
  completedWorkoutSessionsCount: z.number(),
  exercisesCount: z.number(),
  publishedExercisesCount: z.number(),
});
export type AdminOverview = z.infer<typeof adminOverviewSchema>;

/**
 * Exercice vu du back-office.
 *
 * Distinct du catalogue mobile sur deux points qui justifient un contrat
 * séparé : les exercices **non publiés** en font partie — c'est même leur
 * raison d'être ici — et les médias sont rendus en entier, pas seulement leur
 * URL, pour que l'écran d'administration puisse dire QUEL fichier est
 * rattaché.
 */
export const adminExerciseSummarySchema = z.object({
  id: z.string(),
  slug: z.string(),
  name: z.string(),
  isPublished: z.boolean(),
  isPremium: z.boolean(),
  primaryMuscleGroupName: z.string().nullable(),
  /** Groupes musculaires, principal en tête. */
  muscleGroupSlugs: z.array(z.string()),
  primaryMuscleGroupSlug: z.string().nullable(),
  equipmentSlugs: z.array(z.string()),
  /** Date de retrait du catalogue, `null` tant que l'exercice est vivant. */
  deletedAt: z.string().nullable(),
  image: mediaAssetSchema.nullable(),
  mesh: mediaAssetSchema.nullable(),
});
export type AdminExerciseSummary = z.infer<typeof adminExerciseSummarySchema>;

/**
 * Groupe musculaire vu du back-office.
 *
 * Le contrat mobile (`muscleGroupSchema`) ne porte que l'identité : ici il
 * faut aussi de quoi DÉCIDER — l'ordre d'affichage, et le nombre d'exercices
 * rattachés, sans lequel on supprimerait une catégorie sans savoir ce qu'elle
 * emporte.
 */
export const adminMuscleGroupSchema = z.object({
  id: z.string(),
  slug: z.string(),
  name: z.string(),
  sortOrder: z.number(),
  /** Exercices vivants dont ce groupe est le PRINCIPAL. */
  primaryExercisesCount: z.number(),
  /** Exercices vivants où il figure, tous rôles confondus. */
  exercisesCount: z.number(),
});
export type AdminMuscleGroup = z.infer<typeof adminMuscleGroupSchema>;

/** Slug de catégorie : minuscules, chiffres et tirets simples. */
export const categorySlugSchema = z
  .string()
  .min(2)
  .max(48)
  .regex(/^[a-z0-9]+(-[a-z0-9]+)*$/u);

export const createMuscleGroupSchema = z.object({
  slug: categorySlugSchema,
  name: z.string().min(2).max(48),
  sortOrder: z.number().int().min(0).max(999).optional(),
});
export type CreateMuscleGroupInput = z.infer<typeof createMuscleGroupSchema>;

export const updateMuscleGroupSchema = z.object({
  name: z.string().min(2).max(48).optional(),
  sortOrder: z.number().int().min(0).max(999).optional(),
});
export type UpdateMuscleGroupInput = z.infer<typeof updateMuscleGroupSchema>;

/**
 * Catégories d'un exercice, remplacées EN BLOC.
 *
 * Un ensemble complet plutôt que des ajouts et des retraits : c'est ce que
 * manipule l'écran (des cases à cocher), et cela rend l'appel idempotent —
 * rejouer la même requête ne peut pas dédoubler un rattachement.
 */
export const setExerciseCategoriesSchema = z.object({
  primaryMuscleGroupSlug: categorySlugSchema,
  secondaryMuscleGroupSlugs: z.array(categorySlugSchema).max(8),
  equipmentSlugs: z.array(categorySlugSchema).max(8),
});
export type SetExerciseCategoriesInput = z.infer<typeof setExerciseCategoriesSchema>;

// ── Signalements de la communauté (/admin/community/reports) ──────────────

/** Une des deux personnes d'un signalement, avec de quoi agir (fiche, e-mail). */
export const adminCommunityReportPartySchema = z.object({
  id: z.string(),
  email: z.string(),
  displayName: z.string().nullable(),
});
export type AdminCommunityReportParty = z.infer<typeof adminCommunityReportPartySchema>;

/**
 * Signalement vu du back-office : l'accusé de réception du membre, plus les
 * deux personnes et le texte de l'encouragement visé, FIGÉ au moment du
 * signalement : l'auteur a beau retirer son message ensuite
 * (`encouragementId` passe alors à `null`), la preuve reste lisible.
 * `null` seulement quand le signalement vise la personne en général.
 *
 * Un signalement de DÉFI entre amis porte, lui, les clichés du titre et du
 * message de son créateur (la personne signalée), figés de la même façon.
 * `friendChallengeTitle` non nul dit qu'un défi est visé ;
 * `friendChallengeMessage` peut rester `null` si le défi n'en portait pas.
 */
export const adminCommunityReportSchema = communityReportSchema.extend({
  reporter: adminCommunityReportPartySchema,
  reportedUser: adminCommunityReportPartySchema,
  encouragementMessage: z.string().nullable(),
  friendChallengeTitle: z.string().nullable(),
  friendChallengeMessage: z.string().nullable(),
});
export type AdminCommunityReport = z.infer<typeof adminCommunityReportSchema>;

/** PATCH /admin/community/reports/:id — résoudre, ou rouvrir par erreur. */
export const updateCommunityReportSchema = z.object({
  status: communityReportStatusSchema,
});
export type UpdateCommunityReportInput = z.infer<typeof updateCommunityReportSchema>;
