import { S3Client } from '@aws-sdk/client-s3';
import { type AppConfigService } from '../../config/app-config.service';

/**
 * Le client S3 de Carlys, construit depuis la configuration.
 *
 * Un seul endroit pour ces réglages : le stockage des médias publics et
 * celui des données privées parlent au même serveur, avec les mêmes
 * identifiants — seul le BUCKET change, et c'est chaque service qui le nomme.
 */
export function createS3Client(config: AppConfigService): S3Client {
  return new S3Client({
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
