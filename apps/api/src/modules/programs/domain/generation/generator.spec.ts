import { ExerciseDifficulty, ExerciseType, TrainingExperience, TrainingGoal } from '@prisma/client';
import { EQUIPMENT, EXERCISES, MUSCLE_GROUPS } from '../../../exercises/application/catalog-data';
import { derivedUuid } from '../../../../common/utilities/derived-uuid';
import { EXERCISES_PER_SESSION_MAX, GENERATION_UUID_NAMESPACE } from './constants';
import { verify } from './constraints';
import { generateProgram } from './generator';
import { GOAL_RULES } from './goal-rules';
import { normalizeSessions } from './splits';
import { type GenerationInput, type PoolExercise } from './types';

/**
 * LE BALAYAGE — le test qui vaut tous les autres.
 *
 * Le moteur est une fonction pure, donc on peut lui présenter TOUTES les
 * combinaisons d'entrées et vérifier qu'aucune ne produit un programme qui
 * viole ses propres règles. Et la vérification n'est pas réécrite ici : c'est
 * `verify()`, LA MÊME fonction que le générateur appelle en dernière phase. Un
 * test qui recopierait les invariants finirait par diverger du code qu'il
 * surveille, et c'est précisément quand il diverge qu'on aurait besoin de lui.
 *
 * Le pool vient du VRAI catalogue (`catalog-data.ts`), pas d'un jeu inventé :
 * un générateur qui passe sur trois exercices fictifs ne prouve rien sur les
 * cent quatre-vingt-dix que les gens reçoivent.
 */

const DIFFICULTY_ORDER: Record<ExerciseDifficulty, number> = {
  BEGINNER: 0,
  INTERMEDIATE: 1,
  ADVANCED: 2,
};

const CEILING: Record<TrainingExperience, ExerciseDifficulty> = {
  BEGINNER: ExerciseDifficulty.BEGINNER,
  INTERMEDIATE: ExerciseDifficulty.INTERMEDIATE,
  ADVANCED: ExerciseDifficulty.ADVANCED,
};

/** Le catalogue réel, traduit dans la vue pauvre que le moteur manipule. */
const CATALOGUE: PoolExercise[] = EXERCISES.map((exercise) => ({
  id: derivedUuid('test.catalogue', exercise.slug),
  slug: exercise.slug,
  name: exercise.name,
  primary: exercise.primary,
  secondary: exercise.secondary,
  difficulty: exercise.difficulty,
  type: exercise.type,
  tags: exercise.tags,
  equipment: exercise.equipment,
})).sort((a, b) => (a.slug < b.slug ? -1 : 1));

/** Le même filtre que le repository, rejoué en mémoire. */
function poolFor(kit: string[], experience: TrainingExperience): PoolExercise[] {
  const owned = new Set(kit);
  return CATALOGUE.filter(
    (exercise) =>
      exercise.equipment.length > 0 &&
      exercise.equipment.every((slug) => owned.has(slug)) &&
      DIFFICULTY_ORDER[exercise.difficulty] <= DIFFICULTY_ORDER[CEILING[experience]],
  );
}

const KITS: { name: string; slugs: string[] }[] = [
  { name: 'rien du tout', slugs: ['poids-du-corps'] },
  { name: 'haltères', slugs: ['poids-du-corps', 'halteres'] },
  { name: 'maison complète', slugs: ['poids-du-corps', 'halteres', 'banc', 'barre-de-traction'] },
  { name: 'élastique seul', slugs: ['poids-du-corps', 'elastique'] },
  {
    name: 'salle',
    slugs: [
      'poids-du-corps',
      'barre',
      'halteres',
      'kettlebell',
      'machine',
      'poulie',
      'banc',
      'elastique',
      'barre-de-traction',
      'barre-ez',
      'disque',
      'medecine-ball',
      'ballon',
      'rouleau',
      'tapis',
    ],
  },
];

const MINUTES = [15, 30, 45, 60, 90, 120, 240];

