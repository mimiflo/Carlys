/**
 * Intégrité du catalogue.
 *
 * Le catalogue est écrit à la main et il grossit par lots (une planche de
 * photos à la fois). Une faute de frappe dans un slug de groupe musculaire ou
 * de matériel ne se voit pas : le seed la ferait échouer en base, et seulement
 * une fois PostgreSQL disponible — donc jamais en CI, où le seed ne tourne pas.
 * Ces vérifications-là ne coûtent rien et se font sans base.
 */
import { existsSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { EQUIPMENT, EXERCISES, MUSCLE_GROUPS } from './catalog';

const groups = new Set(MUSCLE_GROUPS.map((group) => group.slug));
const equipment = new Set(EQUIPMENT.map((item) => item.slug));
const SLUG = /^[a-z0-9]+(-[a-z0-9]+)*$/;

describe('catalogue', () => {
  it('n’a ni slug en double ni slug mal formé', () => {
    const seen = new Set<string>();
    for (const exercise of EXERCISES) {
      expect(exercise.slug).toMatch(SLUG);
      expect(seen.has(exercise.slug)).toBe(false);
      seen.add(exercise.slug);
    }
  });

  it('ne référence que des groupes musculaires et des matériels existants', () => {
    for (const exercise of EXERCISES) {
      expect(groups).toContain(exercise.primary);
      for (const slug of exercise.secondary) {
        expect(groups).toContain(slug);
      }
      // Un groupe secondaire qui répète le principal n'apporte rien et
      // dédoublerait la ligne « muscles » de la fiche.
      expect(exercise.secondary).not.toContain(exercise.primary);
      expect(new Set(exercise.secondary).size).toBe(exercise.secondary.length);
      for (const slug of exercise.equipment) {
        expect(equipment).toContain(slug);
      }
    }
  });

  it('décrit chaque mouvement', () => {
    for (const exercise of EXERCISES) {
      expect(exercise.name.length).toBeGreaterThan(2);
      expect(exercise.description.length).toBeGreaterThan(20);
      expect(exercise.instructions.length).toBeGreaterThanOrEqual(3);
      expect(exercise.tags.length).toBeGreaterThan(0);
    }
  });

  it('ne livre pas de photo orpheline', () => {
    // Le nom du fichier EST le slug (`seed-media.ts`) : une photo dont le slug
    // n'existe pas ne serait jamais rattachée, et personne ne s'en apercevrait.
    // L'inverse est normal : les photos arrivent par lots, le catalogue est
    // volontairement illustré en partie seulement.
    const slugs = new Set(EXERCISES.map((exercise) => exercise.slug));
    const directory = join(__dirname, 'seed-media', 'exercises');
    const files = existsSync(directory) ? readdirSync(directory) : [];
    const orphans = files
      .filter((name) => name.endsWith('.webp'))
      .map((name) => name.replace(/\.webp$/, ''))
      .filter((slug) => !slugs.has(slug));
    expect(orphans).toEqual([]);
  });
});
