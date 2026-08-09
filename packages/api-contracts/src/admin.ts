import { z } from 'zod';
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
  image: mediaAssetSchema.nullable(),
  mesh: mediaAssetSchema.nullable(),
});
export type AdminExerciseSummary = z.infer<typeof adminExerciseSummarySchema>;
