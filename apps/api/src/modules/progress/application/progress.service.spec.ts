import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { type WorkoutSet } from '@prisma/client';
import { type PinoLogger } from 'nestjs-pino';
import { type PrismaService } from '../../../database/prisma/prisma.service';
import { type ProgressRepository } from '../infrastructure/progress.repository';
import { ProgressService } from './progress.service';

const USER = 'user-1';
const OTHER_USER = 'user-2';

interface Stubs {
  periodTotals: jest.Mock;
  volumeBuckets: jest.Mock;
  userTimeZone: jest.Mock;
  exercisePoints: jest.Mock;
  listRecords: jest.Mock;
  findRecords: jest.Mock;
  upsertRecord: jest.Mock;
  createBodyMetric: jest.Mock;
  findBodyMetricById: jest.Mock;
  listBodyMetrics: jest.Mock;
  updateBodyMetric: jest.Mock;
  softDeleteBodyMetric: jest.Mock;
}

function buildStubs(): Stubs {
  return {
    periodTotals: jest.fn().mockResolvedValue({
      sessionsCount: 0,
      setsCount: 0,
      totalVolumeKg: 0,
      totalDurationSeconds: 0,
    }),
    volumeBuckets: jest.fn().mockResolvedValue([]),
    userTimeZone: jest.fn().mockResolvedValue('Europe/Paris'),
    exercisePoints: jest.fn().mockResolvedValue([]),
    listRecords: jest.fn().mockResolvedValue([]),
    findRecords: jest.fn().mockResolvedValue([]),
    upsertRecord: jest.fn().mockResolvedValue(undefined),
    createBodyMetric: jest.fn().mockResolvedValue(true),
    findBodyMetricById: jest.fn().mockResolvedValue(null),
    listBodyMetrics: jest.fn().mockResolvedValue([]),
    updateBodyMetric: jest.fn().mockResolvedValue(bodyMetricRow()),
    softDeleteBodyMetric: jest.fn().mockResolvedValue(undefined),
  };
}

const loggerStub = { error: jest.fn() };

function buildService(
  stubs: Stubs,
  prisma: unknown = { exercise: { findFirst: jest.fn().mockResolvedValue(null) } },
): ProgressService {
  return new ProgressService(
    stubs as unknown as ProgressRepository,
    prisma as PrismaService,
    loggerStub as unknown as PinoLogger,
  );
}

function workoutSet(overrides: Record<string, unknown> = {}): WorkoutSet {
  return {
    id: 'set-1',
    sessionId: 'session-1',
    exerciseId: 'exercise-1',
    exerciseName: 'Développé couché',
    position: 0,
    kind: 'NORMAL',
    reps: 10,
    weightKg: 60,
    durationSeconds: null,
    distanceMeters: null,
    rpe: null,
    restSeconds: null,
    completedAt: new Date('2026-08-07T10:05:00Z'),
    createdAt: new Date(),
    updatedAt: new Date(),
    deletedAt: null,
    ...overrides,
  } as unknown as WorkoutSet;
}

function storedRecord(overrides: Record<string, unknown> = {}): unknown {
  return {
    id: 'record-1',
    userId: USER,
    exerciseId: 'exercise-1',
    exerciseName: 'Développé couché',
    recordType: 'MAX_WEIGHT',
    value: 100,
    reps: 5,
    weightKg: 100,
    achievedAt: new Date('2026-08-01T10:00:00Z'),
    sessionId: 'session-0',
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  };
}

function bodyMetricRow(overrides: Record<string, unknown> = {}): unknown {
  return {
    id: 'metric-1',
    userId: USER,
    metricType: 'WEIGHT_KG',
    value: 82.5,
    measuredAt: new Date('2026-08-07T07:00:00Z'),
    createdAt: new Date(),
    updatedAt: new Date(),
    deletedAt: null,
    ...overrides,
  };
}

