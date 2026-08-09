import { PROGRAM_FREE_LIMIT } from '@carlys/api-contracts';
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { type EntitlementsService } from '../../subscriptions/application/entitlements.service';
import {
  type ProgramsRepository,
  type ProgramWithDays,
} from '../infrastructure/programs.repository';
import { ProgramsService } from './programs.service';

const USER = 'user-1';
const OTHER = 'user-2';
const ID = '11111111-1111-4111-8111-111111111111';

function program(overrides: Partial<ProgramWithDays> = {}): ProgramWithDays {
  return {
    id: ID,
    userId: USER,
    name: 'Prise de masse',
    description: null,
    weeksCount: 4,
    isActive: false,
    createdAt: new Date('2026-01-01'),
    updatedAt: new Date('2026-01-01'),
    deletedAt: null,
    days: [],
    ...overrides,
  };
}

interface Stubs {
  repository: {
    listPage: jest.Mock;
    findById: jest.Mock;
    countLive: jest.Mock;
    ownedTemplateIds: jest.Mock;
    save: jest.Mock;
    softDelete: jest.Mock;
  };
  entitlements: { hasEntitlement: jest.Mock };
}

function buildStubs(): Stubs {
  return {
    repository: {
      listPage: jest.fn().mockResolvedValue([]),
      findById: jest.fn().mockResolvedValue(null),
      countLive: jest.fn().mockResolvedValue(0),
      ownedTemplateIds: jest.fn().mockResolvedValue(new Set<string>()),
      save: jest.fn().mockImplementation((row: ProgramWithDays) => Promise.resolve(program(row))),
      softDelete: jest.fn().mockResolvedValue(true),
    },
    entitlements: { hasEntitlement: jest.fn().mockResolvedValue(false) },
  };
}

function buildService(stubs: Stubs): ProgramsService {
  return new ProgramsService(
    stubs.repository as unknown as ProgramsRepository,
    stubs.entitlements as unknown as EntitlementsService,
  );
}

const baseInput = {
  name: 'Prise de masse',
  weeksCount: 4,
  days: [{ id: 'd-1', weekNumber: 1, dayOfWeek: 1 }],
};

