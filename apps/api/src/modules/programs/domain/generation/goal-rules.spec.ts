import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { TrainingExperience, TrainingGoal } from '@prisma/client';
import { MUSCLE_GROUPS } from '../../../exercises/application/catalog-data';
import { MESOCYCLE_WEEKS, PULL_GROUPS, PUSH_GROUPS, GROUP_NEIGHBOURS } from './constants';
import { GOAL_RULES, weeklySetsRange } from './goal-rules';
import { prescriptionFor } from './progression';
import { buildSlots, enduranceDayCount, normalizeSessions } from './splits';

const GROUPS = new Set(MUSCLE_GROUPS.map((group) => group.slug));

describe('les règles par objectif', () => {
  /**
   * L'EXHAUSTIVITÉ, prouvée deux fois.
   *
   * Le type `Record<TrainingGoal, GoalRules>` casse la compilation si un
   * objectif manque — mais un `as` malheureux suffirait à rouvrir le trou, et
   * personne ne s'en apercevrait avant qu'un utilisateur ne choisisse le
   * neuvième objectif et ne reçoive rien.
   */
  it('en porte une par objectif, sans plus ni moins', () => {
    expect(Object.keys(GOAL_RULES).sort()).toEqual(Object.values(TrainingGoal).sort());
  });

  it('a des bornes cohérentes entre elles', () => {
    for (const [goal, rules] of Object.entries(GOAL_RULES)) {
      expect(rules.repsMin).toBeLessThanOrEqual(rules.repsBase);
      expect(rules.repsBase).toBeLessThanOrEqual(rules.repsMax);
      expect(rules.restMin).toBeLessThanOrEqual(rules.restIsolation);
      expect(rules.restPolyarticular).toBeLessThanOrEqual(rules.restMax);
      expect(rules.sessionsMin).toBeLessThanOrEqual(rules.sessionsMax);
      expect(rules.prioritySetsMin).toBeLessThanOrEqual(rules.prioritySetsMax);
      expect(rules.secondarySetsMin).toBeLessThanOrEqual(rules.secondarySetsMax);
      expect(rules.weeksCount).toBeGreaterThan(0);
      expect(rules.mesocycle.length).toBe(MESOCYCLE_WEEKS);
      expect(rules.cardioShare).toBeGreaterThanOrEqual(0);
      expect(rules.cardioShare).toBeLessThanOrEqual(1);
      // Un objectif dont on ne sait plus pourquoi il dose ainsi est un objectif
      // que le prochain développeur modifiera au jugé.
      expect(rules.rationale.length).toBeGreaterThan(120);
      for (const group of [...rules.priorityGroups, ...rules.requiredGroups]) {
        expect(GROUPS).toContain(group);
      }
      // `avant-bras` n'est le principal d'aucun exercice du catalogue : lui
      // ouvrir un créneau produirait un jour vide.
      expect(rules.priorityGroups).not.toContain('avant-bras');
      expect(goal in TrainingGoal).toBe(true);
    }
  });

  it('ne compose que des découpages faits de groupes existants', () => {
    for (const goal of Object.values(TrainingGoal)) {
      for (const experience of Object.values(TrainingExperience)) {
        for (let wanted = 1; wanted <= 7; wanted += 1) {
          const sessions = normalizeSessions(goal, experience, wanted);
          const slots = buildSlots(goal, experience, sessions);
          expect(slots.length).toBeGreaterThan(0);
          for (const slot of slots) {
            expect(slot.name.length).toBeGreaterThan(0);
            expect(slot.groups.length).toBeGreaterThan(0);
            for (const group of slot.groups) expect(GROUPS).toContain(group);
          }
          // Il reste TOUJOURS une séance dans l'application : un programme qui
          // ne serait que des jours de course n'est pas un programme Carlys.
          expect(enduranceDayCount(goal, sessions)).toBeLessThan(sessions);
        }
      }
    }
  });

  it('ramène le rythme demandé dans ce que l’objectif et le niveau permettent', () => {
    // Un débutant qui vise sept séances en reçoit quatre — et le rapport le
    // dit. Le lui accorder en silence serait le laisser se griller.
    expect(normalizeSessions(TrainingGoal.MUSCLE_GAIN, TrainingExperience.BEGINNER, 7)).toBe(4);
    expect(normalizeSessions(TrainingGoal.STRENGTH, TrainingExperience.ADVANCED, 7)).toBe(5);
    expect(normalizeSessions(TrainingGoal.MUSCLE_GAIN, TrainingExperience.ADVANCED, 1)).toBe(3);
  });

  it('classe le tirage et la poussée dans des groupes qui existent', () => {
    for (const group of [...PUSH_GROUPS, ...PULL_GROUPS]) expect(GROUPS).toContain(group);
    for (const [group, voisins] of Object.entries(GROUP_NEIGHBOURS)) {
      expect(GROUPS).toContain(group);
      for (const voisin of voisins) {
        expect(GROUPS).toContain(voisin);
        expect(voisin).not.toBe(group);
      }
    }
  });
});

