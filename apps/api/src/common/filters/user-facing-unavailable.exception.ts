import { ServiceUnavailableException } from '@nestjs/common';

/**
 * Un 503 dont le message est ÉCRIT POUR LA PERSONNE : le filtre d'exceptions
 * le laisse passer, là où il remplace tout autre message 5xx par « Une
 * erreur interne est survenue. » (un message serveur peut citer un objet
 * interne). Celui-ci ne cite rien : il dit quoi faire, et surtout ce qui n'a
 * PAS eu lieu — ce qu'une erreur générique tairait.
 */
export class UserFacingUnavailableException extends ServiceUnavailableException {
  /**
   * `SERVICE_BUSY` : debout mais saturé — le client propose de réessayer
   * plutôt que d'annoncer une panne.
   */
  constructor(
    message: string,
    readonly code: 'SERVICE_UNAVAILABLE' | 'SERVICE_BUSY' = 'SERVICE_UNAVAILABLE',
  ) {
    super(message);
  }
}
