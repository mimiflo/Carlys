import { z } from 'zod';
import { communityReportSchema, communityReportStatusSchema } from './community';
import { mediaAssetSchema } from './media';
import { entitlementSchema } from './subscriptions';

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

export const managedUserDetailSchema = managedUserSummarySchema.extend({
  sessionsCount: z.number(),
  completedWorkoutsCount: z.number(),
  entitlements: z.array(entitlementSchema),
});
export type ManagedUserDetail = z.infer<typeof managedUserDetailSchema>;

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
 * deux personnes et le texte de l'encouragement visé (`null` s'il a été
 * supprimé depuis, ou si le signalement vise la personne en général).
 */
export const adminCommunityReportSchema = communityReportSchema.extend({
  reporter: adminCommunityReportPartySchema,
  reportedUser: adminCommunityReportPartySchema,
  encouragementMessage: z.string().nullable(),
});
export type AdminCommunityReport = z.infer<typeof adminCommunityReportSchema>;

/** PATCH /admin/community/reports/:id — résoudre, ou rouvrir par erreur. */
export const updateCommunityReportSchema = z.object({
  status: communityReportStatusSchema,
});
export type UpdateCommunityReportInput = z.infer<typeof updateCommunityReportSchema>;
