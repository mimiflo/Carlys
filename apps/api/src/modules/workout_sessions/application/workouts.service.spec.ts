import { ConflictException, NotFoundException } from '@nestjs/common';
import { WorkoutSessionStatus, WorkoutSetKind } from '@prisma/client';
import { type ProgressService } from '../../progress/application/progress.service';
import { type WorkoutTemplatesService } from '../../workout_templates/application/workout-templates.service';
import {
  type SessionWithSets,
  type WorkoutsRepository,
} from '../infrastructure/workouts.repository';
import { WorkoutsService } from './workouts.service';

const USER = 'user-1';
const OTHER_USER = 'user-2';

function sessionRow(overrides: Partial<SessionWithSets> = {}): SessionWithSets {
  return {
    id: 'session-1',
    userId: USER,
    name: null,
    notes: null,
    status: WorkoutSessionStatus.IN_PROGRESS,
    startedAt: new Date('2026-08-07T10:00:00Z'),
    endedAt: null,
    durationSeconds: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    deletedAt: null,
    templateId: null,
    templateName: null,
    sets: [],
    planItems: [],
    ...overrides,
  };
}

interface Stubs {
  createSession: jest.Mock;
  findSessionById: jest.Mock;
  listSessionsPage: jest.Mock;
  updateSession: jest.Mock;
  transitionStatus: jest.Mock;
  createSet: jest.Mock;
  findSetById: jest.Mock;
  updateSet: jest.Mock;
  softDeleteSet: jest.Mock;
  exercisePublishedName: jest.Mock;
  publishedExerciseNames: jest.Mock;
  linkPlanItem: jest.Mock;
  skipPlanItems: jest.Mock;
}

function buildStubs(): Stubs {
  return {
    createSession: jest.fn().mockResolvedValue(true),
    findSessionById: jest.fn().mockResolvedValue(sessionRow()),
    listSessionsPage: jest.fn().mockResolvedValue([]),
    updateSession: jest.fn().mockResolvedValue(sessionRow()),
    transitionStatus: jest.fn().mockResolvedValue(true),
    createSet: jest.fn().mockResolvedValue(true),
    findSetById: jest.fn().mockResolvedValue(null),
    updateSet: jest.fn(),
    softDeleteSet: jest.fn().mockResolvedValue(undefined),
    exercisePublishedName: jest.fn().mockResolvedValue('Développé couché'),
    publishedExerciseNames: jest.fn().mockResolvedValue(new Map()),
    linkPlanItem: jest.fn().mockResolvedValue(undefined),
    skipPlanItems: jest.fn().mockResolvedValue(0),
  };
}

/** Par défaut : aucun modèle résolu — une séance libre, comme avant. */
function buildTemplates(origin: { templateId: string | null; templateName: string | null }): {
  resolveSessionOrigin: jest.Mock;
} {
  return { resolveSessionOrigin: jest.fn().mockResolvedValue(origin) };
}

function buildService(
  stubs: Stubs,
  progress: { updateRecordsForSession: jest.Mock } = {
    updateRecordsForSession: jest.fn().mockResolvedValue(undefined),
  },
  templates: { resolveSessionOrigin: jest.Mock } = buildTemplates({
    templateId: null,
    templateName: null,
  }),
): WorkoutsService {
  return new WorkoutsService(
    stubs as unknown as WorkoutsRepository,
    progress as unknown as ProgressService,
    templates as unknown as WorkoutTemplatesService,
  );
}

const createInput = {
  id: 'session-1',
  startedAt: new Date('2026-08-07T10:00:00Z'),
};

const setInput = {
  id: 'set-1',
  exerciseId: 'exercise-1',
  position: 0,
  reps: 10,
  weightKg: 60,
  completedAt: new Date('2026-08-07T10:05:00Z'),
};

function setRow(overrides: Record<string, unknown> = {}): unknown {
  return {
    id: 'set-1',
    sessionId: 'session-1',
    exerciseId: 'exercise-1',
    exerciseName: 'Développé couché',
    position: 0,
    kind: WorkoutSetKind.NORMAL,
    reps: 10,
    weightKg: 60,
    durationSeconds: null,
    distanceMeters: null,
    rpe: null,
    restSeconds: null,
    plannedReps: null,
    plannedWeightKg: null,
    completedAt: new Date('2026-08-07T10:05:00Z'),
    createdAt: new Date(),
    updatedAt: new Date(),
    deletedAt: null,
    session: sessionRow(),
    ...overrides,
  };
}

