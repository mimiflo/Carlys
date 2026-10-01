import { globSync, readFileSync } from 'node:fs';
import { join, relative } from 'node:path';
import { describe, expect, it } from 'vitest';

/**
 * LE BACK-OFFICE TUTOIE, comme l'application.
 *
 * La relecture de septembre 2026 a trouvé quatre textes restés au
 * vouvoiement, dont trois dans des fichiers qu'on venait de reprendre pour
 * passer au tutoiement : « vérifiez que l'API est démarrée » sur la page de
 * connexion (une consigne de développeur, servie en production),
 * « Connectez-vous » sur l'accueil, « reclassez-les d'abord »,
 * « Action impossible, réessayez ». Une relecture à l'œil en laisse passer :
 * ce balai lit toutes les sources des écrans, commentaires exclus.
 */

const srcRoot = join(__dirname, '..');

/** Les sources de l'application : ni les tests, ni leurs jeux d'essai. */
function sources(directory: string): string[] {
  return globSync('**/*.{ts,tsx}', { cwd: directory })
    .filter((path) => !path.startsWith('testing/') && !path.includes('.test.'))
    .map((path) => join(directory, path));
}

/**
 * Les commentaires parlent aux développeurs, pas à l'administrateur : ils
 * sont blanchis, en gardant les sauts de ligne pour que les numéros de ligne
 * restent justes. Le `//` précédé de `:` est celui d'une URL, pas un
 * commentaire.
 */
function withoutComments(source: string): string {
  return source
    .replace(/\/\*[\s\S]*?\*\//g, (block) => block.replace(/[^\n]/g, ' '))
    .replace(/(^|[^:])\/\/.*$/gm, '$1');
}

/** « vous », « votre », « vos », et toute forme en -ez (« réessayez », « Connectez »). */
const VOUVOIEMENT = /(?<!\p{L})(vous|votre|vos|\p{L}+ez)(?!\p{L})/giu;

/** Les mots en -ez qui ne sont pas un verbe conjugué. */
const NOT_A_VERB = new Set(['assez', 'chez', 'nez', 'rez']);

function vouvoiements(source: string): { line: number; word: string }[] {
  return withoutComments(source)
    .split('\n')
    .flatMap((text, index) =>
      [...text.matchAll(VOUVOIEMENT)]
        .map(([, word = '']) => word)
        .filter((word) => !NOT_A_VERB.has(word.toLowerCase()))
        .map((word) => ({ line: index + 1, word })),
    );
}

describe('Tutoiement', () => {
  const files = sources(srcRoot);

  it('lit bien les sources des écrans', () => {
    expect(files.length).toBeGreaterThan(20);
  });

  it('le balai reconnaît le vouvoiement, et pas les commentaires ni les mots en -ez', () => {
    expect(vouvoiements("'Connexion impossible : vérifiez que l’API est démarrée.'")).toEqual([
      { line: 1, word: 'vérifiez' },
    ]);
    expect(vouvoiements('<p>Connectez-vous avec un compte.</p>')).toHaveLength(2);
    expect(vouvoiements("// Réessayez plus tard\n'Passe chez le coach, assez vite.'")).toEqual([]);
  });

  it('aucun texte de l’admin ne vouvoie', () => {
    const faults = files.flatMap((file) =>
      vouvoiements(readFileSync(file, 'utf8')).map(
        ({ line, word }) => `${relative(srcRoot, file)}:${line} — « ${word} »`,
      ),
    );
    expect(faults).toEqual([]);
  });
});