describe('la progression', () => {
  it('fait démarrer le second bloc AU-DESSUS du premier', () => {
    const rules = GOAL_RULES[TrainingGoal.CALISTHENICS];
    const semaine1 = prescriptionFor(rules, TrainingExperience.INTERMEDIATE, 1, true);
    const semaine5 = prescriptionFor(rules, TrainingExperience.INTERMEDIATE, 5, true);
    // Sans la progression INTER-BLOC, un programme de huit semaines progresse
    // sur quatre semaines, deux fois : il entretient au lieu de développer.
    expect(semaine5.reps).toBeGreaterThan(semaine1.reps);
  });

  it('laisse l’entretien PLAT, y compris la quatrième semaine', () => {
    const rules = GOAL_RULES[TrainingGoal.MAINTENANCE];
    const doses = [1, 2, 3, 4].map((week) =>
      prescriptionFor(rules, TrainingExperience.INTERMEDIATE, week, true),
    );
    for (const dose of doses) {
      expect(dose).toEqual(doses[0]);
      // On ne décharge pas une charge d'entretien.
      expect(dose.deload).toBe(false);
    }
  });

  it('fait DESCENDRE les répétitions en force, et monter le repos', () => {
    const rules = GOAL_RULES[TrainingGoal.STRENGTH];
    const semaines = [1, 2, 3].map((week) =>
      prescriptionFor(rules, TrainingExperience.INTERMEDIATE, week, true),
    );
    expect(semaines[1]!.reps).toBeLessThan(semaines[0]!.reps);
    expect(semaines[2]!.reps).toBeLessThan(semaines[1]!.reps);
    expect(semaines[2]!.restSeconds).toBeGreaterThan(semaines[0]!.restSeconds);
  });

  it('fait RACCOURCIR le repos en perte de gras, sans jamais passer sous son plancher', () => {
    const rules = GOAL_RULES[TrainingGoal.FAT_LOSS];
    const semaines = [1, 2, 3].map((week) =>
      prescriptionFor(rules, TrainingExperience.INTERMEDIATE, week, true),
    );
    expect(semaines[2]!.restSeconds).toBeLessThan(semaines[0]!.restSeconds);
    for (const semaine of semaines) {
      // Sous 45 secondes ce n'est plus du renforcement mais du circuit
      // métabolique, et la masse maigre part avec le gras.
      expect(semaine.restSeconds).toBeGreaterThanOrEqual(rules.restMin);
    }
  });

  it('ne sort jamais des fourchettes de son objectif', () => {
    for (const goal of Object.values(TrainingGoal)) {
      const rules = GOAL_RULES[goal];
      for (const experience of Object.values(TrainingExperience)) {
        for (let week = 1; week <= rules.weeksCount; week += 1) {
          for (const poly of [true, false]) {
            const dose = prescriptionFor(rules, experience, week, poly);
            expect(dose.reps).toBeGreaterThanOrEqual(rules.repsMin);
            expect(dose.reps).toBeLessThanOrEqual(rules.repsMax);
            expect(dose.restSeconds).toBeGreaterThanOrEqual(rules.restMin);
            expect(dose.restSeconds).toBeLessThanOrEqual(rules.restMax);
            expect(dose.sets).toBeGreaterThanOrEqual(2);
          }
        }
      }
    }
  });

  it('donne au groupe prioritaire plus de volume qu’au secondaire', () => {
    for (const goal of Object.values(TrainingGoal)) {
      const rules = GOAL_RULES[goal];
      const prioritaire = rules.priorityGroups[0];
      if (prioritaire === undefined) continue;
      const haut = weeklySetsRange(rules, prioritaire);
      const bas = weeklySetsRange(rules, 'avant-bras');
      expect(haut.max).toBeGreaterThanOrEqual(bas.max);
    }
  });
});

/**
 * LE VERROU DE DÉTERMINISME, par lecture des sources.
 *
 * Grossier et très bon marché. Il documente l'intention pour le prochain
 * développeur mieux qu'un commentaire : le moteur ne doit dépendre ni de
 * l'heure, ni du hasard, ni de l'environnement. Sans quoi une génération ne se
 * rejoue pas, donc ne s'explique pas, donc n'est pas auditable — ce que
 * l'intitulé de la tranche promet.
 */
describe('le moteur ne dépend de rien d’extérieur', () => {
  const INTERDITS = ['Math.random(', 'Date.now(', 'new Date(', 'randomUUID(', 'process.env'];

  /**
   * Les commentaires sont retirés avant la recherche.
   *
   * Sans cela, le garde se déclenche sur les explications qui NOMMENT ce qu'on
   * s'interdit — et il n'y a rien de plus absurde qu'un contrôle qui punit le
   * fait d'avoir documenté sa règle.
   */
  function codeOnly(source: string): string {
    return source.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');
  }

  it('n’appelle ni horloge, ni hasard, ni variable d’environnement', () => {
    const directory = __dirname;
    const fautes: string[] = [];
    for (const file of readdirSync(directory)) {
      if (!file.endsWith('.ts') || file.endsWith('.spec.ts')) continue;
      const source = codeOnly(readFileSync(join(directory, file), 'utf8'));
      for (const interdit of INTERDITS) {
        if (source.includes(interdit)) fautes.push(`${file} : ${interdit}`);
      }
    }
    expect(fautes).toEqual([]);
  });

  it('et le garde sait vraiment détecter une faute', () => {
    // Un garde qu'on n'a jamais vu tomber ne prouve rien : on lui montre le
    // code qu'il doit refuser, et le commentaire qu'il doit laisser passer.
    const fautif = 'const x = Math.random();';
    const innocent = '// on n’utilise jamais Math.random( ici\nconst x = 1;';
    expect(INTERDITS.some((interdit) => codeOnly(fautif).includes(interdit))).toBe(true);
    expect(INTERDITS.some((interdit) => codeOnly(innocent).includes(interdit))).toBe(false);
  });
});
