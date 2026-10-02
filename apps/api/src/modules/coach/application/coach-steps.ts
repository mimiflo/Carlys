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
