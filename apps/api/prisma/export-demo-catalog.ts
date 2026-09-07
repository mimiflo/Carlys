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
 * - `exercises/<slug>.png|webp` — les images, copiées telles quelles. La démo ne
 *   dispose d'aucun stockage objet : ses images voyagent dans l'APK. On
 *   conserve les originaux, dont les pectoraux en PNG transparent 1536 × 1152,
 *   pour que les fiches d'exercices restent nettes sur les écrans mobiles.
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

function exportCatalog(withPhoto: Map<string, string>): void {
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
      photoFile: withPhoto.get(exercise.slug) ?? null,
    })),
  };
  writeFileSync(join(MOBILE_DEMO, 'catalog.json'), `${JSON.stringify(catalogue, null, 2)}\n`);
}

/** Recopie les photos du seed ; le dossier est reconstruit à chaque passage. */
function exportThumbnails(): Map<string, string> {
  const out = join(MOBILE_DEMO, 'exercises');
  // On efface avant de recopier : sans cela, la photo d'un exercice supprimé
  // du catalogue resterait dans l'APK, et le test de fraîcheur ne le dirait pas.
  rmSync(out, { recursive: true, force: true });
  mkdirSync(out, { recursive: true });

  const slugs = new Map<string, string>();
  if (!existsSync(SOURCE_MEDIA)) return slugs;

  for (const file of readdirSync(SOURCE_MEDIA).filter((n) => /\.(png|webp)$/.test(n))) {
    copyFileSync(join(SOURCE_MEDIA, file), join(out, file));
    slugs.set(file.replace(/\.(png|webp)$/, ''), file);
  }
  return slugs;
}

mkdirSync(MOBILE_DEMO, { recursive: true });
const photographed = exportThumbnails();
exportCatalog(photographed);
console.log(
  `Démo : ${EXERCISES.length} exercices, ${photographed.size} vignettes → apps/mobile/assets/demo/`,
);
