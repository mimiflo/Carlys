import {
  exerciseSearchFilters,
  filtersFromSearch,
  matchByName,
  primaryOnly,
} from './coach-exercise-search';

/**
 * Ce que le modèle écrit n'est pas ce que le catalogue range : « pecs »,
 * « pectoral », « haltères », le muscle dans les mots du nom… Chaque écart
 * vidait la recherche, et le coach concluait « aucun exercice pour les
 * pectoraux » (constaté le 1er octobre 2026, Qwen3-4B).
 */
describe('exerciseSearchFilters', () => {
  const catalog = {
    muscleGroups: [
      { slug: 'pectoraux', name: 'Pectoraux' },
      { slug: 'abdominaux', name: 'Abdominaux' },
      { slug: 'epaules', name: 'Épaules' },
      { slug: 'ischio-jambiers', name: 'Ischio-jambiers' },
      { slug: 'dos', name: 'Dos' },
      { slug: 'quadriceps', name: 'Quadriceps' },
    ],
    equipment: [
      { slug: 'barre', name: 'Barre' },
      { slug: 'barre-ez', name: 'Barre EZ' },
      { slug: 'halteres', name: 'Haltères' },
      { slug: 'poids-du-corps', name: 'Poids du corps' },
      { slug: 'rouleau', name: 'Rouleau' },
      { slug: 'disque', name: 'Disque' },
    ],
  };
  const filters = (input: Record<string, unknown>) => exerciseSearchFilters(input, catalog);

  it('un vrai slug passe tel quel', () => {
    expect(filters({ muscleGroupSlug: 'dos', equipmentSlug: 'barre' })).toEqual({
      muscleGroupSlug: 'dos',
      equipmentSlug: 'barre',
    });
  });

  it('les mots de salle et les accents retrouvent leur slug', () => {
    expect(filters({ muscleGroupSlug: 'pecs' }).muscleGroupSlug).toBe('pectoraux');
    expect(filters({ muscleGroupSlug: 'pectoral' }).muscleGroupSlug).toBe('pectoraux');
    expect(filters({ muscleGroupSlug: 'abdos' }).muscleGroupSlug).toBe('abdominaux');
    expect(filters({ muscleGroupSlug: 'Épaules' }).muscleGroupSlug).toBe('epaules');
    expect(filters({ muscleGroupSlug: 'ischios' }).muscleGroupSlug).toBe('ischio-jambiers');
    expect(filters({ equipmentSlug: 'Haltères' }).equipmentSlug).toBe('halteres');
    expect(filters({ equipmentSlug: 'poids du corps' }).equipmentSlug).toBe('poids-du-corps');
    expect(filters({ equipmentSlug: 'barres' }).equipmentSlug).toBe('barre');
  });

  it('jamais un début de trois lettres : « row » n’est pas un rouleau', () => {
    expect(() => filters({ equipmentSlug: 'row' })).toThrow('Matériel inconnu');
    expect(() => filters({ equipmentSlug: 'dip' })).toThrow('Matériel inconnu');
  });

  it('les mots du nom restent ENTIERS : un nom exact se cherche tel quel', () => {
    expect(filters({ search: 'Extensions mollets debout' })).toEqual({
      search: 'Extensions mollets debout',
    });
  });

  it('en second essai, le muscle ou le matériel glissé dans les mots devient un filtre', () => {
    const pulled = (input: Record<string, unknown>) =>
      filtersFromSearch(exerciseSearchFilters(input, catalog), catalog);
    expect(pulled({ search: 'pectoraux', equipmentSlug: 'halteres' })).toEqual({
      muscleGroupSlug: 'pectoraux',
      equipmentSlug: 'halteres',
    });
    expect(pulled({ search: 'développé pecs haltères' })).toEqual({
      search: 'développé',
      muscleGroupSlug: 'pectoraux',
      equipmentSlug: 'halteres',
    });
    // Rien à tirer des mots : pas de second essai.
    expect(pulled({ search: 'Pendlay Row' })).toBeNull();
  });

  it('un nom ambigu ou inconnu est refusé AVEC les valeurs possibles', () => {
    // « barr » désigne aussi bien la barre que la barre EZ : on ne choisit pas.
    expect(() => filters({ equipmentSlug: 'barr' })).toThrow('Valeurs possibles : barre');
    expect(() => filters({ muscleGroupSlug: 'jambes' })).toThrow(
      /Groupe musculaire inconnu « jambes ».*pectoraux.*quadriceps/,
    );
  });

  it('des valeurs vides ou absentes ne filtrent rien', () => {
    expect(filters({})).toEqual({});
    expect(filters({ search: '  ', muscleGroupSlug: '' })).toEqual({});
  });
});

describe('matchByName et primaryOnly', () => {
  const ex = (name: string, muscle: string | null = null) => ({
    name,
    primaryMuscleGroup: muscle === null ? null : { slug: muscle },
  });

  it('sans accents, sans majuscules, dans n’importe quel ordre', () => {
    const items = [ex('Développé couché'), ex('Écarté couché haltères'), ex('Squat')];
    expect(matchByName(items, 'developpe couche').map((e) => e.name)).toEqual(['Développé couché']);
    expect(matchByName(items, 'COUCHE ecarte').map((e) => e.name)).toEqual([
      'Écarté couché haltères',
    ]);
    expect(matchByName(items, 'curl')).toEqual([]);
  });

  it('seuls les exercices dont le groupe est le muscle PRINCIPAL, s’il y en a', () => {
    // Constaté le 2 octobre 2026 : « fessiers » rendait 15 exercices, dont
    // les squats et fentes déjà rendus pour « quadriceps » — le contexte
    // payait chaque doublon, et la séance tardait de plusieurs minutes.
    const items = [ex('Burpees', 'quadriceps'), ex('Pompes', 'pectoraux'), ex('Dips', 'triceps')];
    expect(primaryOnly(items, 'pectoraux').map((e) => e.name)).toEqual(['Pompes']);
    // Aucun principal : les secondaires plutôt que rien.
    expect(primaryOnly(items, 'epaules')).toEqual(items);
    expect(primaryOnly(items, undefined)).toEqual(items);
  });
});
