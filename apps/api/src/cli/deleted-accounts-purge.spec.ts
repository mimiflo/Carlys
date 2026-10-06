import { DEFAULT_PURGE_DELAY_DAYS } from '../modules/users/application/deleted-accounts-purge';
import { formatReport, parseArgs, UsageError } from './deleted-accounts-purge';

const COMPTE = '0b6f7a3c-1d2e-4f5a-8b9c-0d1e2f3a4b5c';

describe('deleted-accounts-purge — arguments', () => {
  it('sans argument : efface pour de vrai, au bout de 30 jours', () => {
    expect(parseArgs([])).toEqual({ dryRun: false, delayDays: DEFAULT_PURGE_DELAY_DAYS });
    expect(DEFAULT_PURGE_DELAY_DAYS).toBe(30);
  });

  it('--a-blanc, --delai-jours et --compte', () => {
    expect(parseArgs(['--a-blanc', '--delai-jours', '7', '--compte', COMPTE])).toEqual({
      dryRun: true,
      delayDays: 7,
      accountId: COMPTE,
    });
  });

  it('refuse ce qu’il ne comprend pas, plutôt que d’effacer au hasard', () => {
    expect(() => parseArgs(['--delai-jours'])).toThrow(UsageError);
    expect(() => parseArgs(['--delai-jours', '0'])).toThrow(UsageError);
    expect(() => parseArgs(['--delai-jours', '2.5'])).toThrow(UsageError);
    expect(() => parseArgs(['--delai-jours='])).toThrow(UsageError);
    expect(() => parseArgs(['--compte', 'tout-le-monde'])).toThrow(UsageError);
    expect(() => parseArgs(['--tout-effacer'])).toThrow(UsageError);
  });

  it('le rapport dit la portée, les comptes et chaque échec', () => {
    const texte = formatReport(
      {
        eligible: 2,
        erased: 1,
        objectsDeleted: 3,
        paymentEventsErased: 4,
        sessionsErased: { sessions: 5, refreshTokens: 6 },
        failures: ['id : panne'],
        refused: null,
      },
      { dryRun: false, delayDays: 30 },
    );
    expect(texte).toContain('supprimés depuis plus de 30 jours');
    expect(texte).toContain('comptes effacés    : 1');
    expect(texte).toContain('photos effacées    : 3');
    expect(texte).toContain('paiements orphelins effacés (plus de 90 jours) : 4');
    expect(texte).toContain('sessions closes effacées (plus de 30 jours) : 5');
    expect(texte).toContain('jetons de renouvellement échus effacés : 6');
    expect(texte).toContain('ÉCHEC : id : panne');
  });

  it('--compte-actif exige --confirmer, et l’inverse ; jamais avec --compte', () => {
    expect(parseArgs(['--compte-actif', COMPTE, '--confirmer', ' Lea@Exemple.fr '])).toEqual({
      dryRun: false,
      delayDays: DEFAULT_PURGE_DELAY_DAYS,
      activeAccount: { id: COMPTE, confirmEmail: 'Lea@Exemple.fr' },
    });
    expect(
      parseArgs(['--a-blanc', '--compte-actif', COMPTE, '--confirmer', 'lea@exemple.fr']),
    ).toMatchObject({ dryRun: true, activeAccount: { id: COMPTE } });
    expect(() => parseArgs(['--compte-actif', COMPTE])).toThrow(UsageError);
    expect(() => parseArgs(['--confirmer', 'lea@exemple.fr'])).toThrow(UsageError);
    expect(() => parseArgs(['--compte-actif', 'tout-le-monde', '--confirmer', 'a@b.c'])).toThrow(
      UsageError,
    );
    expect(() => parseArgs(['--compte-actif', COMPTE, '--confirmer', 'pas-une-adresse'])).toThrow(
      UsageError,
    );
    expect(() =>
      parseArgs(['--compte', COMPTE, '--compte-actif', COMPTE, '--confirmer', 'a@b.c']),
    ).toThrow(UsageError);
  });
});
