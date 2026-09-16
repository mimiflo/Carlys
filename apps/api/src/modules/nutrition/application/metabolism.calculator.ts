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

/**
 * Plancher de l'objectif calorique, en kcal/jour, par sexe biologique.
 *
 * POURQUOI IL EXISTE. `tdee × 0,85` n'a pas de fond. Pour une personne
 * petite, âgée et sédentaire visant la perte de gras, la cible descendait
 * sous 900 kcal sans qu'aucune garde ni aucun mot n'apparaisse — le seul
 * `Math.max` du fichier bornait les glucides à 0, ce qui protégeait la
 * cohérence des macros, jamais la personne. Une fixture du dépôt le montrait
 * déjà : femme de 70 ans, 150 cm, 40 kg, sédentaire, perte de gras → 843.
 *
 * 1200 (femmes) et 1500 (hommes) sont les seuils bas usuels d'un régime non
 * supervisé médicalement. Ce sont des planchers, pas des recommandations :
 * descendre dessous peut se justifier, mais pas SANS un professionnel, et
 * sûrement pas parce qu'une multiplication est tombée là.
 *
 * Le plancher s'applique AVANT les macros, sinon les lipides et les glucides
 * se calculeraient sur une cible que l'écran n'affiche pas.
 */
const TARGET_KCAL_FLOOR: Record<BiologicalSex, number> = {
  FEMALE: 1200,
  MALE: 1500,
};

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
 *  - objectif calorique : TDEE ajusté au but visé, puis RELEVÉ au plancher ;
 *  - macros : protéines en g/kg, lipides en % des calories, glucides en solde ;
 *  - hydratation : 35 ml/kg.
 */
export function computeMetabolism(input: MetabolismInput): MetabolismResult {
  const { sex, ageYears, heightCm, weightKg, activityLevel, goal } = input;

  const bmr = 10 * weightKg + 6.25 * heightCm - 5 * ageYears + (sex === 'MALE' ? 5 : -161);
  const tdee = bmr * ACTIVITY_FACTORS[activityLevel];
  const ajuste = tdee * GOAL_FACTORS[goal];
  const floor = TARGET_KCAL_FLOOR[sex];
  const target = Math.max(floor, ajuste);
  // Arrondi des DEUX côtés : la cible servie est arrondie, donc une cible de
  // 1199,6 devient 1200 et n'est pas « relevée » du point de vue de qui lit
  // l'écran. Comparer l'avant-arrondi afficherait un avertissement pour une
  // différence invisible.
  const targetKcalFloored = Math.round(ajuste) < Math.round(floor);

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
    targetKcalFloored,
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
