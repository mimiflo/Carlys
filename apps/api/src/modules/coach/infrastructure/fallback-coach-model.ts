import {
  type CoachModelPort,
  CoachProviderUnavailableException,
  type CoachTurnInput,
  type CoachTurnOutput,
} from '../domain/coach-model.port';

/**
 * Repli d'un fournisseur sur un autre (ADR 0013) : nos workers d'abord, le
 * fournisseur cloud seulement quand AUCUN n'a répondu.
 *
 * Le repli ne rejoue qu'un tour qui n'a rien coûté ni rien montré : une
 * réponse commencée à l'écran ne recommence pas ailleurs, et une annulation
 * reste une annulation.
 */
export class FallbackCoachModel implements CoachModelPort {
  constructor(
    private readonly primary: CoachModelPort,
    private readonly fallback: CoachModelPort,
  ) {}

  async reply(input: CoachTurnInput): Promise<CoachTurnOutput> {
    try {
      return await this.primary.reply(input);
    } catch (error) {
      const untouched =
        error instanceof CoachProviderUnavailableException && error.usage.inputTokens === 0;
      if (!untouched || input.signal?.aborted === true || input.localOnly === true) throw error;
      return this.fallback.reply(input);
    }
  }
}
