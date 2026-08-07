import { ageYearsAt, computeMetabolism } from './metabolism.calculator';

describe('computeMetabolism', () => {
  it('homme 30 ans, 180 cm, 80 kg, activité modérée, maintien — valeurs de référence', () => {
    const result = computeMetabolism({
      sex: 'MALE',
      ageYears: 30,
      heightCm: 180,
      weightKg: 80,
      activityLevel: 'MODERATE',
      goal: 'MAINTAIN',
    });

    // BMR Mifflin-St Jeor : 10·80 + 6,25·180 − 5·30 + 5 = 1780.
    expect(result.bmrKcal).toBe(1780);
    // TDEE : 1780 × 1,55 = 2759.
    expect(result.tdeeKcal).toBe(2759);
    expect(result.targetKcal).toBe(2759);
    // Protéines maintien : 1,6 g/kg → 128 g.
    expect(result.proteinG).toBe(128);
    // Lipides : 25 % des calories / 9.
    expect(result.fatG).toBe(Math.round((2759 * 0.25) / 9));
    // IMC : 80 / 1,8² ≈ 24,7 → normal.
    expect(result.bmi).toBe(24.7);
    expect(result.bmiCategory).toBe('NORMAL');
    expect(result.waterMl).toBe(2800);
  });

  it('femme : constante Mifflin-St Jeor différente (−161)', () => {
    const result = computeMetabolism({
      sex: 'FEMALE',
      ageYears: 25,
      heightCm: 165,
      weightKg: 60,
      activityLevel: 'SEDENTARY',
      goal: 'MAINTAIN',
    });

    // 10·60 + 6,25·165 − 5·25 − 161 = 1345,25 → 1345.
    expect(result.bmrKcal).toBe(1345);
    expect(result.tdeeKcal).toBe(Math.round(1345.25 * 1.2));
  });

  it('perte de poids : déficit de 15 % et protéines renforcées', () => {
    const maintain = computeMetabolism({
      sex: 'MALE',
      ageYears: 40,
      heightCm: 175,
      weightKg: 90,
      activityLevel: 'LIGHT',
      goal: 'MAINTAIN',
    });
    const lose = computeMetabolism({
      sex: 'MALE',
      ageYears: 40,
      heightCm: 175,
      weightKg: 90,
      activityLevel: 'LIGHT',
      goal: 'LOSE_WEIGHT',
    });

    expect(lose.targetKcal).toBeLessThan(maintain.targetKcal);
    expect(lose.proteinG).toBe(180); // 2 g/kg
    expect(lose.bmiCategory).toBe('OVERWEIGHT'); // 90 / 1,75² ≈ 29,4
  });

  it('prise de muscle : surplus de 10 %', () => {
    const result = computeMetabolism({
      sex: 'FEMALE',
      ageYears: 22,
      heightCm: 170,
      weightKg: 55,
      activityLevel: 'VERY_ACTIVE',
      goal: 'GAIN_MUSCLE',
    });

    const bmr = 10 * 55 + 6.25 * 170 - 5 * 22 - 161;
    expect(result.targetKcal).toBe(Math.round(bmr * 1.9 * 1.1));
    expect(result.bmiCategory).toBe('NORMAL'); // 55 / 1,7² ≈ 19,0
  });

  it('les glucides ne deviennent jamais négatifs', () => {
    const result = computeMetabolism({
      sex: 'FEMALE',
      ageYears: 70,
      heightCm: 150,
      weightKg: 40,
      activityLevel: 'SEDENTARY',
      goal: 'LOSE_WEIGHT',
    });

    expect(result.carbsG).toBeGreaterThanOrEqual(0);
  });
});

describe('ageYearsAt', () => {
  it('âge révolu : avant et après l’anniversaire', () => {
    const birth = new Date('1996-08-15T00:00:00Z');
    expect(ageYearsAt(birth, new Date('2026-08-07T12:00:00Z'))).toBe(29);
    expect(ageYearsAt(birth, new Date('2026-08-15T00:00:00Z'))).toBe(30);
    expect(ageYearsAt(birth, new Date('2026-12-01T00:00:00Z'))).toBe(30);
  });
});
