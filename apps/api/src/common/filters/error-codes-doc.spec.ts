import { apiErrorCodeSchema } from '@carlys/api-contracts';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

/**
 * `docs/api/README.md` présente `code` comme un enum FERMÉ et en donne le
 * tableau : c'est d'après lui qu'un client décide quels cas traiter. Un code
 * ajouté au contrat sans sa ligne (`UNSUPPORTED_MEDIA_TYPE`, arrivé avec la
 * photo d'un repas) laissait ce client sans le prévoir. Le tableau suit donc
 * le contrat, ligne pour ligne.
 */
const README = join(__dirname, '..', '..', '..', '..', '..', 'docs', 'api', 'README.md');

function documentedCodes(): string[] {
  const markdown = readFileSync(README, 'utf8');
  const start = markdown.indexOf('### Codes d');
  const section = markdown.slice(start, markdown.indexOf('\n## ', start));
  return [...section.matchAll(/^\| `([A-Z_]+)` \| \d{3} \|/gm)].map((match) => match[1] ?? '');
}

describe('docs/api/README.md, « Codes d’erreur »', () => {
  it('liste exactement les codes du contrat, un par ligne', () => {
    expect(documentedCodes().sort()).toEqual([...apiErrorCodeSchema.options].sort());
  });
});
