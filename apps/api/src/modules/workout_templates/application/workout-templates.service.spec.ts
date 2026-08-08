import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { WorkoutSetKind } from '@prisma/client';
import {
  type TemplateWithContent,
  type WorkoutTemplatesRepository,
} from '../infrastructure/workout-templates.repository';
import { type SaveTemplateInput, WorkoutTemplatesService } from './workout-templates.service';

const USER = 'user-1';
const OTHER_USER = 'user-2';
const TEMPLATE = 'modele-1';

function templateRow(overrides: Partial<TemplateWithContent> = {}): TemplateWithContent {
  return {
    id: TEMPLATE,
    userId: USER,
    name: 'Push — Force',
    notes: null,
    estimatedDurationMinutes: null,
    lastUsedAt: null,
    createdAt: new Date('2026-08-01T09:00:00Z'),
    updatedAt: new Date('2026-08-06T09:10:00Z'),
    deletedAt: null,
    exercises: [],
    ...overrides,
  };
}

interface Stubs {
  findTemplateById: jest.Mock;
  listTemplatesPage: jest.Mock;
  replaceTemplate: jest.Mock;
  softDeleteTemplate: jest.Mock;
  publishedExerciseNames: jest.Mock;
  findLaunchableTemplate: jest.Mock;
}

function buildStubs(): Stubs {
  return {
    findTemplateById: jest.fn().mockResolvedValue(null),
    listTemplatesPage: jest.fn().mockResolvedValue([]),
    replaceTemplate: jest.fn().mockResolvedValue(undefined),
    softDeleteTemplate: jest.fn().mockResolvedValue(undefined),
    publishedExerciseNames: jest.fn().mockResolvedValue(new Map()),
    findLaunchableTemplate: jest.fn().mockResolvedValue(null),
  };
}

function buildService(stubs: Stubs): WorkoutTemplatesService {
  const logger = { info: jest.fn(), warn: jest.fn(), error: jest.fn() };
  return new WorkoutTemplatesService(
    stubs as unknown as WorkoutTemplatesRepository,
    logger as never,
  );
}

const saveInput: SaveTemplateInput = {
  name: 'Push — Force',
  exercises: [
    {
      id: 'ligne-1',
      exerciseId: 'exercice-1',
      sets: [
        { id: 'serie-1', kind: WorkoutSetKind.WARMUP, targetReps: 12, targetWeightKg: 40 },
        { id: 'serie-2', targetReps: 8, targetWeightKg: 70, restSeconds: 120 },
      ],
    },
  ],
};

