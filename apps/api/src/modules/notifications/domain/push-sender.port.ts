/**
 * Frontière UNIQUE avec le fournisseur de push (FCM).
 *
 * Toute la logique métier — enregistrement des jetons, choix des messages,
 * purge des jetons morts — se teste contre un faux qui implémente ce port :
 * aucun test ne sort sur le réseau, et changer de fournisseur ne touche
 * qu'un fichier d'infrastructure.
 */

export interface PushMessage {
  title: string;
  body: string;
  /**
   * Données remises à l'application avec la notification, jamais affichées :
   * c'est ce qui fait qu'un toucher ouvre le bon écran (`destination`, voir
   * `PUSH_DESTINATIONS` dans `@carlys/api-contracts`). Des CHAÎNES seulement,
   * comme le champ `data` de FCM.
   */
  data?: Record<string, string>;
}

/** Résultat d'un envoi : `invalid-token` déclenche la purge du jeton. */
export type PushSendOutcome = 'sent' | 'invalid-token' | 'failed';

export interface PushSenderPort {
  /** Faux tant que le compte de service Firebase n'est pas configuré. */
  readonly enabled: boolean;

  send(token: string, message: PushMessage): Promise<PushSendOutcome>;
}

export const PUSH_SENDER_PORT = Symbol('PUSH_SENDER_PORT');
