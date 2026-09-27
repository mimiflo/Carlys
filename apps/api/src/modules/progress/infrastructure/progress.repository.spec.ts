import { type PrismaService } from '../../../database/prisma/prisma.service';
import { type RecordSet } from '../application/records.calculator';
import { ProgressRepository } from './progress.repository';

/**
 * Les franchissements de RECORD se synchronisent PAR DIFFÉRENCE : une
 * clôture de séance ne doit écrire que ce qui change. La version précédente
 * réinsérait tous les franchissements connus des exercices touchés (263
 * lignes, 1 841 paramètres pour un habitué) à chaque clôture.
 */
describe('ProgressRepository.syncRecordMilestones', () => {
  const USER = 'user-1';
  const cle = (valeur: number) => `record:Squat|MAX_WEIGHT|${valeur}`;
  const franchissement = (valeur: number) => ({
    key: cle(valeur),
    occurredAt: new Date(`2026-08-0${valeur % 9}T10:00:00Z`),
    payload: { exerciseName: 'Squat', recordType: 'MAX_WEIGHT', value: valeur },
  });

  function repository(connues: string[]) {
    const findMany = jest.fn().mockResolvedValue(connues.map((key) => ({ key })));
    const deleteMany = jest.fn().mockResolvedValue({ count: 0 });
    const createMany = jest.fn().mockResolvedValue({ count: 0 });
    const prisma = { progressMilestone: { findMany, deleteMany, createMany } };
    return {
      repo: new ProgressRepository(prisma as unknown as PrismaService),
      findMany,
      deleteMany,
      createMany,
    };
  }

  it('historique inchangé : une lecture, aucune écriture', async () => {
    const { repo, findMany, deleteMany, createMany } = repository([cle(1), cle(2)]);

    await repo.syncRecordMilestones(USER, ['Squat'], [franchissement(1), franchissement(2)]);

    expect(findMany).toHaveBeenCalledWith({
      where: {
        userId: USER,
        kind: 'RECORD',
        OR: [{ key: { startsWith: 'record:Squat|' } }],
      },
      select: { key: true },
    });
    expect(deleteMany).not.toHaveBeenCalled();
    expect(createMany).not.toHaveBeenCalled();
  });

  it('écrit SEULEMENT le nouveau, retire SEULEMENT le périmé', async () => {
    const { repo, deleteMany, createMany } = repository([cle(1), cle(2), cle(3)]);

    await repo.syncRecordMilestones(
      USER,
      ['Squat'],
      [franchissement(2), franchissement(3), franchissement(4)],
    );

    expect(deleteMany).toHaveBeenCalledWith({
      where: { userId: USER, kind: 'RECORD', key: { in: [cle(1)] } },
    });
    expect(createMany).toHaveBeenCalledWith({
      data: [
        {
          userId: USER,
          kind: 'RECORD',
          key: cle(4),
          occurredAt: franchissement(4).occurredAt,
          payload: franchissement(4).payload,
        },
      ],
      skipDuplicates: true,
    });
  });

  it('plus aucune série : tous les franchissements de l’exercice partent', async () => {
    const { repo, deleteMany, createMany } = repository([cle(1), cle(2)]);

    await repo.syncRecordMilestones(USER, ['Squat'], []);

    expect(deleteMany).toHaveBeenCalledWith({
      where: { userId: USER, kind: 'RECORD', key: { in: [cle(1), cle(2)] } },
    });
    expect(createMany).not.toHaveBeenCalled();
  });

  it('aucun exercice recalculé : rien n’est lu', async () => {
    const { repo, findMany } = repository([]);

    await repo.syncRecordMilestones(USER, [], [franchissement(1)]);

    expect(findMany).not.toHaveBeenCalled();
  });
});

/**
 * La relecture des séries à chaque clôture ne rapatrie QUE ce que les calculs
 * de record lisent ([RecordSet]). Sans `select`, les dix-huit colonnes de
 * chaque série de l'historique de l'exercice partaient, charges prévues, RPE
 * et horodatages compris. Le type seul ne le garde pas : un `findMany` sans
 * `select` rend un sur-ensemble, que TypeScript accepte sans broncher.
 */
describe('ProgressRepository.findSetsForRecords', () => {
  // `Record<keyof RecordSet, true>` : la compilation refuse une colonne en
  // trop comme une colonne oubliée, et le test suit le type s'il change.
  const COLONNES: Record<keyof RecordSet, true> = {
    sessionId: true,
    exerciseId: true,
    exerciseName: true,
    position: true,
    reps: true,
    weightKg: true,
    completedAt: true,
    deletedAt: true,
  };

  it('ne lit que les huit colonnes des calculs, des séances terminées de la personne', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const prisma = { workoutSet: { findMany } } as unknown as PrismaService;

    await new ProgressRepository(prisma).findSetsForRecords('user-1', ['Squat']);

    expect(findMany).toHaveBeenCalledWith({
      where: {
        exerciseName: { in: ['Squat'] },
        deletedAt: null,
        session: { userId: 'user-1', status: 'COMPLETED', deletedAt: null },
      },
      select: COLONNES,
    });
  });
});
