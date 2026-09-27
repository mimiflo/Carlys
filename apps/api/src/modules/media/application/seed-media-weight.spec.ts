import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { readImageSize } from './image-size';

/**
 * LE POIDS DES PHOTOS DU CATALOGUE livrées avec le seed.
 *
 * Ces fichiers ne restent pas dans le dépôt : `syncExerciseMedia` les pousse
 * tels quels vers le stockage objet, d'où ils sont servis à l'application et
 * à l'administration sans aucune retouche. Leur poids est donc celui que
 * télécharge chaque personne qui ouvre la fiche d'un exercice.
 *
 * Mesuré en septembre 2026 : quatorze visuels « pectoraux » arrivés en PNG
 * 1536 × 1152 pesaient de 0,8 à 1,2 Mo chacun, 88 % des octets du catalogue,
 * quand les 142 autres photos étaient des WebP de 6 à 32 Ko. Convertis en
 * WebP qualité 90, canal alpha intact (détourage identique au pixel près),
 * ils sont passés de 13 649 à 1 923 Kio sans différence visible.
 *
 * Ce fichier garde les deux règles qui s'en déduisent. Le plafond laisse de
 * la marge à une illustration pleine page en WebP (la plus lourde fait
 * 184 Kio), et refuse d'emblée un PNG de cette taille.
 */
const DIRECTORY = join(__dirname, '..', '..', '..', '..', 'prisma', 'seed-media', 'exercises');
const MAX_BYTES = 256 * 1024;

const files = readdirSync(DIRECTORY).sort();

function isWebp(content: Buffer): boolean {
  return (
    content.length >= 12 &&
    content.toString('ascii', 0, 4) === 'RIFF' &&
    content.toString('ascii', 8, 12) === 'WEBP'
  );
}

describe('photos du seed : poids servi', () => {
  it('le dossier porte bien les photos du catalogue', () => {
    expect(files.length).toBeGreaterThan(100);
  });

  it('chaque photo est un WebP, par son contenu et par son nom', () => {
    const autres = files.filter(
      (file) => !file.endsWith('.webp') || !isWebp(readFileSync(join(DIRECTORY, file))),
    );
    expect(autres).toEqual([]);
  });

  it(`aucune photo ne dépasse ${MAX_BYTES / 1024} Kio`, () => {
    const lourdes = files
      .map((file) => ({ file, bytes: readFileSync(join(DIRECTORY, file)).byteLength }))
      .filter(({ bytes }) => bytes > MAX_BYTES);
    expect(lourdes).toEqual([]);
  });

  it('chaque photo a des dimensions lisibles, que la ligne MediaAsset recopie', () => {
    const illisibles = files.filter(
      (file) => readImageSize(readFileSync(join(DIRECTORY, file))) === null,
    );
    expect(illisibles).toEqual([]);
  });
});