describe('ProgressService', () => {
  beforeEach(() => {
    loggerStub.error.mockClear();
  });

  describe('updateRecordsForSession', () => {
    it('crée un record quand aucun n’existe pour l’exercice', async () => {
      const stubs = buildStubs();
      const service = buildService(stubs);

      await service.updateRecordsForSession(USER, 'session-1', [workoutSet()]);

      // MAX_WEIGHT, MAX_REPS et MAX_SET_VOLUME sont tous nouveaux.
      expect(stubs.upsertRecord).toHaveBeenCalledTimes(3);
    });

    it('ne remplace un record que s’il est battu', async () => {
      const stubs = buildStubs();
      stubs.findRecords.mockResolvedValue([
        storedRecord({ recordType: 'MAX_WEIGHT', value: 100 }),
        storedRecord({ id: 'record-2', recordType: 'MAX_REPS', value: 8 }),
        storedRecord({ id: 'record-3', recordType: 'MAX_SET_VOLUME', value: 10_000 }),
      ]);
      const service = buildService(stubs);

      // 60 kg < 100 kg, 10 reps > 8 reps, 600 kg < 10 000 kg.
      await service.updateRecordsForSession(USER, 'session-1', [workoutSet()]);

      expect(stubs.upsertRecord).toHaveBeenCalledTimes(1);
      expect(stubs.upsertRecord).toHaveBeenCalledWith(
        USER,
        expect.objectContaining({ recordType: 'MAX_REPS', value: 10 }),
        'session-1',
      );
    });

    it('ne fait jamais échouer la clôture : les erreurs sont journalisées', async () => {
      const stubs = buildStubs();
      stubs.findRecords.mockRejectedValue(new Error('base indisponible'));
      const service = buildService(stubs);

      await expect(
        service.updateRecordsForSession(USER, 'session-1', [workoutSet()]),
      ).resolves.toBeUndefined();
      expect(loggerStub.error).toHaveBeenCalled();
    });

    it('ne consulte rien quand la séance n’a aucune série exploitable', async () => {
      const stubs = buildStubs();
      const service = buildService(stubs);

      await service.updateRecordsForSession(USER, 'session-1', []);

      expect(stubs.findRecords).not.toHaveBeenCalled();
      expect(stubs.upsertRecord).not.toHaveBeenCalled();
    });
  });

  describe('exerciseProgression', () => {
    it('un exercice inconnu ou non publié reste invisible (404)', async () => {
      const stubs = buildStubs();
      const service = buildService(stubs);

      await expect(
        service.exerciseProgression(USER, '00000000-0000-4000-8000-000000000000'),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('addBodyMetric (idempotent)', () => {
    const input = {
      id: 'metric-1',
      metricType: 'WEIGHT_KG' as const,
      value: 82.5,
      measuredAt: new Date('2026-08-07T07:00:00Z'),
    };

    it('rejouer la création renvoie la mesure existante sans doublon', async () => {
      const stubs = buildStubs();
      stubs.createBodyMetric.mockResolvedValue(false); // id déjà présent
      stubs.findBodyMetricById.mockResolvedValue(bodyMetricRow());
      const service = buildService(stubs);

      const metric = await service.addBodyMetric(USER, input);

      expect(metric.id).toBe('metric-1');
      expect(metric.value).toBe(82.5);
    });

    it('un id appartenant à un autre utilisateur est un conflit', async () => {
      const stubs = buildStubs();
      stubs.createBodyMetric.mockResolvedValue(false);
      stubs.findBodyMetricById.mockResolvedValue(bodyMetricRow({ userId: OTHER_USER }));
      const service = buildService(stubs);

      await expect(service.addBodyMetric(USER, input)).rejects.toThrow(ConflictException);
    });
  });

  describe('listBodyMetrics', () => {
    it('sert les mesures du plus ancien au plus récent', async () => {
      const stubs = buildStubs();
      stubs.listBodyMetrics.mockResolvedValue([
        bodyMetricRow({ id: 'b', measuredAt: new Date('2026-08-07T07:00:00Z') }),
        bodyMetricRow({ id: 'a', measuredAt: new Date('2026-08-01T07:00:00Z') }),
      ]);
      const service = buildService(stubs);

      const metrics = await service.listBodyMetrics(USER, 'WEIGHT_KG', 90);

      expect(metrics.map((metric) => metric.id)).toEqual(['a', 'b']);
    });
  });

  describe('updateBodyMetric', () => {
    it('corrige la valeur seule, sans toucher à la date', async () => {
      const stubs = buildStubs();
      stubs.findBodyMetricById.mockResolvedValue(bodyMetricRow());
      stubs.updateBodyMetric.mockResolvedValue(bodyMetricRow({ value: 81 }));
      const service = buildService(stubs);

      const metric = await service.updateBodyMetric(USER, 'metric-1', { value: 81 });

      expect(metric.value).toBe(81);
      // `measuredAt` absent de l'objet transmis : Prisma laisse la colonne
      // intacte. L'envoyer à `undefined` marcherait aussi, mais le vérifier
      // ici interdit qu'un futur remaniement passe `null` par mégarde.
      expect(stubs.updateBodyMetric).toHaveBeenCalledWith('metric-1', { value: 81 });
    });

    it('corrige la date seule — c’est elle qui décide quelle mesure fait foi', async () => {
      const stubs = buildStubs();
      stubs.findBodyMetricById.mockResolvedValue(bodyMetricRow());
      const veille = new Date('2026-08-06T07:00:00Z');
      stubs.updateBodyMetric.mockResolvedValue(bodyMetricRow({ measuredAt: veille }));
      const service = buildService(stubs);

      await service.updateBodyMetric(USER, 'metric-1', { measuredAt: veille });

      expect(stubs.updateBodyMetric).toHaveBeenCalledWith('metric-1', { measuredAt: veille });
    });

    it('un corps vide n’est pas une correction', async () => {
      const stubs = buildStubs();
      stubs.findBodyMetricById.mockResolvedValue(bodyMetricRow());
      const service = buildService(stubs);

      await expect(service.updateBodyMetric(USER, 'metric-1', {})).rejects.toThrow(
        BadRequestException,
      );
      expect(stubs.updateBodyMetric).not.toHaveBeenCalled();
    });

    it('corriger une mesure supprimée échoue — le client croirait sa correction prise', async () => {
      const stubs = buildStubs();
      stubs.findBodyMetricById.mockResolvedValue(bodyMetricRow({ deletedAt: new Date() }));
      const service = buildService(stubs);

      await expect(service.updateBodyMetric(USER, 'metric-1', { value: 80 })).rejects.toThrow(
        NotFoundException,
      );
      expect(stubs.updateBodyMetric).not.toHaveBeenCalled();
    });

    it('la mesure d’un autre utilisateur reste introuvable, jamais interdite', async () => {
      const stubs = buildStubs();
      stubs.findBodyMetricById.mockResolvedValue(bodyMetricRow({ userId: OTHER_USER }));
      const service = buildService(stubs);

      // NotFound et non Forbidden : un 403 confirmerait que cet identifiant
      // existe, et transformerait la route en oracle d'énumération.
      await expect(service.updateBodyMetric(USER, 'metric-1', { value: 80 })).rejects.toThrow(
        NotFoundException,
      );
      expect(stubs.updateBodyMetric).not.toHaveBeenCalled();
    });
  });

  describe('deleteBodyMetric (idempotent)', () => {
    it('supprimer une mesure inconnue ou déjà supprimée aboutit sans erreur', async () => {
      const stubs = buildStubs();
      const service = buildService(stubs);

      await expect(service.deleteBodyMetric(USER, 'metric-1')).resolves.toBeUndefined();

      stubs.findBodyMetricById.mockResolvedValue(bodyMetricRow({ deletedAt: new Date() }));
      await expect(service.deleteBodyMetric(USER, 'metric-1')).resolves.toBeUndefined();
      expect(stubs.softDeleteBodyMetric).not.toHaveBeenCalled();
    });

    it('la mesure d’un autre utilisateur reste invisible', async () => {
      const stubs = buildStubs();
      stubs.findBodyMetricById.mockResolvedValue(bodyMetricRow({ userId: OTHER_USER }));
      const service = buildService(stubs);

      await expect(service.deleteBodyMetric(USER, 'metric-1')).rejects.toThrow(NotFoundException);
    });
  });

  describe('overview — découpage des journées', () => {
    it('découpe dans le fuseau de la personne, pas en UTC', async () => {
      // Le serveur ne découpe jamais les journées à la place du client :
      // sans cela, une séance de 21 h à Montréal (01 h UTC le lendemain)
      // tombait dans le panier du jour suivant et s'affichait à la date de
      // la veille une fois ramenée à l'heure locale.
      const stubs = buildStubs();
      stubs.userTimeZone.mockResolvedValue('America/Montreal');
      const service = buildService(stubs);

      await service.overview(USER, 'week');

      expect(stubs.volumeBuckets).toHaveBeenCalledWith(
        USER,
        expect.any(Date),
        'week',
        'America/Montreal',
      );
    });

    it('fuseau absent ou fantaisiste : UTC, jamais une erreur', async () => {
      // La colonne a longtemps accepté n'importe quelle chaîne. Un découpage
      // UTC, visiblement décalé mais lisible, vaut mieux qu'un 500 sur une
      // page de statistiques.
      const stubs = buildStubs();
      stubs.userTimeZone.mockResolvedValue('Europe/Pariss');
      const service = buildService(stubs);

      await service.overview(USER, 'month');

      expect(stubs.volumeBuckets).toHaveBeenCalledWith(USER, expect.any(Date), 'month', 'UTC');
    });
  });
});