describe('WorkoutTemplatesService', () => {
  describe('saveTemplate — résolution du nom d’exercice', () => {
    it('le catalogue gagne sur le nom fourni par le client', async () => {
      const stubs = buildStubs();
      stubs.publishedExerciseNames.mockResolvedValue(new Map([['exercice-1', 'Développé couché']]));
      stubs.findTemplateById.mockResolvedValueOnce(null).mockResolvedValue(templateRow());
      const service = buildService(stubs);

      await service.saveTemplate(USER, TEMPLATE, {
        ...saveInput,
        exercises: [{ ...saveInput.exercises[0]!, exerciseName: 'Nom obsolète du client' }],
      });

      expect(stubs.replaceTemplate).toHaveBeenCalledWith(
        expect.objectContaining({
          exercises: [
            expect.objectContaining({ exerciseId: 'exercice-1', exerciseName: 'Développé couché' }),
          ],
        }),
      );
    });

    it('un exerciseId non résolu retombe sur un exercice libre (clé étrangère sûre)', async () => {
      const stubs = buildStubs();
      stubs.findTemplateById.mockResolvedValueOnce(null).mockResolvedValue(templateRow());
      const service = buildService(stubs);

      await service.saveTemplate(USER, TEMPLATE, {
        ...saveInput,
        exercises: [{ ...saveInput.exercises[0]!, exerciseName: '  Tirage libre  ' }],
      });

      expect(stubs.replaceTemplate).toHaveBeenCalledWith(
        expect.objectContaining({
          exercises: [expect.objectContaining({ exerciseId: null, exerciseName: 'Tirage libre' })],
        }),
      );
    });

    it('exerciseId inconnu ET exerciseName absent est un refus de validation', async () => {
      const stubs = buildStubs();
      const service = buildService(stubs);

      await expect(service.saveTemplate(USER, TEMPLATE, saveInput)).rejects.toThrow(
        BadRequestException,
      );
      expect(stubs.replaceTemplate).not.toHaveBeenCalled();
    });
  });

  describe('saveTemplate — positions dérivées de l’ordre', () => {
    it('numérote lignes et séries à partir de 0, sans jamais lire le corps', async () => {
      const stubs = buildStubs();
      stubs.findTemplateById.mockResolvedValueOnce(null).mockResolvedValue(templateRow());
      const service = buildService(stubs);

      await service.saveTemplate(USER, TEMPLATE, {
        name: 'Full body',
        exercises: [
          { id: 'ligne-1', exerciseName: 'Squat', sets: [{ id: 's1' }, { id: 's2' }] },
          { id: 'ligne-2', exerciseName: 'Tractions', sets: [{ id: 's3' }] },
        ],
      });

      const [call] = stubs.replaceTemplate.mock.calls[0] as [
        { exercises: { position: number }[]; sets: { position: number; kind: string }[] },
      ];
      expect(call.exercises.map((row) => row.position)).toEqual([0, 1]);
      expect(call.sets.map((row) => row.position)).toEqual([0, 1, 0]);
      // Sans `kind` explicite, une série prévue est une série normale.
      expect(call.sets.every((row) => row.kind === WorkoutSetKind.NORMAL)).toBe(true);
    });

    it('refuse un identifiant dupliqué : l’écriture ne serait plus rejouable', async () => {
      const stubs = buildStubs();
      const service = buildService(stubs);

      await expect(
        service.saveTemplate(USER, TEMPLATE, {
          name: 'Doublon',
          exercises: [
            { id: 'ligne-1', exerciseName: 'Squat', sets: [{ id: 'serie-1' }, { id: 'serie-1' }] },
          ],
        }),
      ).rejects.toThrow(BadRequestException);
      expect(stubs.replaceTemplate).not.toHaveBeenCalled();
    });

    it('refuse un nom vide une fois trimé', async () => {
      const stubs = buildStubs();
      const service = buildService(stubs);

      await expect(
        service.saveTemplate(USER, TEMPLATE, { ...saveInput, name: '   ' }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('saveTemplate — 404 supprimé vs 409 autrui', () => {
    it('un PUT ne ressuscite pas un modèle supprimé (404)', async () => {
      const stubs = buildStubs();
      stubs.findTemplateById.mockResolvedValue(templateRow({ deletedAt: new Date() }));
      const service = buildService(stubs);

      await expect(service.saveTemplate(USER, TEMPLATE, saveInput)).rejects.toThrow(
        NotFoundException,
      );
      expect(stubs.replaceTemplate).not.toHaveBeenCalled();
    });

    it('un id déjà pris par un autre utilisateur est un conflit (409)', async () => {
      const stubs = buildStubs();
      stubs.findTemplateById.mockResolvedValue(templateRow({ userId: OTHER_USER }));
      const service = buildService(stubs);

      await expect(service.saveTemplate(USER, TEMPLATE, saveInput)).rejects.toThrow(
        ConflictException,
      );
      expect(stubs.replaceTemplate).not.toHaveBeenCalled();
    });

    it('annonce 201 à la création et 200 au remplacement', async () => {
      const stubs = buildStubs();
      stubs.publishedExerciseNames.mockResolvedValue(new Map([['exercice-1', 'Développé couché']]));
      stubs.findTemplateById.mockResolvedValueOnce(null).mockResolvedValue(templateRow());
      const service = buildService(stubs);

      const created = await service.saveTemplate(USER, TEMPLATE, saveInput);
      expect(created.created).toBe(true);

      stubs.findTemplateById.mockResolvedValue(templateRow());
      const replaced = await service.saveTemplate(USER, TEMPLATE, saveInput);
      expect(replaced.created).toBe(false);
    });
  });

  describe('templateDetail', () => {
    it('inconnu, supprimé ou à autrui : 404 dans les trois cas', async () => {
      const stubs = buildStubs();
      const service = buildService(stubs);

      stubs.findTemplateById.mockResolvedValue(null);
      await expect(service.templateDetail(USER, TEMPLATE)).rejects.toThrow(NotFoundException);

      stubs.findTemplateById.mockResolvedValue(templateRow({ deletedAt: new Date() }));
      await expect(service.templateDetail(USER, TEMPLATE)).rejects.toThrow(NotFoundException);

      stubs.findTemplateById.mockResolvedValue(templateRow({ userId: OTHER_USER }));
      await expect(service.templateDetail(USER, TEMPLATE)).rejects.toThrow(NotFoundException);
    });
  });

  describe('deleteTemplate (rejouable)', () => {
    it('supprimer un modèle inconnu ou déjà supprimé aboutit sans erreur', async () => {
      const stubs = buildStubs();
      const service = buildService(stubs);

      stubs.findTemplateById.mockResolvedValue(null);
      await expect(service.deleteTemplate(USER, TEMPLATE)).resolves.toBeUndefined();

      stubs.findTemplateById.mockResolvedValue(templateRow({ deletedAt: new Date() }));
      await expect(service.deleteTemplate(USER, TEMPLATE)).resolves.toBeUndefined();
      expect(stubs.softDeleteTemplate).not.toHaveBeenCalled();
    });

    it('le modèle d’un autre utilisateur reste invisible', async () => {
      const stubs = buildStubs();
      stubs.findTemplateById.mockResolvedValue(templateRow({ userId: OTHER_USER }));
      const service = buildService(stubs);

      await expect(service.deleteTemplate(USER, TEMPLATE)).rejects.toThrow(NotFoundException);
      expect(stubs.softDeleteTemplate).not.toHaveBeenCalled();
    });
  });

  describe('listTemplates', () => {
    it('pagine par curseur et compte les séries prévues sans les charger', async () => {
      const stubs = buildStubs();
      const withCounts = (id: string, sets: number[]) => ({
        ...templateRow({ id }),
        exercises: sets.map((count, index) => ({
          exerciseName: `Exercice ${index}`,
          _count: { sets: count },
        })),
      });
      stubs.listTemplatesPage.mockResolvedValue([
        withCounts('a', [3, 4, 4, 3]),
        withCounts('b', []),
        withCounts('c', []),
      ]);
      const service = buildService(stubs);

      const page = await service.listTemplates(USER, 2);

      expect(page.items).toHaveLength(2);
      expect(page.hasMore).toBe(true);
      expect(page.nextCursor).toBe('b');
      expect(page.items[0]?.exercisesCount).toBe(4);
      expect(page.items[0]?.plannedSetsCount).toBe(14);
      // L'aperçu de la carte se limite aux trois premiers exercices.
      expect(page.items[0]?.previewExerciseNames).toHaveLength(3);
    });
  });

  describe('resolveSessionOrigin (n’échoue jamais)', () => {
    it('un modèle lançable donne son id et son nom SERVEUR', async () => {
      const stubs = buildStubs();
      stubs.findLaunchableTemplate.mockResolvedValue({ id: TEMPLATE, name: 'Push — Force' });
      const service = buildService(stubs);

      await expect(
        service.resolveSessionOrigin(USER, { templateId: TEMPLATE, templateName: 'Périmé' }),
      ).resolves.toEqual({ templateId: TEMPLATE, templateName: 'Push — Force' });
    });

    it('un modèle inconnu conserve le nom du client sans jamais lever', async () => {
      const stubs = buildStubs();
      const service = buildService(stubs);

      await expect(
        service.resolveSessionOrigin(USER, {
          templateId: 'inconnu',
          templateName: '  Push — Force  ',
        }),
      ).resolves.toEqual({ templateId: null, templateName: 'Push — Force' });
    });

    it('sans modèle ni nom, la séance reste une séance libre', async () => {
      const stubs = buildStubs();
      const service = buildService(stubs);

      await expect(service.resolveSessionOrigin(USER, {})).resolves.toEqual({
        templateId: null,
        templateName: null,
      });
      expect(stubs.findLaunchableTemplate).not.toHaveBeenCalled();
    });
  });
});
