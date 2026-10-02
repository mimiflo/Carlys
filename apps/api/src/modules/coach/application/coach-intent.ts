import {
  ANAPHORA,
  CREATE,
  DETAILED,
  FRUSTRATED,
  KNOWLEDGE,
  minutesIn,
  MODIFY,
  NOT_AN_ORDER,
  NOT_TRAINING,
  POLITE,
  QUICK,
  SHORT_ON_TIME,
  TRAINING,
  WANT,
  WHAT_TO_DO,
  WORK,
} from './coach-intent.rules';
import { asksForData, asksForPlan, asksForSession, folded, namedMuscles } from './coach-prefetch';

/**
 * L'INTENTION d'un message, décidée par le serveur AVANT le modèle.
 *
 * Signalé cinq fois (2 octobre 2026) : Qwen3-4B comprenait la demande, lisait
 * les exercices… puis répondait en texte, sans proposer ni créer la séance.
 * « Le modèle décide s'il appelle l'outil » ne suffit pas : l'orchestration
 * décide ici ce que le tour DOIT produire, et refuse de le terminer sans
 * (coach-actions.ts) — une proposition (`proposalId`), ou une création
 * (`createdTemplateId`) prouvée par la base, jamais par ce que le modèle dit.
 *
 * Des RÈGLES, déterministes et testées sur des dizaines de formulations
 * (test/fixtures/coach-intents.json), plutôt qu'un classifieur : un appel au
 * modèle de plus coûterait 10 à 20 s sur le processeur du serveur, pour
 * un jugement moins sûr que ces signaux. Elles combinent ce que dit le
 * message (verbe d'action, objet, muscles, temps disponible, forme de la
 * question) et le CONTEXTE : la proposition des derniers échanges (« Ok
 * crée-la »), la séance demandée plus haut (« ça fait 5 fois que je te le
 * demande »).
 */

/** Un tour précédent du fil, et la proposition qu'il porte s'il en a une. */
export interface CoachIntentTurn {
  role: 'user' | 'assistant';
  content: string;
  proposalId: string | null;
}

export type CoachIntent =
  | { kind: 'GENERAL_CHAT' | 'KNOWLEDGE' | 'DATA_QUERY' | 'WORKOUT_ADVICE' | 'PROGRAM' }
  /** Une carte est obligatoire, composée d'après `request`. */
  | { kind: 'WORKOUT_PROPOSAL_REQUIRED'; request: string; minutes: number | null }
  /** Une nouvelle carte, d'après la proposition `proposalId` et ce qu'il veut y changer. */
  | {
      kind: 'WORKOUT_MODIFICATION_REQUIRED';
      proposalId: string;
      request: string;
      minutes: number | null;
    }
  /**
   * Une séance ENREGISTRÉE : la proposition `proposalId`, ou celle à composer
   * d'après `request` (l'un des deux, jamais aucun).
   */
  | {
      kind: 'WORKOUT_CREATION_REQUIRED';
      proposalId: string | null;
      request: string | null;
      minutes: number | null;
    }
  /** Une action demandée sans de quoi la faire : UNE question précise. */
  | { kind: 'CLARIFICATION_REQUIRED'; question: string };

/** Les échanges où « la », « ça », « cette séance » trouvent encore leur objet. */
const RECENT_TURNS = 4;

/** Jusqu'où un reproche (« ça fait 5 fois… ») cherche la demande qu'il redit. */
const FRUSTRATION_TURNS = 10;

const CLARIFY =
  'Quelle séance veux-tu que je crée : pour quels muscles, et combien de temps as-tu ?';

const recent = (turns: readonly CoachIntentTurn[]) => turns.slice(-RECENT_TURNS).reverse();

