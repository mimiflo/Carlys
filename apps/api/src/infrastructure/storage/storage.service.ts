import {
  DeleteObjectCommand,
  HeadBucketCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { Injectable, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { AppConfigService } from '../../config/app-config.service';

/**
 * Stockage objet — **seul endroit qui connaît S3**.
 *
 * MinIO en développement, S3 (ou compatible) en production : c'est le même
 * protocole, et le reste du code ne voit qu'une clé et une URL. Aucun média
 * n'est embarqué dans une application ni écrit en dur ; ils entrent tous par
 * l'administration et sortent tous d'ici.
 */
@Injectable()
export class StorageService implements OnModuleInit, OnModuleDestroy {
  private readonly client: S3Client;

  constructor(
    private readonly config: AppConfigService,
    @InjectPinoLogger(StorageService.name)
    private readonly logger: PinoLogger,
  ) {
    this.client = new S3Client({
      endpoint: config.s3Endpoint,
      region: config.s3Region,
      // MinIO n'accepte pas les sous-domaines de bucket en local.
      forcePathStyle: config.s3ForcePathStyle,
      credentials: {
        accessKeyId: config.s3AccessKeyId,
        secretAccessKey: config.s3SecretAccessKey,
      },
    });
  }

  /**
   * Clé d'un objet : `<genre>/<id>.<extension>`.
   *
   * L'identifiant du média EST la clé — pas le nom d'origine. Deux fichiers
   * nommés `photo.jpg` ne peuvent donc pas se recouvrir, et un nom déposé par
   * un tiers ne décide jamais d'un chemin de stockage.
   */
  static keyFor(kind: string, id: string, extension: string): string {
    const safe = extension.replace(/[^a-z0-9]/gi, '').toLowerCase();
    return `${kind.toLowerCase()}/${id}${safe.length > 0 ? `.${safe}` : ''}`;
  }

  async put(key: string, body: Buffer, mimeType: string): Promise<void> {
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.config.s3Bucket,
        Key: key,
        Body: body,
        ContentType: mimeType,
        // Un an : la clé porte l'identifiant du média, donc son contenu ne
        // change jamais. Remplacer une photo, c'est déposer un autre média.
        CacheControl: 'public, max-age=31536000, immutable',
      }),
    );
  }

  async delete(key: string): Promise<void> {
    await this.client.send(new DeleteObjectCommand({ Bucket: this.config.s3Bucket, Key: key }));
  }

  /** URL publique servie à l'application. */
  urlFor(key: string): string {
    return `${this.config.s3PublicBaseUrl.replace(/\/+$/, '')}/${key}`;
  }

  /**
   * Vérifie le bucket au démarrage — sans jamais empêcher l'API de démarrer.
   *
   * Le stockage ne sert qu'aux dépôts d'administration : les applications
   * lisent les médias directement depuis son URL publique. Refuser de démarrer
   * (ou se déclarer non prêt) parce que S3 est injoignable retirerait donc du
   * trafic une API parfaitement capable de servir tout le reste. Un
   * avertissement au démarrage suffit à attraper la mauvaise configuration.
   */
  async onModuleInit(): Promise<void> {
    try {
      await this.client.send(new HeadBucketCommand({ Bucket: this.config.s3Bucket }));
    } catch (error) {
      this.logger.warn(
        { err: error, bucket: this.config.s3Bucket },
        'Bucket de médias injoignable : les dépôts échoueront',
      );
    }
  }

  /** Ferme les sockets à l'arrêt. */
  onModuleDestroy(): void {
    try {
      this.client.destroy();
    } catch (error) {
      this.logger.warn({ err: error }, 'Fermeture du client S3');
    }
  }
}
