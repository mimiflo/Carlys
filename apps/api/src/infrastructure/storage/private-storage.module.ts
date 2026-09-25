import { Module } from '@nestjs/common';
import { PrivateBucketCheck } from './private-bucket-check';
import { PRIVATE_OBJECT_STORE } from './private-object-store';
import { S3PrivateObjectStore } from './s3-private-object-store';

/**
 * Le stockage des données PRIVÉES, derrière son port.
 *
 * Les modules qui en ont besoin l'importent et injectent
 * `PRIVATE_OBJECT_STORE` ; aucun ne voit S3. Un test d'intégration remplace
 * ce jeton par un stockage en mémoire.
 */
@Module({
  providers: [
    S3PrivateObjectStore,
    { provide: PRIVATE_OBJECT_STORE, useExisting: S3PrivateObjectStore },
    PrivateBucketCheck,
  ],
  exports: [PRIVATE_OBJECT_STORE],
})
export class PrivateStorageModule {}