/** Une séance À COMPOSER, d'après ce message seul. */
function asksForWorkout(message: string, question: string, turns: readonly CoachIntentTurn[]) {
  if (asksForSession(message)) return true;
  const soft =
    minutesIn(question) !== null ||
    SHORT_ON_TIME.test(question) ||
    WHAT_TO_DO.test(question) ||
    QUICK.test(question) ||
    (WORK.test(question) && WANT.test(question));
  if (!soft || NOT_TRAINING.test(question)) return false;
  // « Que me conseilles-tu ? » juste après une question de repas : la suite
  // de CE sujet, pas une séance.
  const previous = recent(turns).find((turn) => turn.role === 'user');
  return !(
    previous !== undefined &&
    NOT_TRAINING.test(folded(previous.content)) &&
    !TRAINING.test(question)
  );
}

/**
 * Ce qui est à créer : la carte en vue (« crée-la », « crée-la en 30 min »,
 * modifiée alors d'après ce message), sa propre description (« crée-moi une
 * séance jambes »), la dernière carte, ou la séance demandée plus haut.
 */
function creation(message: string, question: string, turns: readonly CoachIntentTurn[]) {
  const minutes = minutesIn(question);
  const detailed = namedMuscles(question).size > 0 || minutes !== null || DETAILED.test(question);
  const create = (proposalId: string | null, request: string | null) =>
    ({ kind: 'WORKOUT_CREATION_REQUIRED', proposalId, request, minutes }) as const;
  const shown = recent(turns).find((turn) => turn.proposalId !== null)?.proposalId ?? null;
  if (shown !== null && ANAPHORA.test(question)) return create(shown, detailed ? message : null);
  if (detailed) return create(null, message);
  for (const turn of recent(turns)) {
    if (turn.proposalId !== null) return create(turn.proposalId, null);
    if (turn.role === 'user' && asksForWorkout(turn.content, folded(turn.content), [])) {
      return create(null, turn.content);
    }
  }
  // « Crée-moi une séance », sans rien d'autre : une séance du corps entier.
  if (/\b(une|un) (nouvelle |petite |autre )?(seance|entrainement)\b/.test(question)) {
    return create(null, message);
  }
  return { kind: 'CLARIFICATION_REQUIRED', question: CLARIFY } as const;
}

export function resolveIntent(message: string, turns: readonly CoachIntentTurn[]): CoachIntent {
  const question = folded(message);
  const minutes = minutesIn(question);
  const lastReply = turns.at(-1);
  const howTo = KNOWLEDGE.test(question);
  const asksBack = question.includes('?') && !POLITE.test(question);

  if (!NOT_AN_ORDER.test(question) && CREATE.some((pattern) => pattern.test(question))) {
    return creation(message, question, turns);
  }
  if (howTo) return { kind: 'KNOWLEDGE' };
  if (lastReply?.proposalId && !asksBack && (MODIFY.test(question) || minutes !== null)) {
    return {
      kind: 'WORKOUT_MODIFICATION_REQUIRED',
      proposalId: lastReply.proposalId,
      request: message,
      minutes,
    };
  }
  if (/\b(programme|plan)s?\b/.test(question) && asksForPlan(message)) return { kind: 'PROGRAM' };
  if (asksForWorkout(message, question, turns)) {
    return { kind: 'WORKOUT_PROPOSAL_REQUIRED', request: message, minutes };
  }
  if (asksForData(message)) return { kind: 'DATA_QUERY' };
  // « Ça marche jamais, je te l'ai demandé 5 fois » : la dernière demande
  // d'action des derniers échanges, reprise telle quelle.
  if (FRUSTRATED.test(question)) {
    const turnsBefore = turns.slice(-FRUSTRATION_TURNS);
    while (turnsBefore.length > 0) {
      const turn = turnsBefore.pop();
      if (turn?.role !== 'user') continue;
      const earlier = resolveIntent(turn.content, turnsBefore);
      if (earlier.kind.startsWith('WORKOUT_') && earlier.kind !== 'WORKOUT_ADVICE') return earlier;
    }
  }
  if (TRAINING.test(question) || namedMuscles(question).size > 0) return { kind: 'WORKOUT_ADVICE' };
  return { kind: 'GENERAL_CHAT' };
}
