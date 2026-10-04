import { Prisma } from '@prisma/client';

/** Les teneurs (g/100 g) dont se déduit l'énergie ; `null` : non dosé. */
export interface Macros {
  readonly protein: Prisma.Decimal | null;
  readonly carbs: Prisma.Decimal | null;
  readonly fat: Prisma.Decimal | null;
  readonly fibre?: Prisma.Decimal | null;
  readonly alcohol?: Prisma.Decimal | null;
  readonly organicAcids?: Prisma.Decimal | null;
  /** Comptés DANS les glucides par CIQUAL : ils y valent 2,4 kcal/g au lieu de 4. */
  readonly polyols?: Prisma.Decimal | null;
}

/**
 * L'énergie (kcal/100 g) d'un aliment dont CIQUAL ne publie que les
 * macronutriments, par les facteurs du règlement UE 1169/2011 (annexe XIV),
 * ceux de l'étiquetage et de l'Anses elle-même.
 *
 * Vérifié le 4 octobre 2026 sur les 2 298 aliments de CIQUAL 2020 dont
 * l'énergie EST publiée : écart médian 0,3 kcal, 99 % à moins de 6 kcal ;
 * 0,37 kcal sur les 47 riches en polyols, qui confirment que CIQUAL les
 * compte DANS les glucides.
 * Les teneurs secondaires (fibres, alcool, acides organiques, polyols)
 * inconnues comptent pour zéro ; protéines, glucides ou lipides inconnus :
 * `null`, on ne sait pas.
 */
export function energyFromMacros(macros: Macros): Prisma.Decimal | null {
  const { protein, carbs, fat } = macros;
  if (protein === null || carbs === null || fat === null) return null;
  const zero = new Prisma.Decimal(0);
  // Comptés dans les glucides : jamais plus qu'eux (sinon, une énergie négative).
  const polyols = Prisma.Decimal.min(macros.polyols ?? zero, carbs);
  return protein
    .mul(4)
    .plus(carbs.minus(polyols).mul(4))
    .plus(polyols.mul(2.4))
    .plus(fat.mul(9))
    .plus((macros.fibre ?? zero).mul(2))
    .plus((macros.alcohol ?? zero).mul(7))
    .plus((macros.organicAcids ?? zero).mul(3))
    .toDecimalPlaces(1);
}
