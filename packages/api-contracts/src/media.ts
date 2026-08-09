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

/** Types acceptés par genre. Ce qui n'y figure pas est refusé au dépôt. */
export const MEDIA_ALLOWED_MIME_TYPES: Record<MediaKind, readonly string[]> = {
  IMAGE: ['image/webp', 'image/png', 'image/jpeg', 'image/avif'],
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
 * Dépôt d'un fichier. L'identifiant vient de l'ADMINISTRATION : un envoi
 * rejoué après une coupure ne crée pas un second média ni un second objet.
 */
export const uploadMediaRequestSchema = z.object({
  id: z.string().uuid(),
  kind: mediaKindSchema,
});
export type UploadMediaRequest = z.infer<typeof uploadMediaRequestSchema>;

/** Rattache un média à un exercice, ou le détache avec `null`. */
export const attachExerciseMediaRequestSchema = z.object({
  mediaId: z.string().uuid().nullable(),
});
export type AttachExerciseMediaRequest = z.infer<typeof attachExerciseMediaRequestSchema>;
