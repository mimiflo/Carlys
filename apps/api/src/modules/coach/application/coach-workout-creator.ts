import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { type WorkoutSetKind } from '@prisma/client';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { WorkoutTemplatesService } from '../../workout_templates/application/workout-templates.service';
import { CoachRepository } from '../infrastructure/coach.repository';

/** Une série proposée, telle qu'un modèle de séance la reprend. */
interface ProposedSet {
  id: string;
  exercisePosition: number;
  exerciseId: string;
  setPosition: number;
  kind: WorkoutSetKind;
  targetReps: number | null;
  targetWeightKg: number | null;
  restSeconds: number | null;
}

export interface ProposedWorkout {
  name: string;
  estimatedMinutes: number;
  sets: ProposedSet[];
}

/** La séance enregistrée — ou la raison MÉTIER qui l'en empêche, à dire telle quelle. */
export type CreatedWorkout =
  { ok: true; templateId: string; name: string } | { ok: false; reason: string };

const GONE =
  'Je ne retrouve plus cette séance. Dis-moi ce que tu veux travailler, je t’en compose une.';
const DELETED =
  'Tu avais supprimé cette séance de tes modèles. Dis-moi ce que tu veux travailler, je t’en compose une nouvelle.';

/**
 * GARDER une séance du coach : toute proposition validée (« Ok crée-la »,
 * « Enregistre ça » ne font plus que le confirmer) devient un MODÈLE de
 * séance, enregistré dans Carlys — la seule séance durable qu'on puisse
 * écrire sans la lancer (une séance, elle, naît sur l'appareil quand on la
 * commence). Le modèle apparaît dans « Mes modèles », se relit, se retouche
 * et se lance comme les autres.
 *
 * IDEMPOTENT par construction : le modèle prend l'identifiant de la
 * proposition (et ses séries ceux des séries proposées). Le redemander, un
 * double appui, un renvoi de l'appareil : le même modèle, jamais deux — et
 * jamais réécrit, pour ne pas effacer les retouches faites depuis.
 *
 * Le modèle est marqué `fromCoach` : il se range dans la catégorie « Coach »
 * de « Mes modèles », et ce marquage ne se pose qu'ici, à la création.
 */
@Injectable()
export class CoachWorkoutCreator {
  constructor(
    private readonly templates: WorkoutTemplatesService,
    private readonly repository: CoachRepository,
    @InjectPinoLogger(CoachWorkoutCreator.name) private readonly logger: PinoLogger,
  ) {}

  /** La proposition `proposalId` de cette personne, déjà archivée. */
  async fromStored(userId: string, proposalId: string): Promise<CreatedWorkout> {
    const proposal = await this.repository.findOwnProposal(userId, proposalId);
    if (proposal === null) return { ok: false, reason: GONE };
    return this.save(userId, proposalId, {
      name: proposal.name,
      estimatedMinutes: proposal.estimatedMinutes,
      sets: proposal.items.map((item) => ({
        ...item,
        targetWeightKg: item.targetWeightKg === null ? null : Number(item.targetWeightKg),
      })),
    });
  }

  /** `workout`, enregistré sous l'identifiant de sa proposition. */
  async save(
    userId: string,
    proposalId: string,
    workout: ProposedWorkout,
  ): Promise<CreatedWorkout> {
    const existing = await this.templates
      .templateDetail(userId, proposalId)
      .catch((error: unknown) => {
        if (error instanceof NotFoundException) return null;
        throw error;
      });
    if (existing !== null) {
      return { ok: true, templateId: existing.id, name: existing.name };
    }
    try {
      const saved = await this.templates.saveTemplate(
        userId,
        proposalId,
        {
          name: workout.name,
          estimatedDurationMinutes: workout.estimatedMinutes,
          exercises: exercisesOf(workout.sets),
        },
        { fromCoach: true },
      );
      this.logger.info({ userId, templateId: proposalId }, 'Séance du coach enregistrée');
      return { ok: true, templateId: saved.template.id, name: saved.template.name };
    } catch (error) {
      // Supprimé depuis : un PUT ne ressuscite pas un modèle (règle des modèles).
      if (error instanceof NotFoundException) return { ok: false, reason: DELETED };
      // Deux « crée-la » au même instant : l'autre a écrit, c'est le même.
      if (error instanceof ConflictException) {
        const written = await this.templates.templateDetail(userId, proposalId);
        return { ok: true, templateId: written.id, name: written.name };
      }
      throw error;
    }
  }
}

/**
 * Les séries regroupées par exercice, dans l'ordre. Les séries gardent les
 * identifiants des séries proposées ; chaque ligne reçoit le sien (un même
 * identifiant deux fois dans le corps est refusé par les modèles).
 */
function exercisesOf(sets: readonly ProposedSet[]) {
  const byPosition = new Map<number, ProposedSet[]>();
  const ordered = [...sets].sort(
    (a, b) => a.exercisePosition - b.exercisePosition || a.setPosition - b.setPosition,
  );
  for (const set of ordered) {
    byPosition.set(set.exercisePosition, [...(byPosition.get(set.exercisePosition) ?? []), set]);
  }
  return [...byPosition.values()].flatMap(([first, ...rest]) =>
    first === undefined
      ? []
      : [
          {
            id: randomUUID(),
            exerciseId: first.exerciseId,
            sets: [first, ...rest].map((row) => ({
              id: row.id,
              kind: row.kind,
              targetReps: row.targetReps,
              targetWeightKg: row.targetWeightKg,
              restSeconds: row.restSeconds,
            })),
          },
        ],
  );
}
