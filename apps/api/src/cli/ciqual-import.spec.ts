import { formatReport, parseArgs, UsageError } from './ciqual-import';

describe('ciqual-import — arguments', () => {
  it('prend un dossier, une version facultative et le mode à blanc', () => {
    expect(parseArgs(['/srv/ciqual'])).toEqual({
      directory: '/srv/ciqual',
      version: undefined,
      dryRun: false,
      allowMassRetirement: false,
    });
    expect(
      parseArgs(['--a-blanc', '/srv/ciqual', '--version', '2020-07-07', '--accepter-retraits']),
    ).toEqual({
      directory: '/srv/ciqual',
      version: '2020-07-07',
      dryRun: true,
      allowMassRetirement: true,
    });
  });

  it('refuse un appel incomplet ou ambigu', () => {
    expect(() => parseArgs([])).toThrow(/Dossier .* manquant/);
    expect(() => parseArgs(['/a', '/b'])).toThrow(UsageError);
    expect(() => parseArgs(['/a', '--version'])).toThrow(/--version attend/);
    expect(() => parseArgs(['/a', '--version', '--a-blanc'])).toThrow(/--version attend/);
    expect(() => parseArgs(['/a', '--force'])).toThrow(/Option inconnue/);
  });
});

describe('ciqual-import — rapport', () => {
  const report = {
    version: '2020-07-07',
    dryRun: false,
    read: 9,
    created: 6,
    updated: 1,
    reactivated: 0,
    unchanged: 0,
    retired: 1,
    activeBefore: 3,
    massRetirement: false,
    ignored: [
      { code: 4, name: 'Eau du robinet', reason: 'énergie inconnue' as const },
      { code: 5, name: 'Sel', reason: 'énergie inconnue' as const },
    ],
    warnings: ['compo_x.xml ne porte pas la date de alim_y.xml'],
  };

  it('compte chaque issue, détaille les ignorés par raison, et rappelle la mention de source', () => {
    const text = formatReport(report);
    expect(text).toContain('Table CIQUAL chargée. Version 2020-07-07.');
    expect(text).toMatch(/créés {8}: 6/);
    expect(text).toMatch(/retirés {6}: 1/);
    expect(text).toContain('énergie inconnue : 2 (ex. 4 Eau du robinet ; 5 Sel)');
    expect(text).toContain('attention : compo_x.xml');
    expect(text).toContain(
      'Source : Anses, Table de composition nutritionnelle des aliments Ciqual (version 2020-07-07)',
    );
  });

  it('dit sans ambiguïté qu’une simulation n’a rien écrit', () => {
    expect(formatReport({ ...report, dryRun: true })).toMatch(/^Simulation \(--a-blanc\) : RIEN/);
  });

  it('prévient, à la simulation, qu’un retrait massif exigera --accepter-retraits', () => {
    const text = formatReport({ ...report, dryRun: true, retired: 2, massRetirement: true });
    expect(text).toContain('2 retraits sur 3 aliments en service');
    expect(text).toContain('--accepter-retraits');
    expect(formatReport(report)).not.toContain('--accepter-retraits');
    expect(formatReport({ ...report, retired: 2, massRetirement: true })).toContain(
      'acceptés par --accepter-retraits',
    );
  });
});
