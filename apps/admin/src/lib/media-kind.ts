import { MEDIA_ALLOWED_MIME_TYPES, type MediaKind } from '@carlys/api-contracts';

/**
 * Le genre d'un fichier déposé dans la bibliothèque, d'après son type MIME —
 * celui que le serveur vérifiera. Un `.glb` arrive souvent SANS type (le
 * navigateur ne le connaît pas) : l'extension tranche alors.
 */
export function mediaKindOf(file: { type: string; name: string }): MediaKind | null {
  for (const [kind, types] of Object.entries(MEDIA_ALLOWED_MIME_TYPES) as [
    MediaKind,
    readonly string[],
  ][]) {
    if (types.includes(file.type)) return kind;
  }
  if (file.type === '' && /\.(glb|gltf)$/iu.test(file.name)) return 'MESH_3D';
  return null;
}

/**
 * Le fichier tel qu'il doit partir : un `.glb` arrivé sans type serait
 * envoyé en `application/octet-stream`, que le serveur refuse ; on lui donne
 * donc le type que son extension annonce.
 */
export function withServerType(file: File): File {
  if (file.type !== '') return file;
  const type = /\.gltf$/iu.test(file.name) ? 'model/gltf+json' : 'model/gltf-binary';
  return new File([file], file.name, { type });
}

/** Ce que le sélecteur de fichiers propose : tous les types acceptés. */
export const MEDIA_ACCEPT = [
  ...Object.values(MEDIA_ALLOWED_MIME_TYPES).flat(),
  '.glb',
  '.gltf',
].join(',');
