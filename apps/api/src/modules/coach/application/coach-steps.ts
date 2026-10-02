import { type CoachToolCall } from '../domain/coach-model.port';
import { PROPOSE_PROGRAM_TOOL, PROPOSE_SESSION_TOOL } from './coach.tool-definitions';

/**
 * La RÉFLEXION montrée à la personne : ce que le coach fait vraiment avant de
 * répondre — lire ses records, chercher des exercices, préparer sa séance.
 *
 * Des étapes RÉELLES, nommées depuis ses appels d'outils, jamais un
 * raisonnement rédigé par le modèle : sur le processeur du serveur
 * (≈ 8 jetons/s), une réflexion écrite coûterait des dizaines de secondes à
 * chaque réponse. Celles-ci sont gratuites, et vraies.
 */
const LABELS: ReadonlyMap<string, string> = new Map([
  ['get_personal_records', 'Je regarde tes records'],
  ['get_progress_overview', 'Je regarde ta progression'],
  ['get_recent_sessions', 'Je relis tes dernières séances'],
  ['get_body_weight_trend', 'Je regarde l’évolution de ton poids'],
  ['get_nutrition_targets', 'Je regarde tes objectifs nutritionnels'],
  ['get_recent_meals', 'Je relis tes derniers repas'],
  ['get_training_profile', 'Je relis ton profil d’entraînement'],
  ['list_workout_templates', 'Je regarde tes modèles de séance'],
  ['get_workout_template', 'Je relis ton modèle de séance'],
  ['search_exercises', 'Je cherche des exercices'],
  [PROPOSE_SESSION_TOOL, 'Je prépare ta séance'],
  [PROPOSE_PROGRAM_TOOL, 'Je prépare ton programme'],
]);

/**
 * Les étapes d'un tour, chacune une fois, dans l'ordre : `add` rend celles
 * qui sont NOUVELLES (à envoyer en direct), `all` celles du tour (archivées
 * avec la réponse) — sans « Je prépare… » quand la proposition n'a pas
 * survécu à sa validation. Un outil inconnu n'en fait pas, `toString`
 * compris : une table, pas un objet.
 */
export function coachSteps() {
  const steps: string[] = [];
  return {
    add(calls: readonly Pick<CoachToolCall, 'name'>[]): string[] {
      const fresh = calls
        .map((call) => LABELS.get(call.name))
        .filter((label): label is string => label !== undefined && !steps.includes(label));
      const unique = [...new Set(fresh)];
      steps.push(...unique);
      return unique;
    },
    all: (kept: { session: boolean; program: boolean }): string[] =>
      steps.filter(
        (label) =>
          (kept.session || label !== LABELS.get(PROPOSE_SESSION_TOOL)) &&
          (kept.program || label !== LABELS.get(PROPOSE_PROGRAM_TOOL)),
      ),
  };
}

/**
 * La réflexion d'un tour, au fil de l'eau : chaque étape COMMENCE (« Je
 * regarde tes records », trois points qui s'animent) puis FINIT (la coche),
 * et sa durée court du créneau obtenu au premier mot écrit (« Réflexion en
 * 30 s »). `onStep` reçoit l'étape, si elle est finie, et le temps écoulé
 * depuis le début : le chrono de l'appli s'y recale.
 */
export function coachReflection(
  onStep?: (label: string, done: boolean, elapsedMs: number) => void,
) {
  const steps = coachSteps();
  let startedAt: number | undefined;
  let thoughtUntil: number | undefined;
  const elapsed = () => (startedAt === undefined ? 0 : Date.now() - startedAt);
  const finished = new Set<string>();
  // Une étape ne finit que si elle a commencé, et une fois.
  const end = (calls: readonly Pick<CoachToolCall, 'name'>[]): void => {
    const begun = steps.all({ session: true, program: true });
    for (const call of calls) {
      const label = LABELS.get(call.name);
      if (label === undefined || !begun.includes(label) || finished.has(label)) continue;
      finished.add(label);
      onStep?.(label, true, elapsed());
    }
  };
  const begin = (calls: readonly Pick<CoachToolCall, 'name'>[]): void => {
    for (const label of steps.add(calls)) onStep?.(label, false, elapsed());
    // Jamais exécutée, seulement retenue : faite dès qu'elle est demandée.
    const retained = calls.filter((call) => call.name === PROPOSE_SESSION_TOOL);
    if (retained.length > 0) end(retained);
  };
  return {
    /** Le créneau est obtenu : la réflexion commence, par ces lectures. */
    start(reads: readonly Pick<CoachToolCall, 'name'>[]): void {
      startedAt ??= Date.now();
      begin(reads);
    },
    begin,
    end,
    /** `run`, qui finit les étapes de ses appels une fois exécutés. */
    track:
      <T>(run: (calls: CoachToolCall[]) => Promise<T>) =>
      async (calls: CoachToolCall[]): Promise<T> => {
        const ran = await run(calls);
        end(calls);
        return ran;
      },
    /** Le premier mot écrit : la réflexion s'arrête là. */
    wrote: () => (thoughtUntil ??= Date.now()),
    /**
     * Sa durée, en secondes ; `null` sans premier mot mesuré (route sans
     * flux, repli qui ne streame pas) : jamais l'écriture comptée comme
     * réflexion.
     */
    seconds: (): number | null =>
      startedAt === undefined || thoughtUntil === undefined
        ? null
        : Math.round((thoughtUntil - startedAt) / 1000),
    all: steps.all,
  };
}
