import { z } from 'zod';

/**
 * Bibliothèque de médias (/api/v1/admin/media).
 *
 * **Tout fichier servi par l'application entre par l'administration.** Photo
 * d'exercice aujourd'hui, maillage 3D demain : même dépôt, même stockage
 * objet, même URL. Rien n'est embarqué dans l'application, rien n'est écrit en
 * dur — ajouter une illustration ne demande donc aucune nouvelle version.
 */

export const mediaKindSchema = z.enum(['IMAGE', 'MESH_3D', 'VIDEO']);
export type MediaKind = z.infer<typeof mediaKindSchema>;

/**
 * Types acceptés par genre. Ce qui n'y figure pas est refusé au dépôt.
 *
 * Une image n'est acceptée que si l'API sait lui retirer ses métadonnées
 * (EXIF, GPS, XMP) avant de la publier : JPEG, PNG, WebP. L'AVIF en est sorti
 * le 21 octobre 2026 — son EXIF est un « item » adressé par décalages, qu'il
 * faudrait réécrire, et aucune photo du catalogue n'était en AVIF.
 */
export const MEDIA_ALLOWED_MIME_TYPES: Record<MediaKind, readonly string[]> = {
  IMAGE: ['image/webp', 'image/png', 'image/jpeg'],
  MESH_3D: ['model/gltf-binary', 'model/gltf+json'],
  VIDEO: ['video/mp4', 'video/webm'],
};

/**
 * Garde-fou mémoire du transport multipart (64 Mio).
 *
 * Le plafond *effectif* reste `MEDIA_MAX_UPLOAD_BYTES`, réglable par
 * environnement ; celui-ci existe seulement pour qu'un envoi démesuré soit
 * coupé pendant la réception, avant d'être entièrement gardé en mémoire.
 */
export const MEDIA_TRANSPORT_HARD_CAP_BYTES = 64 * 1024 * 1024;

export const mediaAssetSchema = z.object({
  id: z.string(),
  kind: mediaKindSchema,
  /** URL publique, servie par le stockage objet. */
  url: z.string(),
  mimeType: z.string(),
  byteSize: z.number(),
  width: z.number().nullable(),
  height: z.number().nullable(),
  originalName: z.string(),
  createdAt: z.string(),
});
export type MediaAsset = z.infer<typeof mediaAssetSchema>;

/**
 * Le média vu de la BIBLIOTHÈQUE du back-office : le même, plus les
 * exercices qui le montrent (photo ou maillage), supprimés compris — c'est
 * ce qui explique qu'une suppression soit refusée.
 */
export const mediaUsageSchema = z.object({ id: z.string(), name: z.string() });

export const adminMediaAssetSchema = mediaAssetSchema.extend({
  usedBy: z.array(mediaUsageSchema),
});
export type AdminMediaAsset = z.infer<typeof adminMediaAssetSchema>;
