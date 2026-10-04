import { ConflictException } from '@nestjs/common';

/**
 * Un 409 qui ne passera pas en réessayant : l'identifiant né sur l'appareil
 * est déjà porté par un autre contenu. Le filtre d'exceptions le rend sous
 * le code `IDENTIFIER_CONFLICT`, pour que le client le distingue d'un
 * `CONFLICT` d'état passager (« le coach répond encore »).
 */
export class IdentifierConflictException extends ConflictException {}
