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
   * s'entraîner, et la génération de programme a de quoi lui composer une
   * séance honnête.
   *
   * `equipment` est une CONJONCTION — le filtre ne retient un exercice que si
   * la personne possède TOUT ce qui y figure (`exercises.repository.ts`,
   * `equipment: { some: { equipment: { slug } } }`). Y glisser un objet de
   * confort ferme donc l'exercice à qui ne l'a pas. Deux fautes s'y sont
   * succédé, toutes deux invisibles en CI avant ces tests : quinze mouvements
   * de sol exigeaient un TAPIS, et trois entrées mêlaient `poids-du-corps` à
   * du matériel, ce qui sous la conjonction exige les DEUX.
   *
   * Les planchers ci-dessous sont délibérément bas : ils ne disent pas que le
   * catalogue est riche, ils disent qu'il n'est pas VIDE là où il comptait.
   *
   * CE QU'ILS NE DISENT PAS, et qu'il faut savoir avant de s'y fier : ouvert
   * n'est pas résolu. Le dos sans matériel tient à `tirage-a-plat-ventre`,
   * qui travaille contre le seul poids des bras — de l'entretien postural,
   * pas du développement de force ; et `curl-auto-resiste` oppose une charge
   * que rien ne mesure, donc la courbe de progression du biceps restera
   * plate. Un générateur qui vise la FORCE du dos ou du biceps doit exiger
   * `barre-de-traction` ou `elastique` : il ne peut pas se croire quitte
   * parce que la case n'est plus vide.
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

    it('ne mêle jamais « poids du corps » à du matériel', () => {
      // Sous la CONJONCTION, `['poids-du-corps', 'banc']` se lit « il faut les
      // deux » : l'entrée n'est donc JAMAIS servie à qui n'a rien, alors que
      // la présence de `poids-du-corps` promet l'inverse. Soit l'objet est
      // exigé et il est seul, soit il est substituable et il n'y figure pas.
      const melanges = EXERCISES.filter(
        (exercise) =>
          exercise.equipment.length > 1 && exercise.equipment.includes('poids-du-corps'),
      );
      expect(melanges.map((exercise) => exercise.slug)).toEqual([]);
    });

    /**
     * Le plancher par groupe musculaire, celui que le commentaire précédent
     * annonçait. Il se pose maintenant parce que les exercices qui le rendent
     * vrai existent — un test écrit avant son contenu échoue en CI et
     * n'apprend rien à personne.
     *
     * Il compte le groupe PRINCIPAL seulement : un groupe qui n'apparaît qu'en
     * secondaire est sollicité, pas entraîné, et le générateur ne peut pas
     * remplir un créneau avec. Et il écarte les étirements et la mobilité :
     * `etirement-ischio-debout` couvrait les ischio-jambiers sans rien
     * renforcer, exactement le genre de vert trompeur que ce test existe pour
     * refuser.
     */
    it('ouvre au moins un exercice à chacun des groupes entraînables', () => {
      const couverts = new Set(
        bodyweight
          .filter((exercise) => exercise.type === 'STRENGTH' || exercise.type === 'CARDIO')
          .map((exercise) => exercise.primary),
      );
      // `avant-bras` est nommément hors plancher : il est à zéro en principal
      // sur les 190 entrées, MATÉRIEL COMPRIS. Ce n'est pas un trou du poids
      // du corps, c'est un trou du catalogue entier, et le combler demandera
      // de la préhension (suspension, curls de poignets) qui exigera de toute
      // façon `barre-de-traction` ou `halteres`.
      const entrainables = MUSCLE_GROUPS.map((group) => group.slug).filter(
        (slug) => slug !== 'avant-bras',
      );
      expect(entrainables.filter((slug) => !couverts.has(slug))).toEqual([]);
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
