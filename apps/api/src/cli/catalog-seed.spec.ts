import { UsageError, parseArgs, sweepAfterPurge } from './catalog-seed';

describe('catalog-seed — arguments', () => {
  it('charge les photos par défaut, les saute sur --sans-photos', () => {
    expect(parseArgs([])).toEqual({ withPhotos: true });
    expect(parseArgs(['--sans-photos'])).toEqual({ withPhotos: false });
  });

  it('refuse une option inconnue', () => {
    expect(() => parseArgs(['--force'])).toThrow(UsageError);
    expect(() => parseArgs(['staging'])).toThrow(/Option inconnue/);
  });
});

/**
 * Les versions précédentes des photos ne quittent le stockage qu'une fois le
 * cache du catalogue purgé : tant qu'une liste en cache cite l'ancienne URL,
 * effacer l'objet casserait l'image qu'elle montre.
 */
describe('catalog-seed — balayage des anciennes photos', () => {
  it('cache NON purgé : rien n’est effacé, le balayage est remis', async () => {
    const sweep = jest.fn();

    const ligne = await sweepAfterPurge(null, sweep);

    expect(sweep).not.toHaveBeenCalled();
    expect(ligne).toMatch(/remis au prochain chargement/);
  });

  it('cache purgé : balaye, et le bilan le dit', async () => {
    const sweep = jest.fn().mockResolvedValue({ scanned: 170, deleted: 14, failures: [] });

    const ligne = await sweepAfterPurge(3, sweep);

    expect(sweep).toHaveBeenCalledTimes(1);
    expect(ligne).toBe('  anciennes photos : 14 version(s) précédente(s) effacée(s) du stockage.');
  });

  it('rien à effacer : rien à dire', async () => {
    const sweep = jest.fn().mockResolvedValue({ scanned: 156, deleted: 0, failures: [] });

    expect(await sweepAfterPurge(0, sweep)).toBeNull();
  });

  it('un stockage qui refuse la liste n’annule pas un chargement réussi', async () => {
    const sweep = jest.fn().mockRejectedValue(new Error('AccessDenied'));

    const ligne = await sweepAfterPurge(3, sweep);

    expect(ligne).toMatch(/balayage impossible \(AccessDenied\)/);
  });
});
