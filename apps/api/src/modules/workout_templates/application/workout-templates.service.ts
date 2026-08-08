import { type WorkoutTemplateDetail, type WorkoutTemplateSummary } from '@carlys/api-contracts';
import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, WorkoutSetKind } from '@prisma/client';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import {
  type TemplateWithContent,
  WorkoutTemplatesRepository,
} from '../infrastructure/workout-templates.repository';
import { presentTemplateDetail, presentTemplateSummary } from './workout-template.presenter';

export interface PlannedSetInput {
  id: string;
  kind?: WorkoutSetKind | null;
  targetReps?: number | null;
  targetWeightKg?: number | null;
  restSeconds?: number | null;
}

export interface TemplateExerciseInput {
  id: string;
  exerciseId?: string | null;
  exerciseName?: string | null;
  notes?: string | null;
  sets: PlannedSetInput[];
}

export interface SaveTemplateInput {
  name: string;
  notes?: string | null;
  estimatedDurationMinutes?: number | null;
  exercises: TemplateExerciseInput[];
}

export interface TemplatesPage {
  items: WorkoutTemplateSummary[];
  nextCursor: string | null;
  hasMore: boolean;
}

export interface SavedTemplate {
  /** 201 à la création, 200 au remplacement — le client rejoue sans surprise. */
  created: boolean;
  template: WorkoutTemplateDetail;
}

/** Provenance d'une séance : modèle résolu côté serveur, nom dénormalisé. */
export interface SessionOrigin {
  templateId: string | null;
  templateName: string | null;
}

interface TemplateRows {
  exercises: Prisma.WorkoutTemplateExerciseCreateManyInput[];
  sets: Prisma.WorkoutTemplateSetCreateManyInput[];
}

/**
 * Modèles de séance : documents PRESCRIPTIFS réutilisables, écrits par un
 * unique `PUT` de remplacement complet. Les identifiants viennent de
 * l'appareil et les positions sont dérivées de l'ordre des tableaux reçus :
 * rejouer le même corps produit exactement le même état.
 */
@Injectable()
export class WorkoutTemplatesService {
  constructor(
    private readonly templates: WorkoutTemplatesRepository,
    @InjectPinoLogger(WorkoutTemplatesService.name)
    private readonly logger: PinoLogger,
  ) {}

  async listTemplates(userId: string, limit: number, cursor?: string): Promise<TemplatesPage> {
    const rows = await this.templates.listTemplatesPage(userId, limit, cursor);
    const hasMore = rows.length > limit;
    const items = rows.slice(0, limit).map(presentTemplateSummary);
    return {
      items,
      hasMore,
      nextCursor: hasMore ? (items.at(-1)?.id ?? null) : null,
    };
  }

  async templateDetail(userId: string, templateId: string): Promise<WorkoutTemplateDetail> {
    return presentTemplateDetail(await this.visibleTemplate(userId, templateId));
  }

