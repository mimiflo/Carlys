import { LEAGUE_GROUP_SIZE } from '../domain/league-ladder';
import { assignCohorts } from './league-groups';

/**
 * Ranger un LOT d'arrivées sur un seul comptage doit donner exactement ce
 * que donnaient un comptage et une écriture par arrivée : le premier groupe
 * qui a de la place, chaque arrivée prenant la sienne avant la suivante.
 */
describe('assignCohorts', () => {
  const arrivees = (nombre: number) => Array.from({ length: nombre }, (_, index) => ({ index }));

  it('division vide : tout le monde au groupe 0, jusqu’à ce qu’il soit plein', () => {
    const places = assignCohorts([], arrivees(LEAGUE_GROUP_SIZE + 2));
    expect(places.filter((place) => place.cohort === 0)).toHaveLength(LEAGUE_GROUP_SIZE);
    expect(places.slice(-2).map((place) => place.cohort)).toEqual([1, 1]);
  });

  it('remplit d’abord le premier groupe qui a de la place, dans l’ordre d’arrivée', () => {
    const places = assignCohorts(
      [
        { cohort: 0, members: LEAGUE_GROUP_SIZE },
        { cohort: 1, members: LEAGUE_GROUP_SIZE - 1 },
        { cohort: 2, members: 3 },
      ],
      arrivees(3),
    );
    expect(places).toEqual([
      { index: 0, cohort: 1 },
      { index: 1, cohort: 2 },
      { index: 2, cohort: 2 },
    ]);
  });

  it('tous les groupes pleins : un nouveau, numéroté après le plus grand', () => {
    const places = assignCohorts(
      [
        { cohort: 0, members: LEAGUE_GROUP_SIZE },
        { cohort: 3, members: LEAGUE_GROUP_SIZE },
      ],
      arrivees(2),
    );
    expect(places.map((place) => place.cohort)).toEqual([4, 4]);
  });

  it('aucune arrivée : aucune place', () => {
    expect(assignCohorts([{ cohort: 0, members: 5 }], [])).toEqual([]);
  });
});