describe('WorkoutsService', () => {
  describe('createSession (idempotent)', () => {
    it('rejouer la création renvoie la séance existante sans doublon', async () => {
      const stubs = buildStubs();
      stubs.createSession.mockResolvedValue(false); // id déjà présent
      const service = buildService(stubs);

      const session = await service.createSession(USER, createInput);

      expect(session.id).toBe('session-1');
      expect(stubs.createSession).toHaveBeenCalledTimes(1);
    });

    it('un id appartenant à un autre utilisateur reste invisible (404)', async () => {
      const stubs = buildStubs();
      stubs.createSession.mockResolvedValue(false);
      stubs.findSessionById.mockResolvedValue(sessionRow({ userId: OTHER_USER }));
      const service = buildService(stubs);

      await expect(service.createSession(USER, createInput)).rejects.toThrow(NotFoundException);
    });

    it('date le dernier lancement du modèle DANS la création quand il est résolu', async () => {
      const stubs = buildStubs();
      const templates = buildTemplates({ templateId: 'modele-1', templateName: 'Push — Force' });
      const service = buildService(stubs, undefined, templates);

      await service.createSession(USER, { ...createInput, templateId: 'modele-1' });

      expect(stubs.createSession).toHaveBeenCalledWith(
        expect.objectContaining({ templateId: 'modele-1', templateName: 'Push — Force' }),
        { templateId: 'modele-1', userId: USER, lastUsedAt: createInput.startedAt },
        [],
      );
    });

    it('un modèle inconnu n’empêche JAMAIS la séance : nom client conservé', async () => {
      const stubs = buildStubs();
      // Résolution en échec : le service des modèles ne lève jamais.
      const templates = buildTemplates({ templateId: null, templateName: 'Push — Force' });
      const service = buildService(stubs, undefined, templates);

      await service.createSession(USER, {
        ...createInput,
        templateId: 'modele-inconnu',
        templateName: 'Push — Force',
      });

      expect(stubs.createSession).toHaveBeenCalledWith(
        expect.objectContaining({ templateId: null, templateName: 'Push — Force' }),
        undefined,
        [],
      );
    });
  });

  describe('createSession — plan de séance (reprise multi-appareil)', () => {
    const planItem = {
      id: 'plan-1',
      exercisePosition: 0,
      exerciseName: 'Développé couché',
      setPosition: 0,
      targetReps: 8,
      targetWeightKg: 60,
      restSeconds: 90,
    };

    it('écrit le plan DANS la création, donc annulé avec elle par un rejeu', async () => {
      const stubs = buildStubs();
      const service = buildService(stubs);

      await service.createSession(USER, { ...createInput, plan: [planItem] });

      expect(stubs.createSession).toHaveBeenCalledWith(expect.anything(), undefined, [
        expect.objectContaining({
          id: 'plan-1',
          sessionId: 'session-1',
          exerciseName: 'Développé couché',
          targetReps: 8,
          targetWeightKg: 60,
          kind: WorkoutSetKind.NORMAL,
        }),
      ]);
    });

    it('un exerciseId inconnu dégrade la prévision au lieu de perdre la séance', async () => {
      const stubs = buildStubs();
      stubs.publishedExerciseNames.mockResolvedValue(new Map()); // catalogue muet
      const service = buildService(stubs);

      await service.createSession(USER, {
        ...createInput,
        plan: [{ ...planItem, exerciseId: 'exercice-inconnu' }],
      });

      expect(stubs.createSession).toHaveBeenCalledWith(expect.anything(), undefined, [
        expect.objectContaining({ exerciseId: null, exerciseName: 'Développé couché' }),
      ]);
    });

    it('le nom du catalogue prime sur le nom transmis quand il est résolu', async () => {
      const stubs = buildStubs();
      stubs.publishedExerciseNames.mockResolvedValue(
        new Map([['exercice-1', 'Développé couché (barre)']]),
      );
      const service = buildService(stubs);

      await service.createSession(USER, {
        ...createInput,
        plan: [{ ...planItem, exerciseId: 'exercice-1', exerciseName: 'Vieux nom' }],
      });

      expect(stubs.createSession).toHaveBeenCalledWith(expect.anything(), undefined, [
        expect.objectContaining({
          exerciseId: 'exercice-1',
          exerciseName: 'Développé couché (barre)',
        }),
      ]);
    });

    it('sert le plan stocké dans le détail de la séance', async () => {
      const stubs = buildStubs();
      stubs.findSessionById.mockResolvedValue(
        sessionRow({
          planItems: [
            {
              id: 'plan-1',
              sessionId: 'session-1',
              exercisePosition: 0,
              exerciseId: null,
              exerciseName: 'Développé couché',
              setPosition: 0,
              kind: WorkoutSetKind.NORMAL,
              targetReps: 8,
              targetWeightKg: null,
              restSeconds: 90,
              doneSetId: null,
              skipped: false,
              createdAt: new Date(),
              updatedAt: new Date(),
            },
          ],
        }),
      );
      const service = buildService(stubs);

      const session = await service.sessionDetail(USER, 'session-1');

      expect(session.plan).toHaveLength(1);
      expect(session.plan[0]).toMatchObject({ id: 'plan-1', targetReps: 8, skipped: false });
    });
  });

  describe('appariement plan ↔ série', () => {
    it('apparie la prévision honorée par la série qui vient d’être créée', async () => {
      const stubs = buildStubs();
      stubs.findSetById.mockResolvedValueOnce(null).mockResolvedValue(setRow());
      const service = buildService(stubs);

      await service.addSet(USER, 'session-1', { ...setInput, planItemId: 'plan-1' });

      expect(stubs.linkPlanItem).toHaveBeenCalledWith('session-1', 'plan-1', 'set-1');
    });

    it('réapparie sur un rejeu : le premier envoi a pu s’interrompre entre les deux', async () => {
      const stubs = buildStubs();
      stubs.findSetById.mockResolvedValue(setRow()); // série déjà là
      const service = buildService(stubs);

      await service.addSet(USER, 'session-1', { ...setInput, planItemId: 'plan-1' });

      expect(stubs.createSet).not.toHaveBeenCalled();
      expect(stubs.linkPlanItem).toHaveBeenCalledWith('session-1', 'plan-1', 'set-1');
    });

    it('une série hors programme n’apparie rien', async () => {
      const stubs = buildStubs();
      stubs.findSetById.mockResolvedValueOnce(null).mockResolvedValue(setRow());
      const service = buildService(stubs);

      await service.addSet(USER, 'session-1', setInput);

      expect(stubs.linkPlanItem).not.toHaveBeenCalled();
    });

    it('passer des prévisions reste invisible pour la séance d’autrui', async () => {
      const stubs = buildStubs();
      stubs.findSessionById.mockResolvedValue(sessionRow({ userId: OTHER_USER }));
      const service = buildService(stubs);

      await expect(service.skipPlanItems(USER, 'session-1', ['plan-1'])).rejects.toThrow(
        NotFoundException,
      );
      expect(stubs.skipPlanItems).not.toHaveBeenCalled();
    });

    it('passer des prévisions délègue au dépôt, qui protège celles déjà faites', async () => {
      const stubs = buildStubs();
      const service = buildService(stubs);

      await service.skipPlanItems(USER, 'session-1', ['plan-1', 'plan-2']);

      expect(stubs.skipPlanItems).toHaveBeenCalledWith('session-1', ['plan-1', 'plan-2']);
    });
  });

  describe('completeSession (idempotent)', () => {
    it('rejouer la clôture d’une séance déjà terminée renvoie son état', async () => {
      const stubs = buildStubs();
      stubs.findSessionById.mockResolvedValue(
        sessionRow({
          status: WorkoutSessionStatus.COMPLETED,
          endedAt: new Date('2026-08-07T11:00:00Z'),
          durationSeconds: 3_600,
        }),
      );
      const service = buildService(stubs);

      const session = await service.completeSession(USER, 'session-1', {});

      expect(session.status).toBe('COMPLETED');
      expect(stubs.transitionStatus).not.toHaveBeenCalled();
    });

    it('terminer une séance abandonnée est un conflit, pas un rejeu', async () => {
      const stubs = buildStubs();
      stubs.findSessionById.mockResolvedValue(
        sessionRow({ status: WorkoutSessionStatus.ABANDONED }),
      );
      const service = buildService(stubs);

      await expect(service.completeSession(USER, 'session-1', {})).rejects.toThrow(
        ConflictException,
      );
    });

    it('calcule la durée depuis startedAt quand elle n’est pas fournie', async () => {
      const stubs = buildStubs();
      const service = buildService(stubs);

      await service.completeSession(USER, 'session-1', {
        endedAt: new Date('2026-08-07T10:45:00Z'),
      });

      expect(stubs.transitionStatus).toHaveBeenCalledWith(
        'session-1',
        WorkoutSessionStatus.COMPLETED,
        expect.objectContaining({ durationSeconds: 45 * 60 }),
      );
    });

    it('déclenche le recalcul des records avec les séries de la séance', async () => {
      const stubs = buildStubs();
      const sets = [setRow()] as never;
      stubs.findSessionById
        .mockResolvedValueOnce(sessionRow()) // pré-vérification
        .mockResolvedValue(sessionRow({ status: WorkoutSessionStatus.COMPLETED, sets }));
      const progress = { updateRecordsForSession: jest.fn().mockResolvedValue(undefined) };
      const service = buildService(stubs, progress);

      await service.completeSession(USER, 'session-1', {});

      expect(progress.updateRecordsForSession).toHaveBeenCalledWith(USER, 'session-1', sets);
    });

    it('abandonner une séance ne recalcule pas les records', async () => {
      const stubs = buildStubs();
      const progress = { updateRecordsForSession: jest.fn().mockResolvedValue(undefined) };
      const service = buildService(stubs, progress);

      await service.abandonSession(USER, 'session-1', {});

      expect(progress.updateRecordsForSession).not.toHaveBeenCalled();
    });
  });

  describe('addSet (upsert idempotent)', () => {
    it('rejouer l’ajout d’une série renvoie la série existante', async () => {
      const stubs = buildStubs();
      stubs.findSetById.mockResolvedValue(setRow());
      const service = buildService(stubs);

      const set = await service.addSet(USER, 'session-1', setInput);

      expect(set.id).toBe('set-1');
      expect(stubs.createSet).not.toHaveBeenCalled();
    });

    it('un id de série déjà pris par une autre séance est un conflit', async () => {
      const stubs = buildStubs();
      stubs.findSetById.mockResolvedValue(setRow({ sessionId: 'autre-session' }));
      const service = buildService(stubs);

      await expect(service.addSet(USER, 'session-1', setInput)).rejects.toThrow(ConflictException);
    });

    it('le nom d’exercice est résolu depuis le catalogue quand exerciseId est connu', async () => {
      const stubs = buildStubs();
      stubs.findSetById
        .mockResolvedValueOnce(null) // pré-vérification
        .mockResolvedValue(setRow()); // relecture après création
      const service = buildService(stubs);

      await service.addSet(USER, 'session-1', setInput);

      expect(stubs.createSet).toHaveBeenCalledWith(
        expect.objectContaining({ exerciseName: 'Développé couché' }),
      );
    });

    it('enregistre la cible affichée à côté de ce qui a été RÉELLEMENT fait', async () => {
      const stubs = buildStubs();
      stubs.findSetById.mockResolvedValueOnce(null).mockResolvedValue(setRow());
      const service = buildService(stubs);

      // Déviation assumée : 7 reps faites pour 8 prévues — jamais une erreur.
      await service.addSet(USER, 'session-1', {
        ...setInput,
        reps: 7,
        plannedReps: 8,
        plannedWeightKg: 60,
      });

      expect(stubs.createSet).toHaveBeenCalledWith(
        expect.objectContaining({ reps: 7, plannedReps: 8, plannedWeightKg: 60 }),
      );
    });
  });

  describe('updateSet', () => {
    it('ne réécrit jamais la cible affichée à la validation', async () => {
      const stubs = buildStubs();
      stubs.findSetById.mockResolvedValue(setRow());
      stubs.updateSet.mockResolvedValue(setRow({ reps: 12 }));
      const service = buildService(stubs);

      await service.updateSet(USER, 'set-1', { reps: 12 });

      const [, patch] = stubs.updateSet.mock.calls[0] as [string, Record<string, unknown>];
      expect(patch).not.toHaveProperty('plannedReps');
      expect(patch).not.toHaveProperty('plannedWeightKg');
    });
  });

  describe('deleteSet (idempotent)', () => {
    it('supprimer une série déjà supprimée ou inconnue aboutit sans erreur', async () => {
      const stubs = buildStubs();
      stubs.findSetById.mockResolvedValue(null);
      const service = buildService(stubs);

      await expect(service.deleteSet(USER, 'set-1')).resolves.toBeUndefined();

      stubs.findSetById.mockResolvedValue(setRow({ deletedAt: new Date() }));
      await expect(service.deleteSet(USER, 'set-1')).resolves.toBeUndefined();
      expect(stubs.softDeleteSet).not.toHaveBeenCalled();
    });

    it('la série d’un autre utilisateur reste invisible', async () => {
      const stubs = buildStubs();
      stubs.findSetById.mockResolvedValue(setRow({ session: sessionRow({ userId: OTHER_USER }) }));
      const service = buildService(stubs);

      await expect(service.deleteSet(USER, 'set-1')).rejects.toThrow(NotFoundException);
    });
  });

  describe('listSessions', () => {
    it('pagine par curseur avec volume total calculé', async () => {
      const stubs = buildStubs();
      stubs.listSessionsPage.mockResolvedValue([
        sessionRow({
          id: 'a',
          sets: [
            setRow({ reps: 10, weightKg: 60 }),
            setRow({ id: 'set-2', reps: 8, weightKg: 80 }),
            setRow({ id: 'set-3', reps: null, weightKg: null }),
          ] as never,
        }),
        sessionRow({ id: 'b' }),
        sessionRow({ id: 'c' }),
      ]);
      const service = buildService(stubs);

      const page = await service.listSessions(USER, 2);

      expect(page.items).toHaveLength(2);
      expect(page.hasMore).toBe(true);
      expect(page.nextCursor).toBe('b');
      expect(page.items[0]?.setsCount).toBe(3);
      expect(page.items[0]?.totalVolumeKg).toBe(10 * 60 + 8 * 80);
    });
  });
});
