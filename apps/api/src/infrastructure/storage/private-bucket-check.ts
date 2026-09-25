import { Injectable, type OnModuleInit } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { S3PrivateObjectStore } from './s3-private-object-store';

/**
 * Vérifie le bucket privé au démarrage — sans jamais empêcher l'API de
 * démarrer, même politique que `StorageService` : un stockage injoignable
 * n'empêche pas de servir tout le reste.
 *
 * Une politique d'accès sur ce bucket est journalisée en ERREUR : c'est le
 * seul signal qui dirait, avant qu'une photo ne fuie, que la séparation des
 * deux buckets a été défaite à la main.
 */
@Injectable()
export class PrivateBucketCheck implements OnModuleInit {
  constructor(
    private readonly store: S3PrivateObjectStore,
    @InjectPinoLogger(PrivateBucketCheck.name) private readonly logger: PinoLogger,
  ) {}

  async onModuleInit(): Promise<void> {
    const bucket = this.store.bucket;
    const inspection = await this.store.inspect();
    switch (inspection.state) {
      case 'ok':
        return;
      case 'has-policy':
        this.logger.error(
          { bucket },
          'Le bucket PRIVÉ porte une politique d’accès : vérifie qu’elle n’ouvre aucune lecture ' +
            'anonyme (mc anonymous set none)',
        );
        return;
      case 'unreachable':
        this.logger.warn(
          { err: inspection.error, bucket },
          'Bucket privé injoignable : les photos de repas ne pourront être ni déposées ni lues',
        );
        return;
      case 'policy-unknown':
        this.logger.warn(
          { err: inspection.error, bucket },
          'Politique du bucket privé illisible : son absence n’a pas pu être vérifiée',
        );
    }
  }
}