function inputFor(
  goal: TrainingGoal,
  experience: TrainingExperience,
  sessions: number,
  minutes: number,
  kit: string[],
): GenerationInput {
  return {
    programId: `11111111-1111-4111-8111-${`${sessions}${minutes}`.padStart(12, '0')}`,
    goal,
    experience,
    weeklySessionsTarget: sessions,
    sessionMinutesTarget: minutes,
    equipmentSlugs: kit,
    pool: poolFor(kit, experience),
    catalogue: CATALOGUE,
    equipmentNames: Object.fromEntries(EQUIPMENT.map((item) => [item.slug, item.name])),
  };
}

describe('génération de programme', () => {
  describe('balayage de toutes les entrées', () => {
    const cases: GenerationInput[] = [];
    for (const goal of Object.values(TrainingGoal)) {
      for (const experience of Object.values(TrainingExperience)) {
        for (let sessions = 1; sessions <= 7; sessions += 1) {
          for (const minutes of MINUTES) {
            for (const kit of KITS) {
              cases.push(inputFor(goal, experience, sessions, minutes, kit.slugs));
            }
          }
        }
      }
    }

    // Le balayage engendre 8 232 programmes complets. Les produire une fois et
    // les partager entre les assertions plutôt que de recommencer à chaque
    // `it` divise le temps du fichier par trois : un test lent finit désactivé,
    // et un invariant désactivé ne vaut rien.
    const outcomes = cases.map((input) => ({ input, outcome: generateProgram(input) }));

    it('couvre bien tout l’espace des entrées', () => {
      // 8 objectifs × 3 niveaux × 7 rythmes × 7 durées × 5 kits.
      expect(cases.length).toBe(8 * 3 * 7 * 7 * 5);
    });

    it('ne viole jamais une contrainte dure', () => {
      const fautes: string[] = [];
      for (const { input, outcome } of outcomes) {
        if (outcome.kind !== 'program') continue;
        const sessions = normalizeSessions(
          input.goal,
          input.experience,
          input.weeklySessionsTarget,
        );
        const violations = verify({
          days: outcome.program.days,
          templates: outcome.program.templates,
          pool: input.pool,
          rules: GOAL_RULES[input.goal],
          experience: input.experience,
          sessionsPerWeek: sessions,
          weeksCount: outcome.program.weeksCount,
        });
        for (const violation of violations) {
          fautes.push(
            `${input.goal}/${input.experience}/${input.weeklySessionsTarget}×${input.sessionMinutesTarget} : ${violation.rule} ${violation.subject} — ${violation.detail}`,
          );
        }
      }
      expect(fautes).toEqual([]);
    });

    /**
     * H5 a son test à elle, MALGRÉ la redondance avec le précédent.
     *
     * C'est la seule contrainte dont le relâchement serait un DANGER et non une
     * déception : servir un mouvement avancé à quelqu'un qui débute, parce
     * qu'il ne restait rien d'autre à mettre dans le créneau. Si l'échelle de
     * dégradation dérive un jour, ce test doit tomber SEUL et nommer la faute,
     * sans se perdre au milieu des autres.
     */
    it('ne prescrit jamais au-dessus du niveau de la personne', () => {
      const trop: string[] = [];
      for (const { input, outcome } of outcomes) {
        if (outcome.kind !== 'program') continue;
        const byId = new Map(input.pool.map((exercise) => [exercise.id, exercise]));
        for (const template of outcome.program.templates) {
          for (const exercise of template.exercises) {
            const known = byId.get(exercise.exerciseId);
            if (known === undefined) {
              trop.push(`${exercise.exerciseName} hors du pool jouable`);
              continue;
            }
            if (DIFFICULTY_ORDER[known.difficulty] > DIFFICULTY_ORDER[CEILING[input.experience]]) {
              trop.push(`${known.slug} (${known.difficulty}) pour un ${input.experience}`);
            }
          }
        }
      }
      expect(trop).toEqual([]);
    });

    it('n’écrit jamais un exercice sans identifiant de catalogue', () => {
      // Une assertion à la fin, pas une par exercice : huit mille programmes
      // font des millions de lignes prescrites, et l'outillage d'assertion
      // coûte plus cher que le générateur lui-même.
      const anonymes: string[] = [];
      const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
      for (const { outcome } of outcomes) {
        if (outcome.kind !== 'program') continue;
        for (const template of outcome.program.templates) {
          for (const exercise of template.exercises) {
            if (!UUID.test(exercise.exerciseId) || exercise.exerciseName.length === 0) {
              anonymes.push(`${template.name} — « ${exercise.exerciseName} »`);
            }
          }
        }
      }
      expect(anonymes).toEqual([]);
    });
  });

  describe('le calendrier', () => {
    it('est complet : toutes les cases de toutes les semaines', () => {
      const outcome = generateProgram(
        inputFor(TrainingGoal.MUSCLE_GAIN, TrainingExperience.INTERMEDIATE, 4, 45, [
          'poids-du-corps',
          'halteres',
        ]),
      );
      if (outcome.kind !== 'program') throw new Error('programme attendu');
      expect(outcome.program.days.length).toBe(outcome.program.weeksCount * 7);
      const actifs = outcome.program.days.filter((day) => !day.isRest);
      expect(actifs.length).toBe(4 * outcome.program.weeksCount);
    });

    it('n’écrit jamais un intitulé plus long que ce que la base accepte', () => {
      for (const goal of Object.values(TrainingGoal)) {
        const outcome = generateProgram(
          inputFor(goal, TrainingExperience.INTERMEDIATE, 4, 45, [
            'poids-du-corps',
            'halteres',
            'banc',
          ]),
        );
        if (outcome.kind !== 'program') continue;
        for (const day of outcome.program.days) {
          // `saveProgramDaySchema` borne `label` à 120 caractères : un intitulé
          // plus long passerait le moteur et échouerait à l'écriture.
          expect(day.label.length).toBeGreaterThan(0);
          expect(day.label.length).toBeLessThanOrEqual(120);
        }
      }
    });
  });

  describe('le déterminisme', () => {
    const base = inputFor(TrainingGoal.MUSCLE_GAIN, TrainingExperience.INTERMEDIATE, 4, 60, [
      'poids-du-corps',
      'halteres',
    ]);

    it('rend deux fois exactement le même programme', () => {
      const premier = generateProgram(base);
      const second = generateProgram(base);
      expect(JSON.stringify(second)).toEqual(JSON.stringify(premier));
    });

    it('rend un AUTRE programme pour un autre identifiant', () => {
      const premier = generateProgram(base);
      const autre = generateProgram({
        ...base,
        programId: '22222222-2222-4222-8222-222222222222',
      });
      if (premier.kind !== 'program' || autre.kind !== 'program') throw new Error('programmes');
      // Même squelette — c'est le même profil…
      expect(autre.report.split).toEqual(premier.report.split);
      expect(autre.program.weeksCount).toBe(premier.program.weeksCount);
      // …mais une autre sélection : c'est ce qui fait de « régénérer » un
      // bouton, et non un tirage caché quelque part dans le moteur.
      const slugsDe = (outcome: typeof premier): string =>
        outcome.kind === 'program'
          ? outcome.program.templates
              .flatMap((template) => template.exercises.map((exercise) => exercise.exerciseName))
              .join('|')
          : '';
      expect(slugsDe(autre)).not.toEqual(slugsDe(premier));
    });

    it('ignore l’ordre des cases de matériel cochées', () => {
      const trie = generateProgram({ ...base, equipmentSlugs: ['halteres', 'poids-du-corps'] });
      const inverse = generateProgram({ ...base, equipmentSlugs: ['poids-du-corps', 'halteres'] });
      expect(JSON.stringify(trie)).toEqual(JSON.stringify(inverse));
    });

    it('dérive ses identifiants, il ne les tire pas', () => {
      const outcome = generateProgram(base);
      if (outcome.kind !== 'program') throw new Error('programme attendu');
      const attendu = derivedUuid(GENERATION_UUID_NAMESPACE, `${base.programId}:template:0:1`);
      expect(outcome.program.templates[0]?.id).toBe(attendu);
    });
  });

  describe('le cas qui a motivé la tranche : débutant, aucun matériel', () => {
    const outcome = generateProgram(
      inputFor(TrainingGoal.MUSCLE_GAIN, TrainingExperience.BEGINNER, 4, 45, ['poids-du-corps']),
    );

    it('rend un programme, et ne se dérobe pas', () => {
      // Il fut un temps où la seule réponse honnête était un refus : le
      // catalogue n'avait aucun exercice de dos, d'épaules ni de biceps
      // réalisable sans matériel. Vingt exercices plus tard, la personne qui
      // n'a rien est servable — et ce test tombe si le catalogue régresse.
      expect(outcome.kind).toBe('program');
    });

    it('remplit vraiment les séances', () => {
      if (outcome.kind !== 'program') throw new Error('programme attendu');
      for (const template of outcome.program.templates) {
        expect(template.exercises.length).toBeGreaterThanOrEqual(2);
        expect(template.exercises.length).toBeLessThanOrEqual(EXERCISES_PER_SESSION_MAX.BEGINNER);
      }
    });

    it('dit ce qu’il a dû céder, plutôt que de se taire', () => {
      if (outcome.kind !== 'program') throw new Error('programme attendu');
      // Le catalogue sans matériel est mince sur le tirage : le rapport doit
      // le NOMMER. Un programme qui se déclare parfait sur ce pool mentirait.
      expect(outcome.report.status).toBe('relaxed');
      expect(outcome.report.relaxations.length).toBeGreaterThan(0);
      for (const relaxation of outcome.report.relaxations) {
        expect(relaxation.message.length).toBeGreaterThan(10);
      }
    });
  });

  describe('les exercices chronométrés', () => {
    it('ne déguisent jamais des secondes en répétitions', () => {
      // Écrire `targetReps: 45` pour une planche ferait entrer « 45
      // répétitions » dans les records personnels, et les y laisserait.
      const chrono = new Set(
        CATALOGUE.filter(
          (exercise) =>
            exercise.tags.includes('isometrique') || exercise.type === ExerciseType.CARDIO,
        ).map((exercise) => exercise.id),
      );
      const outcome = generateProgram(
        inputFor(TrainingGoal.FAT_LOSS, TrainingExperience.BEGINNER, 4, 45, ['poids-du-corps']),
      );
      if (outcome.kind !== 'program') throw new Error('programme attendu');
      for (const template of outcome.program.templates) {
        for (const exercise of template.exercises) {
          if (!chrono.has(exercise.exerciseId)) continue;
          for (const set of exercise.sets) {
            expect(set.targetReps).toBeNull();
            // La durée a son CHAMP : rangée dans la note, l'application ne
            // saurait ni la décompter ni la comparer d'une semaine à l'autre.
            expect(set.targetDurationSeconds).toBeGreaterThan(0);
          }
        }
      }
    });
  });

  describe('le rapport', () => {
    it('ne compte que des groupes qui existent', () => {
      const connus = new Set(MUSCLE_GROUPS.map((group) => group.slug));
      for (const goal of Object.values(TrainingGoal)) {
        const outcome = generateProgram(
          inputFor(goal, TrainingExperience.INTERMEDIATE, 4, 60, ['poids-du-corps', 'halteres']),
        );
        if (outcome.kind !== 'program') continue;
        for (const volume of outcome.report.weeklyVolume) {
          expect(connus).toContain(volume.muscleGroup);
        }
        for (const group of outcome.report.uncoveredGroups) {
          expect(connus).toContain(group);
        }
      }
    });

    it('compte les jours sans modèle pour MARATHON, et le dit', () => {
      const outcome = generateProgram(
        inputFor(TrainingGoal.MARATHON, TrainingExperience.INTERMEDIATE, 4, 45, [
          'poids-du-corps',
          'halteres',
        ]),
      );
      if (outcome.kind !== 'program') throw new Error('programme attendu');
      expect(outcome.report.freeLabelDays).toBeGreaterThan(0);
      // Trois quarts des jours actifs d'un plan marathon ne produiront aucune
      // donnée dans l'application : la personne doit l'apprendre du rapport.
      expect(outcome.report.notes.join(' ')).toContain('course');
    });
  });
});
