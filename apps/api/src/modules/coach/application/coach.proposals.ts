import { type PinoLogger } from 'nestjs-pino';
import { type CoachToolCall, type CoachToolResult } from '../domain/coach-model.port';
import { type CoachRepository } from '../infrastructure/coach.repository';
import { PROPOSE_PROGRAM_TOOL } from './coach.tool-definitions';
import {
  type ValidatedProgramProposal,
  validateProgramProposal,
} from './program-proposal.validator';
import { extractExerciseIds } from './coach.turn';
import { validateProposal } from './proposal.validator';

type RunTools = (calls: CoachToolCall[]) => Promise<CoachToolResult[]>;

/**
 * Les propositions de programme d'UN tour, interceptées au passage des outils.
 *
 * Contrairement à `propose_session` (retenue par le client du modèle, puis
 * validée une fois le tour fini), `propose_program` est un outil ORDINAIRE :
 * un réglage hors bornes revient au modèle comme une erreur qu'il corrige
 * dans le même tour, au lieu de faire tomber la proposition en silence. La
 * dernière proposition VALIDE du tour est gardée.
 */
export function collectProgramProposal(run: RunTools): {
  runTools: RunTools;
  proposal: () => ValidatedProgramProposal | null;
} {
  let kept: ValidatedProgramProposal | null = null;
  return {
    runTools: async (calls) => {
      const others = await run(calls.filter((call) => call.name !== PROPOSE_PROGRAM_TOOL));
      const answers = calls
        .filter((call) => call.name === PROPOSE_PROGRAM_TOOL)
        .map((call): CoachToolResult => {
          const validation = validateProgramProposal(call.input);
          if (!validation.ok) {
            return { id: call.id, content: validation.reason, isError: true };
          }
          kept = validation.proposal;
          return {
            id: call.id,
            content:
              'Programme proposé : l’utilisateur le verra sous ta réponse et pourra le créer.',
          };
        });
      return [...others, ...answers];
    },
    proposal: () => kept,
  };
}

/**
 * Rejette tout ce qui n'est pas une séance proposée valide. Un exercice
 * inconnu fait tomber la proposition entière : mieux vaut une réponse sans
 * séance qu'une séance inventée.
 */
export async function acceptableSessionProposal(
  raw: Record<string, unknown> | null,
  repository: CoachRepository,
  logger: PinoLogger,
) {
  if (raw === null) {
    return null;
  }
  const catalogue = await repository.catalogueNames(extractExerciseIds(raw));
  const validation = validateProposal(raw, catalogue);
  if (!validation.ok) {
    logger.warn({ reason: validation.reason }, 'Proposition du coach rejetée');
    return null;
  }
  return validation.proposal;
}
