import {
  type ActivityLevel,
  type BiologicalSex,
  type BmiCategory,
  type MetabolismResult,
  type NutritionGoal,
} from '@carlys/api-contracts';

export interface MetabolismInput {
  sex: BiologicalSex;
  ageYears: number;
  heightCm: number;
  weightKg: number;
  activityLevel: ActivityLevel;
  goal: NutritionGoal;
}

/** Multiplicateurs d'activité (facteurs de Harris/McArdle usuels). */
const ACTIVITY_FACTORS: Record<ActivityLevel, number> = {
  SEDENTARY: 1.2,
  LIGHT: 1.375,
  MODERATE: 1.55,
  ACTIVE: 1.725,
  VERY_ACTIVE: 1.9,
};

/** Ajustement calorique par objectif (déficit/surplus raisonnables). */
const GOAL_FACTORS: Record<NutritionGoal, number> = {
  LOSE_WEIGHT: 0.85,
  MAINTAIN: 1,
  GAIN_MUSCLE: 1.1,
};

/** Protéines (g/kg de poids corporel) par objectif. */
const PROTEIN_PER_KG: Record<NutritionGoal, number> = {
  LOSE_WEIGHT: 2.0,
  MAINTAIN: 1.6,
  GAIN_MUSCLE: 1.8,
};

/** Part des lipides dans l'apport calorique cible. */
const FAT_RATIO = 0.25;

function bmiCategoryOf(bmi: number): BmiCategory {
  if (bmi < 18.5) return 'UNDERWEIGHT';
  if (bmi < 25) return 'NORMAL';
  if (bmi < 30) return 'OVERWEIGHT';
  return 'OBESE';
}

/**
 * Calculs métaboliques de référence — fonction PURE, testée unitairement.
 *
 *  - BMR : Mifflin-St Jeor (10·poids + 6,25·taille − 5·âge ± constante) ;
 *  - TDEE : BMR × facteur d'activité ;
 *  - objectif calorique : TDEE ajusté au but visé ;
 *  - macros : protéines en g/kg, lipides en % des calories, glucides en solde ;
 *  - hydratation : 35 ml/kg.
 */
export function computeMetabolism(input: MetabolismInput): MetabolismResult {
  const { sex, ageYears, heightCm, weightKg, activityLevel, goal } = input;

  const bmr = 10 * weightKg + 6.25 * heightCm - 5 * ageYears + (sex === 'MALE' ? 5 : -161);
  const tdee = bmr * ACTIVITY_FACTORS[activityLevel];
  const target = tdee * GOAL_FACTORS[goal];

  const proteinG = PROTEIN_PER_KG[goal] * weightKg;
  const fatG = (target * FAT_RATIO) / 9;
  const carbsG = Math.max(0, (target - proteinG * 4 - fatG * 9) / 4);

  const heightM = heightCm / 100;
  const bmi = weightKg / (heightM * heightM);

  return {
    bmi: Math.round(bmi * 10) / 10,
    bmiCategory: bmiCategoryOf(bmi),
    bmrKcal: Math.round(bmr),
    tdeeKcal: Math.round(tdee),
    targetKcal: Math.round(target),
    proteinG: Math.round(proteinG),
    fatG: Math.round(fatG),
    carbsG: Math.round(carbsG),
    waterMl: Math.round(35 * weightKg),
  };
}

/** Âge révolu à la date donnée (calcul en UTC). */
export function ageYearsAt(birthDate: Date, now: Date): number {
  let age = now.getUTCFullYear() - birthDate.getUTCFullYear();
  const beforeBirthday =
    now.getUTCMonth() < birthDate.getUTCMonth() ||
    (now.getUTCMonth() === birthDate.getUTCMonth() && now.getUTCDate() < birthDate.getUTCDate());
  if (beforeBirthday) {
    age -= 1;
  }
  return age;
}
