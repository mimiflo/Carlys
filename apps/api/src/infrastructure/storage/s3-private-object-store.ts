import {
  DeleteObjectCommand,
  GetBucketPolicyCommand,
  GetObjectCommand,
  HeadBucketCommand,
  ListObjectsV2Command,
  PutObjectCommand,
  type S3Client,
} from '@aws-sdk/client-s3';
import { Injectable, type OnModuleDestroy } from '@nestjs/common';
import { AppConfigService } from '../../config/app-config.service';
import {
  type PrivateObjectStore,
  type StoredObjectPage,
  type StoredObjectSummary,
} from './private-object-store';
import { createS3Client } from './s3-client';

function errorName(error: unknown): string | undefined {
  return error instanceof Error ? error.name : undefined;
}

/** Ce que le démarrage constate du bucket privé (voir `PrivateBucketCheck`). */
export type PrivateBucketInspection =
  | { readonly state: 'ok' }
  | { readonly state: 'has-policy' }
  | { readonly state: 'unreachable' | 'policy-unknown'; readonly error: unknown };

/**
 * `PrivateObjectStore` sur S3 (MinIO en développement et sur le serveur).
 *
 * Même serveur et mêmes identifiants que les médias publics, AUTRE bucket :
 * `S3_PRIVATE_BUCKET`, que `minio-init` crée sans politique d'accès (et dont
 * il RETIRE toute politique à chaque déploiement). Voir `env.schema.ts` pour
 * la raison du second bucket.
 *
 * Ne dépend que de la configuration : la commande `meal-photos-sweep`
 * l'instancie telle quelle, hors de Nest.
 */
@Injectable()
export class S3PrivateObjectStore implements PrivateObjectStore, OnModuleDestroy {
  private readonly client: S3Client;
  readonly bucket: string;

  constructor(config: AppConfigService) {
    this.client = createS3Client(config);
    this.bucket = config.s3PrivateBucket;
  }

  async put(key: string, body: Buffer, contentType: string): Promise<void> {
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: body,
        ContentType: contentType,
        // Jamais servi directement ; si un mandataire le relayait un jour
        // par erreur, qu'aucun cache partagé ne le garde.
        CacheControl: 'private, no-store',
      }),
    );
  }

  async get(key: string): Promise<Buffer | null> {
    try {
      const response = await this.client.send(
        new GetObjectCommand({ Bucket: this.bucket, Key: key }),
      );
      if (response.Body === undefined) {
        return null;
      }
      return Buffer.from(await response.Body.transformToByteArray());
    } catch (error) {
      if (errorName(error) === 'NoSuchKey') {
        return null;
      }
      throw error;
    }
  }

  async delete(key: string): Promise<void> {
    // DeleteObject réussit sur une clé absente : l'idempotence est celle de S3.
    await this.client.send(new DeleteObjectCommand({ Bucket: this.bucket, Key: key }));
  }

  async list(prefix: string, cursor: string | null): Promise<StoredObjectPage> {
    const response = await this.client.send(
      new ListObjectsV2Command({
        Bucket: this.bucket,
        Prefix: prefix,
        ContinuationToken: cursor ?? undefined,
      }),
    );
    const objects: StoredObjectSummary[] = [];
    for (const object of response.Contents ?? []) {
      if (object.Key !== undefined) {
        objects.push({ key: object.Key, lastModified: object.LastModified ?? new Date(0) });
      }
    }
    const next = response.IsTruncated === true ? (response.NextContinuationToken ?? null) : null;
    return { objects, next };
  }

  /**
   * Le bucket existe-t-il, et est-il SANS politique d'accès ? Une politique
   * n'a aucune raison d'être sur ce bucket : si elle apparaît (commande tapée
   * à la main, mauvais nom dans le .env), elle ouvre peut-être une lecture
   * anonyme.
   */
  async inspect(): Promise<PrivateBucketInspection> {
    try {
      await this.client.send(new HeadBucketCommand({ Bucket: this.bucket }));
    } catch (error) {
      return { state: 'unreachable', error };
    }
    try {
      await this.client.send(new GetBucketPolicyCommand({ Bucket: this.bucket }));
      return { state: 'has-policy' };
    } catch (error) {
      return errorName(error) === 'NoSuchBucketPolicy'
        ? { state: 'ok' }
        : { state: 'policy-unknown', error };
    }
  }

  /** Ferme les sockets à l'arrêt. */
  onModuleDestroy(): void {
    this.client.destroy();
  }
}
