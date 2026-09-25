/**
 * Stockage des objets PRIVÉS — données personnelles, jamais publiques.
 *
 * Un PORT, et non une classe S3 directement injectée : les services métier
 * ne savent pas où vivent les octets, et un test d'intégration peut y
 * substituer un stockage en mémoire (`test/support/in-memory-object-store.ts`)
 * pour éprouver les routes sans MinIO.
 *
 * Ce qui distingue ce stockage de `StorageService` (médias publics) :
 * - un bucket À PART (`S3_PRIVATE_BUCKET`), sans aucune politique de lecture
 *   anonyme ;
 * - aucune URL : on ne lit un objet qu'en passant par l'API, qui vérifie à
 *   qui il appartient avant de rendre ses octets.
 */
export const PRIVATE_OBJECT_STORE = Symbol('PRIVATE_OBJECT_STORE');

export interface StoredObjectSummary {
  readonly key: string;
  /** Instant du dépôt : le balayage des orphelins épargne les tout récents. */
  readonly lastModified: Date;
}

export interface StoredObjectPage {
  readonly objects: readonly StoredObjectSummary[];
  /** Curseur de la page suivante, `null` à la dernière. */
  readonly next: string | null;
}

export interface PrivateObjectStore {
  put(key: string, body: Buffer, contentType: string): Promise<void>;
  /** Les octets de l'objet, ou `null` s'il n'existe pas. */
  get(key: string): Promise<Buffer | null>;
  /** Idempotent : supprimer un objet absent aboutit. */
  delete(key: string): Promise<void>;
  /** Une page des objets dont la clé commence par `prefix`. */
  list(prefix: string, cursor: string | null): Promise<StoredObjectPage>;
}

/**
 * Supprime TOUS les objets sous un préfixe, page par page. Rend leur nombre.
 *
 * Écrit une fois, au-dessus du port : l'implémentation S3 et le double de
 * test en mémoire suivent donc exactement le même chemin.
 */
export async function deleteEverythingUnder(
  store: PrivateObjectStore,
  prefix: string,
): Promise<number> {
  let deleted = 0;
  let cursor: string | null = null;
  do {
    const page: StoredObjectPage = await store.list(prefix, cursor);
    for (const object of page.objects) {
      await store.delete(object.key);
      deleted += 1;
    }
    cursor = page.next;
  } while (cursor !== null);
  return deleted;
}
