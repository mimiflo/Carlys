/**
 * Un test e2e qui RELIT le journal d'audit doit d'abord attendre les
 * écritures en vol.
 *
 * POURQUOI CETTE GARDE EXISTE. `AuditService.record` est délibérément non
 * bloquant : un échec d'audit ne doit jamais faire échouer l'opération
 * métier, et la réponse HTTP ne doit pas attendre une écriture de journal.
 * La conséquence, côté test, est qu'au retour de la requête la ligne peut ne
 * pas encore être posée. Deux tests l'ont appris à leurs dépens en CI —
 * `auth.refresh_reuse_detected` et `admin.community_report_resolved` —, qui
 * tombaient au hasard sans qu'aucun code de production n'ait changé.
 *
 * `flush()` a fermé la course, et les quatre lectures du dépôt l'appellent.
 * Mais rien n'obligeait la CINQUIÈME. Une règle que rien ne relit n'est qu'un
 * souvenir : c'est ce fichier qui la tient, et il est délibérément dans
 * `src/` plutôt que dans `test/` pour tourner avec `pnpm test`, sans
 * PostgreSQL ni Redis — donc y compris sur un poste sans Docker, là où la
 * suite e2e elle-même ne peut pas s'exécuter.
 *
 * Ce qu'elle NE prétend pas faire : lire du TypeScript comme un compilateur.
 * L'analyse est textuelle, bornée au bloc de test englobant. Un test qui
 * appellerait `flush()` depuis un helper défini ailleurs lui échapperait —
 * mais il échapperait aussi à la relecture humaine, et le seuil de santé
 * ci-dessous garantit au moins qu'elle regarde encore quelque chose.
 */
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

/** Le dossier des suites e2e, vu depuis `src/modules/audit/`. */
const DOSSIER_E2E = join(__dirname, '..', '..', '..', 'test');

/**
 * Une LECTURE du journal : par Prisma, ou par la route du back-office.
 *
 * `deleteMany` en est volontairement exclu — nettoyer n'est pas relire, et le
 * nettoyage vit en `afterAll`, où il n'y a aucune course à perdre.
 */
const LECTURES = [/prisma\.auditLog\.find\w*/g, /admin\/audit-logs/g];

/** L'attente explicite des écritures en vol. */
const FLUSH = /\.flush\(\)/;

/**
 * Les ouvertures de bloc de test. La plus proche AVANT une lecture borne la
 * zone où le `flush()` doit se trouver : un `flush()` posé dans le test
 * précédent n'attend pas l'écriture de celui-ci.
 */
const BLOCS = /\b(?:it|test|beforeAll|beforeEach|afterAll|afterEach)\s*\(/g;

interface Lecture {
  fichier: string;
  ligne: number;
  extrait: string;
  protegee: boolean;
}

function lecturesDuFichier(nom: string, source: string): Lecture[] {
  const debutsDeBloc = [...source.matchAll(BLOCS)].map((m) => m.index ?? 0);
  const trouvees: Lecture[] = [];

  for (const motif of LECTURES) {
    for (const m of source.matchAll(motif)) {
      const position = m.index ?? 0;
      // Le bloc englobant : la dernière ouverture avant la lecture. À défaut
      // (lecture au premier niveau du fichier), on remonte au début.
      const debut = debutsDeBloc.filter((d) => d < position).pop() ?? 0;
      trouvees.push({
        fichier: nom,
        ligne: source.slice(0, position).split('\n').length,
        extrait: m[0],
        protegee: FLUSH.test(source.slice(debut, position)),
      });
    }
  }
  return trouvees;
}

describe('les tests e2e qui relisent le journal d’audit attendent les écritures', () => {
  const fichiers = readdirSync(DOSSIER_E2E).filter((f) => f.endsWith('.e2e-spec.ts'));
  const lectures = fichiers.flatMap((nom) =>
    lecturesDuFichier(nom, readFileSync(join(DOSSIER_E2E, nom), 'utf8')),
  );

  it('la garde lit vraiment les suites e2e', () => {
    // Sans cette assertion, un déplacement du dossier `test/` ou une
    // expression régulière cassée rendrait la règle suivante verte en ne
    // lisant plus rien — le pire état pour un garde-fou, celui où il
    // rassure sans regarder. Les seuils sont volontairement bas : ils ne
    // mesurent pas la taille de la suite, ils détectent l'aveuglement.
    expect(fichiers.length).toBeGreaterThanOrEqual(15);
    expect(lectures.length).toBeGreaterThanOrEqual(4);
  });

  it('chaque lecture est précédée d’un flush() dans le même bloc', () => {
    const nues = lectures
      .filter((l) => !l.protegee)
      .map((l) => `${l.fichier}:${l.ligne} → ${l.extrait}`);

    expect(nues).toEqual([]);
  });
});
