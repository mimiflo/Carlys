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
 * - `exercises/<slug>.webp` — les vignettes, **réduites** : la démo ne dispose
 *   d'aucun stockage objet, ses images voyagent donc dans l'APK. À pleine
 *   résolution elles pèseraient des méga-octets pour un affichage de 58 points.
 *   La réduction passe par `cwebp` ; sans lui, le script prévient et copie tel
 *   quel plutôt que d'échouer — une démo lourde vaut mieux qu'une démo nue.
 */
import { ExerciseDifficulty, ExerciseType } from '@prisma/client';
import { execFileSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { EQUIPMENT, EXERCISES, MUSCLE_GROUPS } from './catalog';

const MOBILE_DEMO = join(__dirname, '..', '..', 'mobile', 'assets', 'demo');
const SOURCE_MEDIA = join(__dirname, 'seed-media', 'exercises');

/** Côté de la vignette embarquée : 58 points affichés, 3× sur mobile. */
const THUMBNAIL_SIZE = 256;

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

/**
 * Réduit chaque vignette du seed. Sans `cwebp` installé, on copie l'original :
 * l'APK est plus lourd, mais la démo reste illustrée — c'est le bon compromis
 * pour un outil de développement.
 */
function exportThumbnails(): Set<string> {
  const out = join(MOBILE_DEMO, 'exercises');
  rmSync(out, { recursive: true, force: true });
  mkdirSync(out, { recursive: true });

  const slugs = new Set<string>();
  if (!existsSync(SOURCE_MEDIA)) return slugs;
  let fullSize = 0;

  for (const file of readdirSync(SOURCE_MEDIA).filter((n) => n.endsWith('.webp'))) {
    const slug = file.replace(/\.webp$/, '');
    const source = join(SOURCE_MEDIA, file);
    const target = join(out, file);
    try {
      execFileSync('cwebp', [
        '-quiet',
        '-resize',
        String(THUMBNAIL_SIZE),
        '0',
        '-q',
        '80',
        '-alpha_q',
        '90',
        source,
        '-o',
        target,
      ]);
    } catch {
      copyFileSync(source, target);
      fullSize++;
    }
    slugs.add(slug);
  }
  if (fullSize > 0) {
    console.warn(
      `⚠️  cwebp introuvable : ${fullSize} vignettes copiées en pleine ` +
        'résolution, l’APK de démo sera plus lourd que nécessaire. ' +
        'Installe-le (`apt install webp` / `brew install webp`) puis relance.',
    );
  }
  return slugs;
}

mkdirSync(MOBILE_DEMO, { recursive: true });
const photographed = exportThumbnails();
exportCatalog(photographed);
console.log(
  `Démo : ${EXERCISES.length} exercices, ${photographed.size} vignettes → apps/mobile/assets/demo/`,
);
