import { NotFoundException } from '@nestjs/common';
import { type NutritionRepository } from '../infrastructure/nutrition.repository';
import { NutritionService } from './nutrition.service';

const USER = 'user-1';

interface Stubs {
  findProfile: jest.Mock;
  latestWeightKg: jest.Mock;
}

function profileRow(overrides: Record<string, unknown> = {}): unknown {
  return {
    userId: USER,
    displayName: 'Camille',
    locale: 'fr',
    timezone: 'Europe/Paris',
    createdAt: new Date(),
    updatedAt: new Date(),
    sex: 'FEMALE',
    birthDate: new Date('1996-05-01T00:00:00Z'),
    heightCm: 168,
    activityLevel: 'MODERATE',
    nutritionGoal: 'MAINTAIN',
    ...overrides,
  };
}

function buildStubs(): Stubs {
  return {
    findProfile: jest.fn().mockResolvedValue(profileRow()),
    latestWeightKg: jest.fn().mockResolvedValue(62),
  };
}

function buildService(stubs: Stubs): NutritionService {
  return new NutritionService(stubs as unknown as NutritionRepository);
}

describe('NutritionService', () => {
  it('profil complet : rapport calculé, aucun champ manquant', async () => {
    const service = buildService(buildStubs());

    const report = await service.metabolismReport(USER);

    expect(report.missing).toEqual([]);
    expect(report.metabolism).not.toBeNull();
    expect(report.metabolism!.bmrKcal).toBeGreaterThan(1000);
    expect(report.profile.weightKg).toBe(62);
    expect(report.profile.ageYears).toBeGreaterThanOrEqual(29);
  });

  it('champs manquants LISTÉS, jamais de calcul partiel', async () => {
    const stubs = buildStubs();
    stubs.findProfile.mockResolvedValue(profileRow({ sex: null, heightCm: null }));
    stubs.latestWeightKg.mockResolvedValue(null);
    const service = buildService(stubs);

    const report = await service.metabolismReport(USER);

    expect(report.metabolism).toBeNull();
    expect(report.missing).toEqual(expect.arrayContaining(['sex', 'heightCm', 'weightKg']));
    expect(report.missing).not.toContain('birthDate');
  });

  it('sans objectif déclaré : maintien appliqué (jamais bloquant)', async () => {
    const stubs = buildStubs();
    stubs.findProfile.mockResolvedValue(profileRow({ nutritionGoal: null }));
    const service = buildService(stubs);

    const report = await service.metabolismReport(USER);

    expect(report.missing).toEqual([]);
    expect(report.metabolism!.targetKcal).toBe(report.metabolism!.tdeeKcal);
  });

  it('profil introuvable → 404', async () => {
    const stubs = buildStubs();
    stubs.findProfile.mockResolvedValue(null);
    const service = buildService(stubs);

    await expect(service.metabolismReport(USER)).rejects.toThrow(NotFoundException);
  });
});
