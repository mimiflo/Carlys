import { z } from 'zod';

/**
 * Contrats des notifications push (/api/v1/notifications).
 *
 * Le serveur ne stocke que le NÉCESSAIRE à l'envoi : le jeton FCM et la
 * plateforme. Aucune préférence de contenu ici — les notifications émises
 * sont décidées côté serveur (encouragements, demandes d'ami).
 */

export const devicePlatformSchema = z.enum(['ANDROID', 'IOS']);
export type DevicePlatform = z.infer<typeof devicePlatformSchema>;

export const registerDeviceTokenSchema = z.object({
  /** Jeton d'enregistrement FCM de l'appareil. */
  token: z.string().min(1).max(512),
  platform: devicePlatformSchema,
});
export type RegisterDeviceToken = z.infer<typeof registerDeviceTokenSchema>;
