import { type GenerationVolume } from '@carlys/api-contracts';
import { ExerciseType } from '@prisma/client';
import {
  GENERATION_RULES_VERSION,
  PULL_TO_PUSH_MIN_RATIO,
  VOLUME_FACTOR,
  WEEKLY_SETS_FLOOR,
} from './constants';
import { buildDays, weekPlan } from './calendar';
import { pullToPushRatio, verify } from './constraints';
import { FREE_LABEL_NOTE } from './endurance-catalog';
import { GOAL_RULES, weeklySetsRange } from './goal-rules';
import { suggestLevers, uselessLevers } from './levers';
import { groupPool, secondaryPool } from './selection';
import { type WorkingState, buildTemplate, relax, uncoveredGroups } from './slot-filler';
import { buildSlots, enduranceDayCount, normalizeSessions, type Slot } from './splits';
import { type GenerationInput, type GenerationOutcome, type PrescribedTemplate } from './types';

/**
 * LE GÉNÉRATEUR — fonction PURE de (profil, catalogue, `programId`).
 *
 * Aucune base, aucun réseau, aucune horloge, aucun hasard. C'est ce qui rend
 * la tranche testable au produit des entrées, et c'est aussi ce qui la rend
 * AUDITABLE : rejouer le calcul explique un programme écrit il y a trois
 * mois, ce qu'une génération qui dépendrait de l'heure ou d'un tirage ne
 * permettrait jamais.
 *
 * Ce fichier ORCHESTRE, il ne décide rien tout seul. Les dosages sont dans
 * `goal-rules.ts`, le temps dans `session-budget.ts`, le choix des mouvements
 * dans `selection.ts`, la composition d'une séance dans `slot-filler.ts`, la
 * place des jours dans `calendar.ts`, la relecture dans `constraints.ts`.
 */

function volumeReport(
  slots: Slot[],
  weeklySets: Map<string, number>,
  goal: GenerationInput['goal'],
  experience: GenerationInput['experience'],
): GenerationVolume[] {
  const rules = GOAL_RULES[goal];
  const factor = VOLUME_FACTOR[experience];
  const groups = [...new Set(slots.flatMap((slot) => slot.groups))].sort();
  return groups.map((group) => {
    const range = weeklySetsRange(rules, group);
    return {
      muscleGroup: group,
      weeklySets: weeklySets.get(group) ?? 0,
      targetMin: Math.max(Math.ceil(range.min * factor), WEEKLY_SETS_FLOOR),
      targetMax: Math.floor(range.max * factor),
    };
  });
}

