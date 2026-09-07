/**
 * Garde-fou de FRAÎCHEUR du catalogue de démonstration.
 *
 * `apps/mobile/assets/demo/catalog.json` est engendré, mais il est versionné :
 * l'APK de démo doit se construire sans lancer l'API. Un fichier engendré et
 * versionné dérive — c'est exactement ce qui s'était produit avec l'ancienne
 * liste écrite à la main (onze exercices affichés sur cinquante-cinq).
 *
 * Ce test compare le fichier au seed. S'il échoue, il n'y a rien à corriger à
 * la main : relancer `pnpm --filter @carlys/api demo:catalog` et commiter.
 */
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { EQUIPMENT, EXERCISES, MUSCLE_GROUPS } from './catalog';

interface ExportedCatalog {
  exercisesCount: number;
  muscleGroups: { slug: string }[];
  equipment: { slug: string }[];
  exercises: { slug: string; primary: string; hasPhoto: boolean; photoFile: string | null }[];
}

const REGENERATE = 'Relance `pnpm --filter @carlys/api demo:catalog` puis commite le résultat.';

describe('catalogue de démonstration engendré', () => {
  const file = join(__dirname, '..', '..', 'mobile', 'assets', 'demo', 'catalog.json');
  const exported = JSON.parse(readFileSync(file, 'utf8')) as ExportedCatalog;

  it(`liste les mêmes exercices que le seed — sinon : ${REGENERATE}`, () => {
    expect(exported.exercisesCount).toBe(EXERCISES.length);
    expect(exported.exercises.map((exercise) => exercise.slug)).toEqual(
      EXERCISES.map((exercise) => exercise.slug),
    );
  });

  it(`liste les mêmes groupes musculaires et matériels — sinon : ${REGENERATE}`, () => {
    expect(exported.muscleGroups.map((group) => group.slug)).toEqual(
      MUSCLE_GROUPS.map((group) => group.slug),
    );
    expect(exported.equipment.map((item) => item.slug)).toEqual(EQUIPMENT.map((item) => item.slug));
  });

  it('livre chaque photo avec son extension réelle et les mêmes octets que le seed', () => {
    for (const exercise of exported.exercises) {
      if (!exercise.hasPhoto) {
        expect(exercise.photoFile).toBeNull();
        continue;
      }
      expect(exercise.photoFile).toMatch(/\.(png|webp)$/);
      const name = exercise.photoFile!;
      const source = readFileSync(join(__dirname, 'seed-media', 'exercises', name));
      const bundled = readFileSync(
        join(__dirname, '..', '..', 'mobile', 'assets', 'demo', 'exercises', name),
      );
      expect(bundled.equals(source)).toBe(true);
      if (exercise.primary === 'pectoraux') {
        expect(name).toBe(`${exercise.slug}.png`);
        expect(source.subarray(0, 8).toString('hex')).toBe('89504e470d0a1a0a');
        expect(source.readUInt32BE(16)).toBe(1536);
        expect(source.readUInt32BE(20)).toBe(1152);
        expect(source[25]).toBe(6); // PNG RGBA, pas un JPEG renommé.
        expect(
          existsSync(join(__dirname, 'seed-media', 'exercises', `${exercise.slug}.webp`)),
        ).toBe(false);
      }
    }
  });
});
