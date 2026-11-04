import { type FoodAttribution, type PackagedFood } from '@carlys/api-contracts';
import { z } from 'zod';

/** La mention que la licence ODbL demande près des valeurs. */
export function openFoodFactsAttribution(): FoodAttribution {
  return {
    attribution: 'Source : Open Food Facts',
    license: 'Open Database License (ODbL)',
    url: 'https://world.openfoodfacts.org/',
  };
}

/** Les seuls champs demandés à Open Food Facts : ce que l'écran montre. */
export const OPEN_FOOD_FACTS_FIELDS = [
  'product_name_fr',
  'product_name',
  'brands',
  'nutriments',
  'serving_quantity',
  'product_quantity_unit',
].join(',');

/** Un nom d'aliment se borne comme le nom d'un repas, qui le reprend. */
const NAME_MAX = 120;
/** Au-delà, ce n'est plus une valeur pour 100 g (l'huile en fait 900). */
const KCAL_PER_100_MAX = 900;
const MACRO_PER_100_MAX = 100;
const SERVING_MAX = 5_000;

/**
 * Base COLLABORATIVE : tout champ peut manquer, être une chaîne ou être faux.
 * Rien n'est cru sur parole — chaque valeur hors de ses bornes est tenue pour
 * inconnue, et un produit sans énergie lisible n'est pas un produit utilisable.
 */
// Une chaîne numérique se lit ; `null`, une chaîne vide ou un texte sont
// inconnus (un `coerce` en ferait 0, soit un produit sans calories).
const number = z.preprocess(
  (value) => (typeof value === 'string' && value.trim() !== '' ? Number(value) : value),
  z.number(),
);
const productSchema = z.object({
  product_name_fr: z.string().optional().catch(undefined),
  product_name: z.string().optional().catch(undefined),
  brands: z.string().optional().catch(undefined),
  serving_quantity: number.optional().catch(undefined),
  product_quantity_unit: z.string().optional().catch(undefined),
  nutriments: z
    .object({
      'energy-kcal_100g': number.optional().catch(undefined),
      /** En kJ quand le produit ne donne pas les kcal. */
      energy_100g: number.optional().catch(undefined),
      proteins_100g: number.optional().catch(undefined),
      carbohydrates_100g: number.optional().catch(undefined),
      fat_100g: number.optional().catch(undefined),
    })
    .catch({}),
});

const within = (value: number | undefined, max: number): number | null =>
  value !== undefined && value >= 0 && value <= max ? Math.round(value * 10) / 10 : null;

// Les caractères de contrôle et de format (bidi, espaces sans largeur) d'une
// fiche collaborative ne passent pas : le nom finit dans le journal, et de là
// dans ce que le coach relit.
const text = (value: string | undefined): string | null => {
  const trimmed = value
    ?.replace(/[\p{Cc}\p{Cf}]/gu, ' ')
    .trim()
    .replace(/\s+/g, ' ');
  return trimmed ? trimmed.slice(0, NAME_MAX) : null;
};

/** La fiche Open Food Facts, en produit Carlys — ou `null` si inutilisable. */
export function toPackagedFood(barcode: string, raw: unknown): PackagedFood | null {
  const parsed = productSchema.safeParse(raw);
  if (!parsed.success) return null;
  const product = parsed.data;
  const n = product.nutriments;
  const kcal = within(
    n['energy-kcal_100g'] ?? (n.energy_100g === undefined ? undefined : n.energy_100g / 4.184),
    KCAL_PER_100_MAX,
  );
  if (kcal === null) return null;
  const brand = text(product.brands?.split(',')[0]);
  const serving = product.serving_quantity;
  return {
    barcode,
    name: text(product.product_name_fr) ?? text(product.product_name) ?? brand ?? 'Produit scanné',
    brand,
    per100g: {
      kcal,
      proteinG: within(n.proteins_100g, MACRO_PER_100_MAX),
      carbsG: within(n.carbohydrates_100g, MACRO_PER_100_MAX),
      fatG: within(n.fat_100g, MACRO_PER_100_MAX),
    },
    liquid: product.product_quantity_unit?.trim().toLowerCase() === 'ml',
    servingQuantity:
      serving !== undefined && serving > 0 && serving <= SERVING_MAX ? serving : null,
  };
}
