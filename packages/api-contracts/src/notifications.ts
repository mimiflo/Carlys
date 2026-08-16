import { z } from 'zod';

/**
 * Contrats des notifications push (/api/v1/notifications).
 *
 * Le serveur stocke le NÉCESSAIRE à l'envoi (jeton FCM, plateforme) et ce
 * que la personne refuse de recevoir. Le contenu, lui, reste décidé côté
 * serveur : l'application ne demande jamais l'envoi d'une notification.
 */

export const devicePlatformSchema = z.enum(['ANDROID', 'IOS']);
export type DevicePlatform = z.infer<typeof devicePlatformSchema>;

export const registerDeviceTokenSchema = z.object({
  /** Jeton d'enregistrement FCM de l'appareil. */
  token: z.string().min(1).max(512),
  platform: devicePlatformSchema,
});
export type RegisterDeviceToken = z.infer<typeof registerDeviceTokenSchema>;

/**
 * Familles réglables séparément. Une bascule unique couperait le lien social
 * en même temps que tout le reste, alors qu'on ne refuse pas les deux pour
 * les mêmes raisons.
 */
export const notificationCategorySchema = z.enum(['FRIEND_REQUESTS', 'ENCOURAGEMENTS']);
export type NotificationCategory = z.infer<typeof notificationCategorySchema>;

export const notificationPreferenceSchema = z.object({
  category: notificationCategorySchema,
  enabled: z.boolean(),
});
export type NotificationPreference = z.infer<typeof notificationPreferenceSchema>;

/**
 * GET /notifications/preferences — TOUTES les catégories, y compris celles
 * qui n'ont jamais été réglées (elles valent `true`). Un écran qui devrait
 * deviner les manquantes finirait par diverger du serveur.
 */
export const notificationPreferencesResponseSchema = z.object({
  preferences: z.array(notificationPreferenceSchema),
});
export type NotificationPreferencesResponse = z.infer<typeof notificationPreferencesResponseSchema>;

/** PATCH /notifications/preferences — une catégorie à la fois. */
export const updateNotificationPreferenceSchema = notificationPreferenceSchema;
export type UpdateNotificationPreference = z.infer<typeof updateNotificationPreferenceSchema>;
