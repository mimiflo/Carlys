/**
 * Frontière UNIQUE avec le fournisseur de modèle.
 *
 * Toute la logique métier — outils, validation, quota, assemblage du prompt —
 * se teste contre un faux qui implémente ce port : aucun test ne sort sur le
 * réseau, et changer de fournisseur ne touche qu'un fichier d'infrastructure.
 */

/** Un tour de conversation vu par le modèle. */
export interface CoachTurn {
  role: 'user' | 'assistant';
  content: string;
}

/**
 * Outil de LECTURE mis à disposition du modèle. Le coach n'en a aucun qui
 * écrive : `propose_session` lui-même ne fait que produire un document, que
 * le serveur valide avant de le stocker.
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
  reply(input: CoachTurnInput): Promise<CoachTurnOutput>;
}

export const COACH_MODEL_PORT = Symbol('COACH_MODEL_PORT');