describe('ProgramsService', () => {
  it('création : 201 et jours écrits', async () => {
    const stubs = buildStubs();

    const saved = await buildService(stubs).save(ID, USER, baseInput);

    expect(saved.created).toBe(true);
    const [, days] = stubs.repository.save.mock.calls[0] as [unknown, unknown[]];
    expect(days).toHaveLength(1);
  });

  it('remplacement : 200, et le plafond ne s’applique PAS', async () => {
    const stubs = buildStubs();
    stubs.repository.findById.mockResolvedValue(program());
    stubs.repository.countLive.mockResolvedValue(99);

    const saved = await buildService(stubs).save(ID, USER, baseInput);

    expect(saved.created).toBe(false);
    // Un compte redevenu gratuit garde ses programmes : il ne peut plus en
    // AJOUTER, il n'est pas empêché de modifier ceux qu'il a.
    expect(stubs.repository.countLive).not.toHaveBeenCalled();
  });

  it('plafond gratuit atteint : création refusée (décision serveur)', async () => {
    const stubs = buildStubs();
    stubs.repository.countLive.mockResolvedValue(PROGRAM_FREE_LIMIT);

    await expect(buildService(stubs).save(ID, USER, baseInput)).rejects.toThrow(ForbiddenException);
    expect(stubs.repository.save).not.toHaveBeenCalled();
  });

  it('avec l’entitlement, aucun plafond', async () => {
    const stubs = buildStubs();
    stubs.repository.countLive.mockResolvedValue(50);
    stubs.entitlements.hasEntitlement.mockResolvedValue(true);

    await buildService(stubs).save(ID, USER, baseInput);

    expect(stubs.entitlements.hasEntitlement).toHaveBeenCalledWith(USER, 'unlimited_programs');
    expect(stubs.repository.save).toHaveBeenCalled();
  });

  it('identifiant pris par un autre compte → 409', async () => {
    const stubs = buildStubs();
    stubs.repository.findById.mockResolvedValue(program({ userId: OTHER }));

    await expect(buildService(stubs).save(ID, USER, baseInput)).rejects.toThrow(ConflictException);
  });

  it('programme supprimé : non ressuscitable', async () => {
    const stubs = buildStubs();
    stubs.repository.findById.mockResolvedValue(program({ deletedAt: new Date() }));

    await expect(buildService(stubs).save(ID, USER, baseInput)).rejects.toThrow(NotFoundException);
  });

  it('semaine hors du programme → 400', async () => {
    const stubs = buildStubs();

    await expect(
      buildService(stubs).save(ID, USER, {
        ...baseInput,
        weeksCount: 2,
        days: [{ id: 'd-1', weekNumber: 3, dayOfWeek: 1 }],
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('deux entrées sur la même case → 400 lisible, pas un 500 de PostgreSQL', async () => {
    const stubs = buildStubs();

    await expect(
      buildService(stubs).save(ID, USER, {
        ...baseInput,
        days: [
          { id: 'd-1', weekNumber: 1, dayOfWeek: 3 },
          { id: 'd-2', weekNumber: 1, dayOfWeek: 3 },
        ],
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('modèle d’autrui : le lien tombe, le plan reste lisible', async () => {
    const stubs = buildStubs();
    // `ownedTemplateIds` ne rend rien : le modèle n'est pas à ce compte.
    await buildService(stubs).save(ID, USER, {
      ...baseInput,
      days: [
        {
          id: 'd-1',
          weekNumber: 1,
          dayOfWeek: 1,
          templateId: '22222222-2222-4222-8222-222222222222',
          label: 'Push A',
        },
      ],
    });

    const [, days] = stubs.repository.save.mock.calls[0] as [
      unknown,
      { templateId: string | null; label: string }[],
    ];
    expect(days[0]?.templateId).toBeNull();
    expect(days[0]?.label).toBe('Push A');
  });

  it('jour de repos : aucun modèle, intitulé par défaut', async () => {
    const stubs = buildStubs();
    stubs.repository.ownedTemplateIds.mockResolvedValue(new Set(['t-1']));

    await buildService(stubs).save(ID, USER, {
      ...baseInput,
      days: [{ id: 'd-1', weekNumber: 1, dayOfWeek: 7, templateId: 't-1', isRest: true }],
    });

    const [, days] = stubs.repository.save.mock.calls[0] as [
      unknown,
      { templateId: string | null; label: string }[],
    ];
    expect(days[0]?.templateId).toBeNull();
    expect(days[0]?.label).toBe('Repos');
  });

  it('activer un programme le signale au dépôt (un seul actif)', async () => {
    const stubs = buildStubs();

    await buildService(stubs).save(ID, USER, { ...baseInput, isActive: true });

    const call = stubs.repository.save.mock.calls[0] as [unknown, unknown, boolean];
    expect(call[2]).toBe(true);
  });

  it('détail : inconnu, supprimé ou à autrui → 404 dans les trois cas', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    await expect(service.detail(ID, USER)).rejects.toThrow(NotFoundException);

    stubs.repository.findById.mockResolvedValue(program({ deletedAt: new Date() }));
    await expect(service.detail(ID, USER)).rejects.toThrow(NotFoundException);

    // Répondre 403 ici révélerait que le programme d'un autre existe.
    stubs.repository.findById.mockResolvedValue(program({ userId: OTHER }));
    await expect(service.detail(ID, USER)).rejects.toThrow(NotFoundException);
  });

  it('suppression rejouable : un programme inconnu ne fait pas échouer', async () => {
    const stubs = buildStubs();

    await expect(buildService(stubs).remove(ID, USER)).resolves.toBeUndefined();
  });

  it('suppression du programme d’autrui → 404', async () => {
    const stubs = buildStubs();
    stubs.repository.findById.mockResolvedValue(program({ userId: OTHER }));

    await expect(buildService(stubs).remove(ID, USER)).rejects.toThrow(NotFoundException);
    expect(stubs.repository.softDelete).not.toHaveBeenCalled();
  });

  it('pagination : limit+1 lignes → hasMore et curseur sur le dernier servi', async () => {
    const stubs = buildStubs();
    stubs.repository.listPage.mockResolvedValue([
      program({ id: 'p-1' }),
      program({ id: 'p-2' }),
      program({ id: 'p-3' }),
    ]);

    const page = await buildService(stubs).list(USER, 2);

    expect(page.items).toHaveLength(2);
    expect(page.hasMore).toBe(true);
    expect(page.nextCursor).toBe('p-2');
  });
});
