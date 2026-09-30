import { ServiceUnavailableException } from '@nestjs/common';

/**
 * Frontière UNIQUE avec le fournisseur de modèle.
 *
 * Toute la logique métier — outils, validation, quota, assemblage du prompt —
 * se teste contre un faux qui implémente ce port : aucun test ne sort sur le
 * réseau, et changer de fournisseur est un réglage (voir coach.module.ts).
 */

/** Un tour de conversation vu par le modèle. */
export interface CoachTurn {
  role: 'user' | 'assistant';
  content: string;
}

/**
 * Outil de LECTURE mis à disposition du modèle. Le coach n'en a aucun qui
 * écrive : `propose_session` et `propose_program` ne font que produire un
 * document, que le serveur valide avant de le stocker.
 */
export interface CoachToolDefinition {
  name: string;
  /** Dit QUAND appeler l'outil, pas seulement ce qu'il fait. */
  description: string;
  inputSchema: Record<string, unknown>;
}

export interface CoachToolCall {
  id: string;
  name: string;
  input: Record<string, unknown>;
}

export interface CoachToolResult {
  id: string;
  content: string;
  isError?: boolean;
}

export interface CoachTurnInput {
  /** Prompt système — stable, donc mis en cache par le fournisseur. */
  system: string;
  /**
   * Bloc système PAR UTILISATEUR (profil Carlys), placé APRÈS la césure de
   * cache : le préfixe partagé reste identique pour tous. Absent ou vide,
   * rien n'est ajouté.
   */
  systemPerUser?: string;
  tools: CoachToolDefinition[];
  history: CoachTurn[];
  /**
   * Exécute les outils demandés par le modèle. Fournie par le service : le
   * port ignore tout du domaine, il ne sait qu'appeler.
   */
  runTools: (calls: CoachToolCall[]) => Promise<CoachToolResult[]>;
  /**
   * Reçoit le texte AU FIL de sa génération (route en flux). Un fournisseur
   * qui ne sait pas streamer l'ignore : la réponse arrive alors d'un bloc,
   * dans `CoachTurnOutput.text`, qui reste la seule version archivée.
   */
  onText?: (delta: string) => void;
}

export interface CoachTurnUsage {
  inputTokens: number;
  outputTokens: number;
  /**
   * Jetons servis depuis le cache. Zéro sur des appels répétés signale un
   * préfixe cassé par une donnée volatile — la facture double en silence.
   */
  cacheReadTokens: number;
}

export interface CoachTurnOutput {
  text: string;
  /** Appel à `propose_session` retenu par le modèle, s'il y en a un. */
  proposal: Record<string, unknown> | null;
  usage: CoachTurnUsage;
  /** Le modèle a décliné : c'est un contenu, pas une panne. */
  refused: boolean;
}

export interface CoachModelPort {
  /** Toute panne du fournisseur rejette en `CoachProviderUnavailableException`. */
  reply(input: CoachTurnInput): Promise<CoachTurnOutput>;
}

/**
 * Le fournisseur a lâché en cours de tour : 503 pour le téléphone, et, pour le
 * quota et les journaux, les jetons DÉJÀ consommés avant la panne (zéro si le
 * premier appel a échoué). Le message porte un statut ou un nom d'erreur,
 * jamais la clé ; pour un 429 ou un 5xx, s'y ajoutent le champ `message` que
 * le fournisseur a écrit (160 caractères au plus) et ses en-têtes de limites
 * (`x-ratelimit-*`, `retry-after`). Un fournisseur qui recopierait la
 * demande dans ce `message` l'enverrait au journal : Mistral ne le fait pas.
 */
export class CoachProviderUnavailableException extends ServiceUnavailableException {
  constructor(
    reason: string,
    readonly usage: CoachTurnUsage,
  ) {
    super(reason);
  }
}

export const COACH_MODEL_PORT = Symbol('COACH_MODEL_PORT');

/**
 * Règles communes à TOUS les fournisseurs : chaque client les importe au lieu
 * de les recopier.
 */
/** Tours d'outils autorisés avant d'arrêter les frais. */
export const COACH_MAX_TOOL_ROUNDS = 6;
export const COACH_MAX_OUTPUT_TOKENS = 2048;
/**
 * Échéance d'un tour ENTIER (tentatives et outils compris), sous les 60 s de
 * nginx (`proxy_read_timeout`) : au-delà, le client recevrait un 504 muet
 * alors que le serveur répond encore. C'est celle de la route SANS flux.
 */
export const COACH_TURN_DEADLINE_MS = 50_000;
/**
 * Échéance d'un tour EN FLUX. Là, les 60 s de nginx ne comptent qu'entre deux
 * octets, et il en passe toujours : le texte, ou le battement de
 * `sseKeepAlive`. Sur le processeur du serveur (≈ 8 jetons/s en écriture),
 * relire des séances puis répondre dépasse souvent 50 s : couper là rendait
 * une réponse amputée. Trois minutes couvrent un tour d'outils complet.
 */
export const COACH_STREAM_DEADLINE_MS = 180_000;
/** L'échéance d'un tour selon qu'il s'écrit en flux ou d'un bloc. */
export const turnDeadlineMs = (input: Pick<CoachTurnInput, 'onText'>): number =>
  input.onText ? COACH_STREAM_DEADLINE_MS : COACH_TURN_DEADLINE_MS;
/** Un refus est un CONTENU, pas une panne : l'utilisateur doit le lire. */
export const COACH_REFUSAL_TEXT = 'Je ne peux pas répondre à cette demande.';
/** Plafond de tours atteint : on rend ce qu'on a plutôt que de boucler. */
export const COACH_GAVE_UP_TEXT = 'Je n’ai pas réussi à aboutir. Reformule ta demande ?';
