import { ACADEMY_LESSON_IDS } from '@carlys/api-contracts';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

/// CE QUE CE FICHIER PROTÈGE : le serveur n'accepte une réponse de quiz que
/// pour une leçon du pack embarqué (`ACADEMY_LESSON_IDS`). Si le pack gagne
/// une leçon sans que le contrat la connaisse, chaque réponse à cette leçon
/// serait refusée (400) — et la file de synchronisation tient un 4xx pour
/// définitif. Ce test rend l'oubli impossible : la liste du contrat est celle
/// du pack, ni plus ni moins.

interface Pack {
  lessons: Array<{ id: string }>;
}

describe('ACADEMY_LESSON_IDS', () => {
  it('reprend exactement les leçons du pack de l’application', () => {
    const chemin = join(__dirname, '../../../../../mobile/assets/academy/pack.json');
    const pack = JSON.parse(readFileSync(chemin, 'utf8')) as Pack;

    expect([...ACADEMY_LESSON_IDS].sort()).toEqual(pack.lessons.map((lesson) => lesson.id).sort());
  });
});
