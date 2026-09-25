import { Prisma } from '@prisma/client';

/**
 * L'interprétation d'une teneur CIQUAL (`<teneur>` de `compo_*.xml`).
 *
 * La table écrit ses valeurs pour un lecteur humain français, pas pour une
 * machine. Cinq formes existent, et chacune a un SENS qu'il faut garder :
 *
 * | Écrit        | Sens                                         | Stocké |
 * | ------------ | -------------------------------------------- | ------ |
 * | `12,5`       | une valeur, virgule décimale                 | 12.5   |
 * | `traces`     | présent, en quantité négligeable             | 0      |
 * | `< 0,5`      | sous le seuil de quantification du dosage    | 0      |
 * | `-` ou vide  | NON DOSÉ : la table ne sait pas              | null   |
 *
 * `traces` et `< x` valent 0 : l'Anses publie ces mentions quand le dosage
 * existe mais ne mesure rien d'exploitable, et compter la borne haute
 * gonflerait la somme d'un repas d'un nutriment qu'on sait quasi absent.
 * `-` vaut `null`, jamais 0 : un « inconnu » compté pour zéro rendrait un
 * total de macros faux avec l'aplomb d'un vrai.
 *
 * Toute autre forme fait ÉCHOUER l'import, en nommant la valeur : c'est le
 * signe qu'une nouvelle version de la table a changé de convention, et la
 * deviner serait pire que s'arrêter.
 */

export class TeneurFormatError extends Error {}

/** Deux décimales, comme les colonnes `Decimal(7, 2)` qui la reçoivent. */
const STORED_PLACES = 2;

const NUMBER = /^\d+(?:[.,]\d+)?$/;
const BELOW_THRESHOLD = /^<\s*\d+(?:[.,]\d+)?$/;

export function parseTeneur(raw: string): Prisma.Decimal | null {
  // L'espace insécable sert parfois de séparateur dans les exports français.
  const text = raw.replace(/\u00a0/g, ' ').trim();
  if (text === '' || text === '-') {
    return null;
  }
  if (/^traces$/i.test(text) || BELOW_THRESHOLD.test(text)) {
    return new Prisma.Decimal(0);
  }
  if (NUMBER.test(text)) {
    return new Prisma.Decimal(text.replace(',', '.')).toDecimalPlaces(
      STORED_PLACES,
      Prisma.Decimal.ROUND_HALF_UP,
    );
  }
  throw new TeneurFormatError(`teneur illisible : « ${raw.trim()} ».`);
}
