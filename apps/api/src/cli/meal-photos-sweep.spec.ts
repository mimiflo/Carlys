import { DEFAULT_SWEEP_GRACE_MS } from '../modules/nutrition/application/meal-photo-sweep';
import { formatReport, parseArgs, UsageError } from './meal-photos-sweep';

describe('meal-photos-sweep — arguments', () => {
  it('sans argument : efface pour de vrai, délai de grâce d’une heure', () => {
    expect(parseArgs([])).toEqual({ dryRun: false, graceMs: DEFAULT_SWEEP_GRACE_MS });
  });

  it('--a-blanc et --delai-minutes', () => {
    expect(parseArgs(['--a-blanc', '--delai-minutes', '0'])).toEqual({ dryRun: true, graceMs: 0 });
    expect(parseArgs(['--delai-minutes', '90']).graceMs).toBe(90 * 60_000);
  });

  it('refuse ce qu’il ne comprend pas, plutôt que de balayer au hasard', () => {
    expect(() => parseArgs(['--delai-minutes'])).toThrow(UsageError);
    expect(() => parseArgs(['--delai-minutes', '-5'])).toThrow(UsageError);
    expect(() => parseArgs(['--tout-effacer'])).toThrow(UsageError);
  });

  it('le rapport nomme le bucket, les comptes et chaque échec', () => {
    const text = formatReport(
      { scanned: 3, live: 1, young: 0, orphans: 2, deleted: 1, failures: ['cle : panne'] },
      false,
      'carlys-private',
    );
    expect(text).toContain('Bucket carlys-private');
    expect(text).toContain('effacés            : 1');
    expect(text).toContain('ÉCHEC : cle : panne');
  });
});
