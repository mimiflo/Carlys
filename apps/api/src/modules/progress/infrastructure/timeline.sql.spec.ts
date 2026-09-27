import { timelinePage, timelineSources } from './timeline.sql';

/**
 * La forme de la requête de la frise, là où elle décide du coût.
 *
 * Le volume et le nombre de séries d'une séance se lisent dans `WorkoutSet`.
 * Lus DANS la source des séances, sous l'`UNION ALL`, ils étaient calculés
 * pour tout l'historique du compte avant la coupe de la page (496 séances,
 * deux sous-requêtes chacune, pour en servir trente). Le contrat, lui, est
 * gardé par `test/timeline.e2e-spec.ts` ; ce fichier garde l'ORDRE : couper
 * d'abord, agréger ensuite.
 */
describe('timeline.sql', () => {
  const USER = '00000000-0000-4000-8000-000000000001';

  it('aucune source ne lit les séries : la fusion ne coûte pas l’historique', () => {
    for (const source of timelineSources(USER, [])) {
      expect(source.sql).not.toContain('"WorkoutSet"');
    }
  });

  it('les séries ne se lisent qu’APRÈS la coupe de la page', () => {
    const { sql } = timelinePage(timelineSources(USER, []), null, 31);

    const coupe = sql.indexOf('LIMIT');
    const series = sql.indexOf('"WorkoutSet"');
    expect(coupe).toBeGreaterThan(0);
    expect(series).toBeGreaterThan(coupe);
  });

  it('chaque source rend les cinq colonnes que l’union empile', () => {
    for (const source of timelineSources(USER, [])) {
      for (const colonne of ['AS kind', 'AS id', 'AS occurred_at', 'AS payload', 'AS session_id']) {
        expect(source.sql).toContain(colonne);
      }
    }
  });

  it('ne garde que les sources demandées', () => {
    expect(timelineSources(USER, ['MEASURE'])).toHaveLength(1);
    expect(timelineSources(USER, ['RECORD', 'TITLE'])).toHaveLength(1);
    expect(timelineSources(USER, ['INCONNU'])).toHaveLength(0);
    expect(timelineSources(USER, [])).toHaveLength(4);
  });
});
