/**
 * Fabrique le catalogue de l'application de DÉMONSTRATION depuis le seed.
 *
 *   pnpm --filter @carlys/api demo:catalog
 *
 * La démo tourne sans serveur : elle a donc besoin de ses propres données,
 * embarquées dans l'application. Jusqu'ici cette liste était recopiée à la
 * main — et elle a dérivé, onze exercices contre cinquante-cinq. Elle est
 * désormais DÉRIVÉE de `catalog.ts`, l'unique source de vérité.
 *
 * Deux sorties dans `apps/mobile/assets/demo/` :
 *
 * - `catalog.json` — les exercices, groupes musculaires et matériels ;
 * - `exercises/<slug>.webp` — les vignettes, copiées telles quelles. La démo ne
 *   dispose d'aucun stockage objet : ses images voyagent dans l'APK. On a
 *   d'abord voulu les réduire, puis mesuré que les originaux plafonnent à
 *   ~400 px et pèsent une dizaine de kilo-octets — alors que la fiche d'un
 *   exercice les affiche sur 300 points de haut, soit 900 pixels. Les réduire
 *   dégradait l'écran de détail pour quelques centaines de kilo-octets.
 *   Copier garde en prime une sortie REPRODUCTIBLE, ce qui compte pour un
 *   fichier engendré mais versionné : aucun encodeur externe dans la boucle.
 */
import { ExerciseDifficulty, ExerciseType } from '@prisma/client';
import { copyFileSync, existsSync, mkdirSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { EQUIPMENT, EXERCISES, MUSCLE_GROUPS } from './catalog';

const MOBILE_DEMO = join(__dirname, '..', '..', 'mobile', 'assets', 'demo');
const SOURCE_MEDIA = join(__dirname, 'seed-media', 'exercises');

function difficultyOf(value: ExerciseDifficulty): string {
  return value;
}

function typeOf(value: ExerciseType): string {
  return value;
}

function exportCatalog(withPhoto: Set<string>): void {
  const catalogue = {
    // Repère de fraîcheur : la CI compare ce nombre à celui du seed.
    exercisesCount: EXERCISES.length,
    muscleGroups: MUSCLE_GROUPS,
    equipment: EQUIPMENT,
    exercises: EXERCISES.map((exercise) => ({
      slug: exercise.slug,
      name: exercise.name,
      description: exercise.description,
      instructions: exercise.instructions,
      difficulty: difficultyOf(exercise.difficulty),
      type: typeOf(exercise.type),
      isPremium: exercise.isPremium ?? false,
      tags: exercise.tags,
      primary: exercise.primary,
      secondary: exercise.secondary,
      equipment: exercise.equipment,
      hasPhoto: withPhoto.has(exercise.slug),
    })),
  };
  writeFileSync(join(MOBILE_DEMO, 'catalog.json'), `${JSON.stringify(catalogue, null, 2)}\n`);
}

/** Recopie les photos du seed ; le dossier est reconstruit à chaque passage. */
function exportThumbnails(): Set<string> {
  const out = join(MOBILE_DEMO, 'exercises');
  // On efface avant de recopier : sans cela, la photo d'un exercice supprimé
  // du catalogue resterait dans l'APK, et le test de fraîcheur ne le dirait pas.
  rmSync(out, { recursive: true, force: true });
  mkdirSync(out, { recursive: true });

  const slugs = new Set<string>();
  if (!existsSync(SOURCE_MEDIA)) return slugs;

  for (const file of readdirSync(SOURCE_MEDIA).filter((n) => n.endsWith('.webp'))) {
    copyFileSync(join(SOURCE_MEDIA, file), join(out, file));
    slugs.add(file.replace(/\.webp$/, ''));
  }
  return slugs;
}

mkdirSync(MOBILE_DEMO, { recursive: true });
const photographed = exportThumbnails();
exportCatalog(photographed);
console.log(
  `Démo : ${EXERCISES.length} exercices, ${photographed.size} vignettes → apps/mobile/assets/demo/`,
);
