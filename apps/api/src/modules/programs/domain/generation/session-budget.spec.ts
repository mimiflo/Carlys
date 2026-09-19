import { ExerciseDifficulty, ExerciseType, TrainingExperience, TrainingGoal } from '@prisma/client';
import {
  CIRCUIT_THRESHOLD_MINUTES,
  EXERCISES_PER_SESSION_MAX,
  EXERCISES_PER_SESSION_MIN,
} from './constants';
import { suggestLevers, uselessLevers } from './levers';
import { enduranceLabel } from './endurance-catalog';
import { executionSeconds, exerciseSeconds, formatFor, planBudget } from './session-budget';
import { type PoolExercise } from './types';

describe('le budget de temps', () => {
  it('ne compte pas le repos qui suit la DERNIÈRE série', () => {
    // L'oublier gonfle l'estimation de 90 secondes par exercice, soit six
    // minutes sur une séance de quatre — assez pour que le générateur retire
    // un mouvement qui tenait parfaitement.
    const format = formatFor(60);
    const quatre = exerciseSeconds(4, 10, 90, format);
    const exec = executionSeconds(10);
    expect(quatre).toBe(90 + 4 * (exec + 90) - 90);
  });

  it('borne la durée d’une série, dans les deux sens', () => {
    // Trois répétitions ne prennent pas dix secondes, trente n'en prennent
    // pas cent cinq : le tempo n'est pas linéaire.
    expect(executionSeconds(2)).toBe(20);
    expect(executionSeconds(40)).toBe(90);
    expect(executionSeconds(null)).toBe(45);
  });

  it('bascule en CIRCUIT sous le seuil, et pas au-dessus', () => {
    expect(formatFor(CIRCUIT_THRESHOLD_MINUTES).circuit).toBe(true);
    expect(formatFor(CIRCUIT_THRESHOLD_MINUTES + 1).circuit).toBe(false);
    // Le format court raccourcit le repos ET la transition : sans les deux,
    // un quart d'heure ne rendrait qu'un exercice et demi.
    const court = formatFor(15);
    const long = formatFor(60);
    expect(court.restOverrideSeconds).not.toBeNull();
    expect(court.transitionSeconds).toBeLessThan(long.transitionSeconds);
  });

  it('rend au moins deux mouvements, même au quart d’heure', () => {
    const plan = planBudget(
      TrainingGoal.MAINTENANCE,
      TrainingExperience.BEGINNER,
      15,
      3,
      10,
      90,
      40,
    );
    // Une séance d'un seul exercice n'est pas une séance courte, c'est un
    // échauffement. On dépasse et on le dit, plutôt que de rendre ça.
    expect(plan.exerciseCount).toBeGreaterThanOrEqual(EXERCISES_PER_SESSION_MIN);
  });

  it('ne dépense PAS le reliquat d’une séance de quatre heures', () => {
    const plan = planBudget(
      TrainingGoal.MUSCLE_GAIN,
      TrainingExperience.INTERMEDIATE,
      240,
      4,
      10,
      90,
      100,
    );
    // Le temps disponible n'est pas une dose d'entraînement : une séance
    // d'hypertrophie de quatre heures n'existe pas.
    expect(plan.exerciseCount).toBe(EXERCISES_PER_SESSION_MAX.INTERMEDIATE);
    expect(plan.overBudget).toBe(false);
  });

  it('donne moins de mouvements à un débutant qu’à un avancé, à durée égale', () => {
    const debutant = planBudget(
      TrainingGoal.MUSCLE_GAIN,
      TrainingExperience.BEGINNER,
      90,
      3,
      10,
      90,
      100,
    );
    const avance = planBudget(
      TrainingGoal.MUSCLE_GAIN,
      TrainingExperience.ADVANCED,
      90,
      4,
      10,
      90,
      100,
    );
    expect(debutant.exerciseCount).toBeLessThan(avance.exerciseCount);
  });

  it('ne promet jamais plus que ce que le pool contient', () => {
    const plan = planBudget(
      TrainingGoal.MUSCLE_GAIN,
      TrainingExperience.ADVANCED,
      120,
      4,
      10,
      90,
      3,
    );
    expect(plan.exerciseCount).toBeLessThanOrEqual(3);
  });
});

