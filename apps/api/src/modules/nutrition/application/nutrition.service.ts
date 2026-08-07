import {
  type MetabolicProfile,
  type MetabolismMissingField,
  type MetabolismReport,
} from '@carlys/api-contracts';
import { Injectable, NotFoundException } from '@nestjs/common';
import { type UserProfile } from '@prisma/client';
import { NutritionRepository } from '../infrastructure/nutrition.repository';
import { ageYearsAt, computeMetabolism } from './metabolism.calculator';

function presentProfile(
  profile: UserProfile,
  weightKg: number | null,
  now: Date,
): MetabolicProfile {
  return {
    sex: profile.sex,
    birthDate: profile.birthDate?.toISOString() ?? null,
    ageYears: profile.birthDate === null ? null : ageYearsAt(profile.birthDate, now),
    heightCm: profile.heightCm === null ? null : Number(profile.heightCm),
    weightKg,
    activityLevel: profile.activityLevel,
    goal: profile.nutritionGoal,
  };
}

/**
 * Rapport métabolique — TOUJOURS calculé côté serveur. Le poids provient de
 * la dernière mesure corporelle : la nutrition suit la progression réelle.
 */
@Injectable()
export class NutritionService {
  constructor(private readonly nutrition: NutritionRepository) {}

  async metabolismReport(userId: string): Promise<MetabolismReport> {
    const [profile, weightKg] = await Promise.all([
      this.nutrition.findProfile(userId),
      this.nutrition.latestWeightKg(userId),
    ]);
    if (profile === null) {
      throw new NotFoundException('Profil introuvable.');
    }

    const now = new Date();
    const presented = presentProfile(profile, weightKg, now);

    const missing: MetabolismMissingField[] = [];
    if (presented.sex === null) missing.push('sex');
    if (presented.birthDate === null) missing.push('birthDate');
    if (presented.heightCm === null) missing.push('heightCm');
    if (presented.activityLevel === null) missing.push('activityLevel');
    if (presented.weightKg === null) missing.push('weightKg');

    if (missing.length > 0) {
      return { profile: presented, missing, metabolism: null };
    }

    return {
      profile: presented,
      missing: [],
      metabolism: computeMetabolism({
        sex: presented.sex!,
        ageYears: presented.ageYears!,
        heightCm: presented.heightCm!,
        weightKg: presented.weightKg!,
        activityLevel: presented.activityLevel!,
        // Sans objectif déclaré : maintien (choix neutre, jamais bloquant).
        goal: presented.goal ?? 'MAINTAIN',
      }),
    };
  }
}
