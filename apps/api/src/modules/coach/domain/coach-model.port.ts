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
   * Lectures DÉJÀ faites pour cette question (coach-prefetch.ts) : présentées
   * au modèle comme des outils appelés, avant qu'il n'écrive un mot.
   */
  prefetched?: { call: CoachToolCall; result: CoachToolResult }[];
  /**
   * Exécute les outils demandés par le modèle. Fournie par le service : le
   * port ignore tout du domaine, il ne sait qu'appeler.
   */
  runTools: (calls: CoachToolCall[]) => Promise<CoachToolResult[]>;
  /**
   * Apprend chaque appel d'outil demandé par le modèle, AVANT son exécution,
   * propositions comprises (`propose_session` n'est jamais exécutée) : les
   * étapes de la réflexion montrée à la personne (coach-steps.ts).
   */
  onToolCalls?: (calls: CoachToolCall[]) => void;
  /**
   * Reçoit le texte AU FIL de sa génération (route en flux). Un fournisseur
   * qui ne sait pas streamer l'ignore : la réponse arrive alors d'un bloc,
   * dans `CoachTurnOutput.text`, qui reste la seule version archivée.
   */
  onText?: (delta: string) => void;
  /**
   * Annulation par l'appelant (écran fermé, « Arrêter », réseau coupé) : le
   * client abandonne l'appel au worker, qui arrête alors de générer. Une
   * génération que personne ne lira ne doit pas voler la place d'une autre.
   */
  signal?: AbortSignal;
  /** Échéance propre à cet appel (travail de fond) ; sinon celle du tour. */
  timeoutMs?: number;
  /** Plafond de sortie propre à cet appel (un résumé est court). */
  maxOutputTokens?: number;
  /**
   * Nos workers seulement, jamais le repli cloud : un résumé de mémoire ne
   * quitte pas le serveur (politique de confidentialité).
   */
  localOnly?: boolean;
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

/**
 * Comment un appel au modèle s'est arrêté. Qu'il cesse d'envoyer des jetons
 * ne dit pas que la réponse est finie : `MAX_TOKENS` est une coupure.
 */
export type FinishReason =
  | 'NORMAL_STOP'
  | 'MAX_TOKENS'
  | 'CONTEXT_LIMIT'
  | 'TIMEOUT'
  | 'CLIENT_DISCONNECT'
  | 'WORKER_ERROR'
  | 'STREAM_ERROR'
  | 'CANCELLED'
  | 'UNKNOWN';

/** Le bilan de fin d'un tour : ce que mesurent journaux et métriques. */
export interface CoachGeneration {
  /** La fin du dernier appel. */
  finishReason: FinishReason;
  /** La fin de chaque appel au modèle du tour, reprises comprises. */
  ends: FinishReason[];
  continuations: number;
  /** Reprises qui ont terminé une réponse coupée. */
  recovered: number;
  /** Reprises superflues (« FIN » : la réponse était finie). */
  unneeded: number;
  /** Réponse rendue incomplète, faute de reprise possible. */
  truncated: boolean;
}

export interface CoachTurnOutput {
  text: string;
  /** Appel à `propose_session` retenu par le modèle, s'il y en a un. */
  proposal: Record<string, unknown> | null;
  usage: CoachTurnUsage;
  /** Le modèle a décliné : c'est un contenu, pas une panne. */
  refused: boolean;
  /** Worker qui a servi le tour (hôte seul) : mesure, jamais secret. */
  worker?: string;
  /** Modèle qui a répondu (repli cloud compris). */
  model?: string;
  /** Absent : le fournisseur ne le mesure pas (Anthropic). */
  generation?: CoachGeneration;
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
    readonly end: FinishReason = 'UNKNOWN',
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
/**
 * Échéance d'un tour ENTIER (tentatives et outils compris), sous les 60 s de
 * nginx (`proxy_read_timeout`) : au-delà, le client recevrait un 504 muet
 * alors que le serveur répond encore. C'est celle de la route SANS flux.
 */
export const COACH_TURN_DEADLINE_MS = 50_000;
/**
 * Le signal d'un tour : son échéance, et l'annulation de qui l'a demandé.
 *
 * En flux, l'échéance est `COACH_REQUEST_TIMEOUT_MS` (10 min par défaut), un
 * PLAFOND : les 60 s de nginx ne comptent qu'entre deux octets, et il en
 * passe toujours — le texte, ou le battement de `sseKeepAlive`. Sur le
 * processeur du serveur (≈ 8 jetons/s), 2 048 jetons prennent plus de 4 min ;
 * un worker muet, lui, est coupé par le délai d'inactivité du flux
 * (`COACH_STREAM_IDLE_TIMEOUT_MS`, coach-worker-requests.ts).
 * D'un bloc, c'est `COACH_TURN_DEADLINE_MS`, sous nginx.
 */
export function turnSignal(
  input: Pick<CoachTurnInput, 'onText' | 'signal' | 'timeoutMs'>,
  streamTimeoutMs: number,
): AbortSignal {
  const deadline = AbortSignal.timeout(
    input.timeoutMs ?? (input.onText ? streamTimeoutMs : COACH_TURN_DEADLINE_MS),
  );
  return input.signal === undefined ? deadline : AbortSignal.any([deadline, input.signal]);
}
/** Un refus est un CONTENU, pas une panne : l'utilisateur doit le lire. */
export const COACH_REFUSAL_TEXT = 'Je ne peux pas répondre à cette demande.';
/** Plafond de tours atteint : on rend ce qu'on a plutôt que de boucler. */
export const COACH_GAVE_UP_TEXT = 'Je n’ai pas réussi à aboutir. Reformule ta demande ?';
