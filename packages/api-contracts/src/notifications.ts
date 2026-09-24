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
export const notificationCategorySchema = z.enum([
  'FRIEND_REQUESTS',
  'ENCOURAGEMENTS',
  /** Invitations à un défi entre amis — refusables à part du reste. */
  'CHALLENGE_INVITES',
]);
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

/**
 * OÙ MÈNE le toucher d'une notification : l'écran que l'application ouvre.
 *
 * Voyage dans le champ `data` du message FCM (en plus du titre et du corps
 * affichés), sous la clé `destination`. Une valeur que l'application ne
 * connaît pas (serveur plus récent) ouvre simplement l'application : la
 * liste s'allonge sans casser les versions déjà installées.
 *
 *  - `community-friends` : l'onglet Amis de la communauté (demande d'ami
 *    reçue ou acceptée, encouragement) ;
 *  - `friend-challenge` : l'écran d'un défi entre amis, dont l'identifiant
 *    voyage sous la clé `challengeId`.
 */
export const PUSH_DESTINATIONS = ['community-friends', 'friend-challenge'] as const;
export type PushDestination = (typeof PUSH_DESTINATIONS)[number];

/**
 * Le champ `data` d'une notification, tel que l'application le lit. FCM ne
 * transporte que des CHAÎNES : pas de nombre, pas d'objet imbriqué.
 */
export const pushDataSchema = z.discriminatedUnion('destination', [
  z.object({ destination: z.literal('community-friends') }),
  z.object({ destination: z.literal('friend-challenge'), challengeId: z.string().uuid() }),
]);
export type PushData = z.infer<typeof pushDataSchema>;
