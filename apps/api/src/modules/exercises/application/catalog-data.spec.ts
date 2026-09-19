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
import { EQUIPMENT, EXERCISES, MUSCLE_GROUPS } from './catalog-data';

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

  /**
   * CE QUE CETTE SECTION PROTÈGE : quelqu'un qui n'a AUCUN matériel peut
   * s'entraîner.
   *
   * `equipment` est une CONJONCTION — le filtre ne retient un exercice que si
   * la personne possède TOUT ce qui y figure. Y glisser un objet de confort
   * ferme donc l'exercice à qui ne l'a pas. Quinze mouvements de sol (planche,
   * crunch, pont fessier, gainage latéral…) exigeaient un TAPIS : une personne
   * sans matériel n'atteignait que neuf exercices du catalogue, et six groupes
   * musculaires sur douze lui étaient inaccessibles. La génération de
   * programme ne pouvait rien lui proposer d'honnête.
   *
   * Le plancher ci-dessous est délibérément bas : il ne dit pas que le
   * catalogue est riche, il dit qu'il n'est pas VIDE là où il comptait.
   *
   * CE QUI MANQUE ENCORE, et que ce fichier n'épingle pas encore : le DOS,
   * les ÉPAULES et les BICEPS restent sans le moindre exercice réalisable
   * sans matériel. Le plancher par groupe musculaire arrivera avec les
   * exercices qui le rendront vrai — un test écrit avant son contenu échoue
   * en CI et n'apprend rien à personne.
   */
  describe('sans aucun matériel', () => {
    const bodyweight = EXERCISES.filter(
      (exercise) => exercise.equipment.length === 1 && exercise.equipment[0] === 'poids-du-corps',
    );

    it('en porte assez pour composer une séance complète', () => {
      // Huit exercices, c'est le plancher d'une séance de corps entier
      // générée : sous ce seuil, le générateur répéterait les mêmes
      // mouvements d'une séance à l'autre.
      expect(bodyweight.length).toBeGreaterThanOrEqual(8);
    });

    it('n’exige jamais un objet de CONFORT', () => {
      // Le tapis en est un : une planche se tient sur le sol. Aucun exercice
      // ne doit se rendre inaccessible pour un accessoire substituable.
      const surTapisSeul = EXERCISES.filter(
        (exercise) => exercise.equipment.length === 1 && exercise.equipment[0] === 'tapis',
      );
      expect(surTapisSeul.map((exercise) => exercise.slug)).toEqual([]);
    });
  });

  it('ne livre pas de photo orpheline', () => {
    // Le nom du fichier EST le slug (`seed-media.ts`) : une photo dont le slug
    // n'existe pas ne serait jamais rattachée, et personne ne s'en apercevrait.
    // L'inverse est normal : les photos arrivent par lots, le catalogue est
    // volontairement illustré en partie seulement.
    const slugs = new Set(EXERCISES.map((exercise) => exercise.slug));
    // Les photos n'ont pas déménagé avec les données : elles restent sous
    // prisma/, hors de la compilation — seuls leurs octets comptent.
    const directory = join(__dirname, '..', '..', '..', '..', 'prisma', 'seed-media', 'exercises');
    const files = existsSync(directory) ? readdirSync(directory) : [];
    const orphans = files
      .filter((name) => name.endsWith('.webp'))
      .map((name) => name.replace(/\.webp$/, ''))
      .filter((slug) => !slugs.has(slug));
    expect(orphans).toEqual([]);
  });
});