export function generateProgram(input: GenerationInput): GenerationOutcome {
  const rules = GOAL_RULES[input.goal];
  const sessions = normalizeSessions(input.goal, input.experience, input.weeklySessionsTarget);
  const state: WorkingState = { relaxations: [], notes: [], weeklySets: new Map() };

  if (sessions !== input.weeklySessionsTarget) {
    relax(
      state,
      'R0_RYTHME_NORMALISE',
      null,
      input.weeklySessionsTarget,
      sessions,
      `Tu visais ${input.weeklySessionsTarget} séances : l’objectif et ton niveau en retiennent ${sessions}.`,
    );
  }

  const trainable = input.pool.filter(
    (exercise) => exercise.type === ExerciseType.STRENGTH || exercise.type === ExerciseType.CARDIO,
  );
  const byGroup = groupPool(trainable, input.experience);
  const bySecondary = secondaryPool(trainable, input.experience);

  // LA PORTE : on ne refuse que là où le NOM de l'objectif serait un mensonge.
  // Un trou de catalogue ailleurs se dégrade et se dit — refuser tout un
  // segment de personnes sur une pénurie transforme un manque de contenu en
  // mur produit.
  const blocking = rules.requiredGroups.filter((group) => (byGroup.get(group)?.length ?? 0) === 0);
  if (blocking.length > 0) {
    const kit = new Set(input.equipmentSlugs);
    const levers = suggestLevers(
      input.catalogue,
      kit,
      input.experience,
      blocking,
      input.equipmentNames,
    );
    const inutiles = uselessLevers(
      input.catalogue,
      kit,
      input.experience,
      blocking,
      input.equipmentNames,
    );
    return {
      kind: 'impossible',
      blockingGroups: blocking,
      levers,
      message:
        `Cet objectif demande au moins un exercice de ${blocking.join(' et de ')}, ` +
        `et ton matériel n’en ouvre aucun à ton niveau.` +
        (inutiles.length > 0
          ? ` À ne pas acheter pour autant : ${inutiles.join(', ')} — ces exercices sont au-dessus de ton niveau.`
          : ''),
    };
  }

  const enduranceDays = enduranceDayCount(input.goal, sessions);
  const slots = buildSlots(input.goal, input.experience, sessions);
  const weeksCount = rules.weeksCount;

  const plan = weekPlan(sessions, enduranceDays, slots.length);
  const templates: PrescribedTemplate[] = [];
  const templatesByWeek = new Map<string, PrescribedTemplate>();
  for (let week = 1; week <= weeksCount; week += 1) {
    const usedInWeek = new Map<string, number>();
    const weekLoad: Map<number, Map<string, number>> = new Map();
    // Dans l'ORDRE DES JOURS, pas dans l'ordre des créneaux : la contrainte de
    // récupération regarde ce que les jours précédents ont déjà chargé, donc
    // composer un mardi avant un lundi la rendrait aveugle.
    for (const entry of plan) {
      if (entry.slotIndex === null) continue;
      const already = templatesByWeek.get(`${entry.slotIndex}:${week}`);
      if (already !== undefined) continue;
      const template = buildTemplate(
        input,
        slots[entry.slotIndex]!,
        entry.slotIndex,
        week,
        entry.dayOfWeek,
        byGroup,
        bySecondary,
        usedInWeek,
        weekLoad,
        state,
      );
      templates.push(template);
      templatesByWeek.set(`${entry.slotIndex}:${week}`, template);
    }
  }

  const days = buildDays(input, slots, plan, templatesByWeek, weeksCount);

  // Le volume hebdomadaire se compte sur UNE semaine type : le mésocycle fait
  // varier les séries, mais la fourchette se juge sur la semaine de base.
  const weeklySets = new Map<string, number>();
  for (const [group, total] of state.weeklySets) {
    weeklySets.set(group, Math.round(total / weeksCount));
  }
  const volumes = volumeReport(slots, weeklySets, input.goal, input.experience);
  for (const volume of volumes) {
    if (volume.weeklySets < volume.targetMin) {
      relax(
        state,
        'R6_GROUPE_SOUS_LE_MINIMUM',
        volume.muscleGroup,
        volume.targetMin,
        volume.weeklySets,
        `« ${volume.muscleGroup} » reçoit ${volume.weeklySets} séries par semaine au lieu de ${volume.targetMin} : le catalogue jouable n’en offre pas davantage.`,
      );
    }
  }

  const ratio = pullToPushRatio(weeklySets);
  if (ratio !== null && ratio < PULL_TO_PUSH_MIN_RATIO) {
    relax(
      state,
      'H9_RATIO_TIRAGE_POUSSEE',
      null,
      Math.round(PULL_TO_PUSH_MIN_RATIO * 100),
      Math.round(ratio * 100),
      `Ce programme pousse plus qu’il ne tire (${Math.round(ratio * 100)} % au lieu de ${Math.round(PULL_TO_PUSH_MIN_RATIO * 100)} %). Sur plusieurs semaines, ce déséquilibre enroule les épaules : ajoute une barre de traction ou un élastique dès que tu peux.`,
    );
  }

  const uncovered = uncoveredGroups(slots, byGroup);
  if (uncovered.length > 0) {
    state.notes.push(
      `Aucun exercice jouable pour ${uncovered.join(', ')} : ces groupes ne sont pas au programme.`,
    );
  }
  const kit = new Set(input.equipmentSlugs);
  const manquants = volumes
    .filter((volume) => volume.weeklySets < volume.targetMin)
    .map((volume) => volume.muscleGroup);
  const cibles = [...manquants, ...uncovered];
  const leviers = suggestLevers(
    input.catalogue,
    kit,
    input.experience,
    cibles,
    input.equipmentNames,
  );
  const inutiles = uselessLevers(
    input.catalogue,
    kit,
    input.experience,
    cibles,
    input.equipmentNames,
  );
  if (leviers.length > 0) {
    const meilleur = leviers[0]!;
    state.notes.push(
      `Pour aller plus loin : « ${meilleur.name} » ouvrirait ${meilleur.unlocks} exercices de plus (${meilleur.muscleGroups.join(', ')}).`,
    );
  }
  if (inutiles.length > 0) {
    state.notes.push(
      `À ne pas acheter pour ça : ${inutiles.join(', ')} — ces exercices sont au-dessus de ton niveau actuel.`,
    );
  }

  const freeLabelDays = days.filter((day) => !day.isRest && day.templateId === null).length;
  if (freeLabelDays > 0) state.notes.push(FREE_LABEL_NOTE);

  const violations = verify({
    days,
    templates,
    pool: trainable,
    rules,
    experience: input.experience,
    sessionsPerWeek: sessions,
    weeksCount,
  });
  for (const violation of violations) {
    relax(
      state,
      violation.rule,
      violation.subject,
      null,
      null,
      `Contrainte non tenue : ${violation.detail}.`,
    );
  }

  return {
    kind: 'program',
    program: {
      name: `Programme ${weeksCount} semaines`,
      description: `Généré pour ${sessions} séances par semaine de ${input.sessionMinutesTarget} minutes.`,
      weeksCount,
      days,
      templates,
    },
    report: {
      status: state.relaxations.length === 0 ? 'satisfied' : 'relaxed',
      rulesVersion: GENERATION_RULES_VERSION,
      goal: input.goal,
      experience: input.experience,
      sessionsPerWeek: sessions,
      split: slots.map((slot) => slot.name),
      templatedDays: days.filter((day) => day.templateId !== null).length,
      freeLabelDays,
      restDays: days.filter((day) => day.isRest).length,
      templatesCreated: templates.length,
      weeklyVolume: volumes,
      uncoveredGroups: uncovered,
      relaxations: state.relaxations,
      notes: state.notes,
    },
  };
}