  /** Crée ou remplace intégralement le modèle décrit par le corps. */
  async saveTemplate(
    userId: string,
    templateId: string,
    input: SaveTemplateInput,
  ): Promise<SavedTemplate> {
    const existing = await this.templates.findTemplateById(templateId);
    if (existing !== null && existing.userId !== userId) {
      // Id déjà pris par quelqu'un d'autre : conflit franc, pas un rejeu.
      throw new ConflictException('Identifiant de modèle déjà utilisé.');
    }
    if (existing !== null && existing.deletedAt !== null) {
      // Un PUT ne ressuscite pas un modèle supprimé.
      throw new NotFoundException('Modèle de séance introuvable.');
    }

    const name = input.name.trim();
    if (name.length === 0) {
      throw new BadRequestException('Le nom du modèle est obligatoire.');
    }
    this.assertUniqueContentIds(input.exercises);
    const rows = await this.buildRows(templateId, input.exercises);

    try {
      await this.templates.replaceTemplate({
        id: templateId,
        userId,
        name,
        notes: input.notes ?? null,
        estimatedDurationMinutes: input.estimatedDurationMinutes ?? null,
        exercises: rows.exercises,
        sets: rows.sets,
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        // Un id de ligne ou de série prévue appartient déjà à un autre modèle.
        throw new ConflictException('Identifiant de contenu déjà utilisé par un autre modèle.');
      }
      throw error;
    }

    const saved = await this.templates.findTemplateById(templateId);
    if (saved === null) {
      throw new NotFoundException('Modèle de séance introuvable.');
    }
    this.logger.info(
      {
        templateId,
        exercisesCount: rows.exercises.length,
        plannedSetsCount: rows.sets.length,
        created: existing === null,
      },
      'workout_template.saved',
    );
    return { created: existing === null, template: presentTemplateDetail(saved) };
  }

  /**
   * Suppression LOGIQUE, rejouable : un modèle inconnu ou déjà supprimé est un
   * succès (le rejeu d'une suppression déjà propagée doit aboutir). Les séances
   * passées ne bougent pas : elles gardent `templateName` dénormalisé.
   */
  async deleteTemplate(userId: string, templateId: string): Promise<void> {
    const template = await this.templates.findTemplateById(templateId);
    if (template === null) {
      return;
    }
    if (template.userId !== userId) {
      throw new NotFoundException('Modèle de séance introuvable.');
    }
    if (template.deletedAt !== null) {
      return;
    }
    await this.templates.softDeleteTemplate(templateId);
    this.logger.info({ templateId }, 'workout_template.deleted');
  }

  /**
   * Provenance d'une séance qu'on démarre. N'ÉCHOUE JAMAIS à cause du modèle :
   * si l'opération `template.save` a été refusée définitivement, la séance
   * arrive quand même, avec le nom conservé par le client.
   */
  async resolveSessionOrigin(
    userId: string,
    input: { templateId?: string; templateName?: string },
  ): Promise<SessionOrigin> {
    if (input.templateId !== undefined) {
      const template = await this.templates.findLaunchableTemplate(userId, input.templateId);
      if (template !== null) {
        return { templateId: template.id, templateName: template.name };
      }
    }
    const fallback = input.templateName?.trim();
    return {
      templateId: null,
      templateName: fallback === undefined || fallback.length === 0 ? null : fallback,
    };
  }

  /** Inexistant, supprimé, ou à quelqu'un d'autre : 404 dans les trois cas. */
  private async visibleTemplate(userId: string, templateId: string): Promise<TemplateWithContent> {
    const template = await this.templates.findTemplateById(templateId);
    if (template === null || template.userId !== userId || template.deletedAt !== null) {
      throw new NotFoundException('Modèle de séance introuvable.');
    }
    return template;
  }

  /**
   * Les positions ne sont jamais transmises : l'ordre des tableaux fait foi.
   * Un client ne peut donc produire ni trou ni doublon de position.
   */
  private async buildRows(
    templateId: string,
    exercises: TemplateExerciseInput[],
  ): Promise<TemplateRows> {
    const catalogNames = await this.templates.publishedExerciseNames(
      exercises.flatMap((exercise) =>
        exercise.exerciseId === undefined || exercise.exerciseId === null
          ? []
          : [exercise.exerciseId],
      ),
    );

    const rows: TemplateRows = { exercises: [], sets: [] };
    exercises.forEach((exercise, exercisePosition) => {
      const catalogName =
        exercise.exerciseId === undefined || exercise.exerciseId === null
          ? undefined
          : catalogNames.get(exercise.exerciseId);
      const fallback = exercise.exerciseName?.trim();
      if (catalogName === undefined && (fallback === undefined || fallback.length === 0)) {
        throw new BadRequestException('exerciseId inconnu et exerciseName absent.');
      }
      rows.exercises.push({
        id: exercise.id,
        templateId,
        // Non résolu = inconnu ou dépublié : la ligne devient un exercice
        // libre, portée par son seul nom dénormalisé (clé étrangère sûre).
        exerciseId: catalogName === undefined ? null : (exercise.exerciseId ?? null),
        exerciseName: catalogName ?? (fallback as string),
        position: exercisePosition,
        notes: exercise.notes ?? null,
      });
      exercise.sets.forEach((set, setPosition) => {
        rows.sets.push({
          id: set.id,
          templateExerciseId: exercise.id,
          position: setPosition,
          kind: set.kind ?? WorkoutSetKind.NORMAL,
          targetReps: set.targetReps ?? null,
          targetWeightKg: set.targetWeightKg ?? null,
          restSeconds: set.restSeconds ?? null,
        });
      });
    });
    return rows;
  }

  /** Un id répété rendrait l'écriture non rejouable : on refuse tôt et clair. */
  private assertUniqueContentIds(exercises: TemplateExerciseInput[]): void {
    const seen = new Set<string>();
    for (const exercise of exercises) {
      for (const id of [exercise.id, ...exercise.sets.map((set) => set.id)]) {
        if (seen.has(id)) {
          throw new BadRequestException('Identifiant dupliqué dans le corps de la requête.');
        }
        seen.add(id);
      }
    }
  }
}
