import {
  type PrivateObjectStore,
  type StoredObjectPage,
} from '../../src/infrastructure/storage/private-object-store';

interface StoredObject {
  readonly body: Buffer;
  readonly contentType: string;
  readonly lastModified: Date;
}

/**
 * Double en mémoire du stockage PRIVÉ — tests seulement.
 *
 * Il remplace `PRIVATE_OBJECT_STORE` là où MinIO n'existe pas (poste de
 * développement, tests unitaires) ; `nutrition-photos-minio.e2e-spec.ts`
 * éprouve, en CI, le vrai stockage S3 et le caractère privé du bucket.
 *
 * `failDeletes` simule un stockage qui refuse d'effacer : c'est le cas que
 * les suppressions doivent journaliser sans échouer. `beforePut` retient un
 * dépôt PENDANT son écriture, le temps qu'une autre requête passe : c'est
 * ainsi que les suites éprouvent les courses entre un dépôt et une
 * suppression.
 */
export class InMemoryObjectStore implements PrivateObjectStore {
  readonly objects = new Map<string, StoredObject>();
  failDeletes = false;
  /** Appelé au début de chaque `put`, avant l'écriture ; `null` : aucun. */
  beforePut: ((key: string) => Promise<void>) | null = null;
  /** Taille d'une page de `list` : petite, pour éprouver la pagination. */
  pageSize = 1000;

  async put(key: string, body: Buffer, contentType: string): Promise<void> {
    if (this.beforePut !== null) {
      await this.beforePut(key);
    }
    this.objects.set(key, { body: Buffer.from(body), contentType, lastModified: new Date() });
  }

  get(key: string): Promise<Buffer | null> {
    const object = this.objects.get(key);
    return Promise.resolve(object === undefined ? null : Buffer.from(object.body));
  }

  delete(key: string): Promise<void> {
    if (this.failDeletes) {
      return Promise.reject(new Error('stockage injoignable (simulé)'));
    }
    this.objects.delete(key);
    return Promise.resolve();
  }

  list(prefix: string, cursor: string | null): Promise<StoredObjectPage> {
    const keys = [...this.objects.keys()].filter((key) => key.startsWith(prefix)).sort();
    const start = cursor === null ? 0 : keys.findIndex((key) => key > cursor);
    const slice = start < 0 ? [] : keys.slice(start, start + this.pageSize);
    const last = slice.at(-1);
    const hasMore = start >= 0 && start + this.pageSize < keys.length;
    return Promise.resolve({
      objects: slice.map((key) => ({ key, lastModified: this.objects.get(key)!.lastModified })),
      next: hasMore && last !== undefined ? last : null,
    });
  }

  /** Vieillit un objet, pour le balayage et son délai de grâce. */
  age(key: string, lastModified: Date): void {
    const object = this.objects.get(key);
    if (object !== undefined) {
      this.objects.set(key, { ...object, lastModified });
    }
  }

  keysUnder(prefix: string): string[] {
    return [...this.objects.keys()].filter((key) => key.startsWith(prefix));
  }
}