describe('les jours d’endurance', () => {
  it('font monter la sortie longue du marathon jusqu’à son pic, puis l’affûtage', () => {
    const longues = Array.from({ length: 16 }, (_unused, index) =>
      enduranceLabel(TrainingGoal.MARATHON, index + 1, 0),
    );
    const minutes = longues.map((label) => Number(/(\d+) min/.exec(label)?.[1] ?? 0));
    // Un plan dont la plus longue sortie fait une heure ne prépare pas un
    // marathon : le pic doit être celui d'un vrai plan, pas une dérivation de
    // la durée d'une séance de musculation.
    expect(Math.max(...minutes)).toBeGreaterThanOrEqual(150);
    // Les trois dernières semaines DESCENDENT : on ne se présente pas au
    // départ avec la fatigue du pic.
    expect(minutes[15]!).toBeLessThan(minutes[13]!);
    expect(minutes[14]!).toBeLessThan(minutes[13]!);
  });

  it('nomme les ateliers Hyrox et en augmente le volume', () => {
    const premiere = enduranceLabel(TrainingGoal.HYROX, 1, 0);
    const derniere = enduranceLabel(TrainingGoal.HYROX, 12, 0);
    expect(premiere).toContain('rameur');
    const tours = (label: string): number => Number(/(\d+) ×/.exec(label)?.[1] ?? 0);
    expect(tours(derniere)).toBeGreaterThan(tours(premiere));
  });

  it('tient dans les 120 caractères que la base accepte', () => {
    for (const goal of Object.values(TrainingGoal)) {
      for (let week = 1; week <= 16; week += 1) {
        for (let position = 0; position < 3; position += 1) {
          const label = enduranceLabel(goal, week, position);
          expect(label.length).toBeGreaterThan(0);
          expect(label.length).toBeLessThanOrEqual(120);
        }
      }
    }
  });
});

describe('les leviers de matériel', () => {
  function exercise(
    slug: string,
    primary: string,
    equipment: string[],
    difficulty: ExerciseDifficulty,
  ): PoolExercise {
    return {
      id: slug,
      slug,
      name: slug,
      primary,
      secondary: [],
      difficulty,
      type: ExerciseType.STRENGTH,
      tags: [],
      equipment,
    };
  }

  const catalogue = [
    exercise('traction', 'dos', ['barre-de-traction'], ExerciseDifficulty.INTERMEDIATE),
    exercise('traction-lestee', 'dos', ['barre-de-traction'], ExerciseDifficulty.ADVANCED),
    exercise('rowing-haltere', 'dos', ['halteres'], ExerciseDifficulty.BEGINNER),
    exercise('curl-haltere', 'biceps', ['halteres'], ExerciseDifficulty.BEGINNER),
    exercise('pompes', 'pectoraux', ['poids-du-corps'], ExerciseDifficulty.BEGINNER),
  ];
  const kit = new Set(['poids-du-corps']);
  /// Les noms d'affichage : ce sont EUX qui partent dans les phrases du
  /// rapport. Un slug montré à quelqu'un est un identifiant de base de
  /// données qui a fui jusqu'à l'écran.
  const noms = {
    'barre-de-traction': 'Barre de traction',
    halteres: 'Haltères',
  };

  it('n’envoie PAS acheter ce qui n’ouvrirait rien à ce niveau', () => {
    // C'est le piège que ce calcul existe pour éviter : compter les gains tous
    // niveaux confondus conseillerait une barre de traction à un débutant, à
    // qui elle n'ouvre rien du tout.
    const leviers = suggestLevers(
      catalogue,
      kit,
      TrainingExperience.BEGINNER,
      ['dos', 'biceps'],
      noms,
    );
    expect(leviers.map((lever) => lever.slug)).toEqual(['halteres']);
    // Le rapport écrit le NOM, jamais le slug : « ajoute halteres » serait un
    // identifiant de base de données montré à quelqu'un.
    expect(leviers.map((lever) => lever.name)).toEqual(['Haltères']);
    expect(uselessLevers(catalogue, kit, TrainingExperience.BEGINNER, ['dos'], noms)).toEqual([
      'Barre de traction',
    ]);
  });

  it('propose la barre de traction dès que le niveau la rend utile', () => {
    const leviers = suggestLevers(catalogue, kit, TrainingExperience.INTERMEDIATE, ['dos']);
    expect(leviers.map((lever) => lever.slug).sort()).toEqual(['barre-de-traction', 'halteres']);
  });

  it('classe les leviers par ce qu’ils ouvrent vraiment', () => {
    const leviers = suggestLevers(catalogue, kit, TrainingExperience.ADVANCED, ['dos', 'biceps']);
    expect(leviers[0]?.slug).toBe('barre-de-traction');
    expect(leviers[0]?.unlocks).toBe(2);
    expect(leviers[0]?.muscleGroups).toEqual(['dos']);
  });

  it('ne compte jamais un exercice qui exige DEUX matériels absents', () => {
    // Ni l'un ni l'autre pris isolément ne le débloque : le compter pour
    // chacun promettrait un gain que l'achat ne rendrait pas.
    const double = [
      exercise('developpe-couche', 'pectoraux', ['barre', 'banc'], ExerciseDifficulty.BEGINNER),
    ];
    expect(suggestLevers(double, kit, TrainingExperience.BEGINNER, ['pectoraux'])).toEqual([]);
  });
});
