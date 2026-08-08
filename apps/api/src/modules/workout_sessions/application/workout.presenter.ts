import {
  type WorkoutSessionDetail,
  type WorkoutSessionPlanItem as WorkoutSessionPlanItemContract,
  type WorkoutSessionSummary,
  type WorkoutSet as WorkoutSetContract,
} from '@carlys/api-contracts';
import { type WorkoutSessionPlanItem, type WorkoutSet } from '@prisma/client';
import { type SessionWithSets } from '../infrastructure/workouts.repository';

export function presentSet(set: WorkoutSet): WorkoutSetContract {
  return {
    id: set.id,
    exerciseId: set.exerciseId,
    exerciseName: set.exerciseName,
    position: set.position,
    kind: set.kind,
    reps: set.reps,
    weightKg: set.weightKg === null ? null : Number(set.weightKg),
    durationSeconds: set.durationSeconds,
    distanceMeters: set.distanceMeters,
    rpe: set.rpe,
    restSeconds: set.restSeconds,
    completedAt: set.completedAt.toISOString(),
    plannedReps: set.plannedReps,
    plannedWeightKg: set.plannedWeightKg === null ? null : Number(set.plannedWeightKg),
  };
}

export function presentSessionSummary(session: SessionWithSets): WorkoutSessionSummary {
  const totalVolumeKg = session.sets.reduce((total, set) => {
    if (set.reps === null || set.weightKg === null) {
      return total;
    }
    return total + set.reps * Number(set.weightKg);
  }, 0);

  return {
    id: session.id,
    name: session.name,
    status: session.status,
    startedAt: session.startedAt.toISOString(),
    endedAt: session.endedAt?.toISOString() ?? null,
    durationSeconds: session.durationSeconds,
    setsCount: session.sets.length,
    totalVolumeKg: Math.round(totalVolumeKg),
    templateId: session.templateId,
    templateName: session.templateName,
  };
}

export function presentPlanItem(item: WorkoutSessionPlanItem): WorkoutSessionPlanItemContract {
  return {
    id: item.id,
    exercisePosition: item.exercisePosition,
    exerciseId: item.exerciseId,
    exerciseName: item.exerciseName,
    setPosition: item.setPosition,
    kind: item.kind,
    targetReps: item.targetReps,
    targetWeightKg: item.targetWeightKg === null ? null : Number(item.targetWeightKg),
    restSeconds: item.restSeconds,
    doneSetId: item.doneSetId,
    skipped: item.skipped,
  };
}

export function presentSessionDetail(session: SessionWithSets): WorkoutSessionDetail {
  return {
    ...presentSessionSummary(session),
    notes: session.notes,
    sets: session.sets.map(presentSet),
    plan: session.planItems.map(presentPlanItem),
  };
}
