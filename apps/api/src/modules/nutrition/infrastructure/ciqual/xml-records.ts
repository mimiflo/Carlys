/**
 * Extracteur d'enregistrements pour un XML PLAT et RÉGULIER.
 *
 * POURQUOI À LA MAIN, SANS DÉPENDANCE. La distribution XML de CIQUAL n'use
 * d'aucune des raisons d'être d'un analyseur XML complet : pas d'espace de
 * noms, pas d'imbrication au-delà de deux niveaux, pas de DTD, pas de CDATA.
 * C'est une table, écrite en balises :
 *
 *   <TABLE>
 *   <ALIM>
 *   <alim_code> 1000 </alim_code>
 *   <alim_nom_fr> Pastis </alim_nom_fr>
 *   …
 *   </ALIM>
 *   …
 *   </TABLE>
 *
 * Une bibliothèque XML ajouterait une dépendance de production à l'image de
 * l'API pour une commande lancée une fois par version de la table, et
 * beaucoup de surface pour rien. Ce fichier fait une
 * seule chose — rendre chaque enregistrement `<TAG>` sous forme de champs
 * texte — et la fait strictement : tout ce qu'il ne comprend pas le fait
 * ÉCHOUER avec la position fautive, plutôt que de sauter une ligne en
 * silence. Un import à moitié lu serait pire qu'un import refusé.
 *
 * Ce qu'il accepte, en plus du strict nécessaire, parce que le vrai fichier
 * peut le contenir : les commentaires `<!-- -->` (ignorés), les éléments
 * vides auto-fermants à attributs (`<min missing=" " />`, valeur vide), les
 * entités XML standard (`&lt;`, `&amp;`, `&#233;`…), et un `<` brut dans un
 * texte (« < 0,5 ») que certains exports n'échappent pas.
 */

export class XmlFormatError extends Error {}

const ENTITIES: Readonly<Record<string, string>> = {
  lt: '<',
  gt: '>',
  amp: '&',
  quot: '"',
  apos: "'",
};

/** Décode les entités XML ; une entité inconnue reste telle quelle. */
export function decodeXmlEntities(text: string): string {
  return text.replace(/&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);/g, (whole, body: string) => {
    if (body.startsWith('#x')) {
      return String.fromCodePoint(Number.parseInt(body.slice(2), 16));
    }
    if (body.startsWith('#')) {
      return String.fromCodePoint(Number.parseInt(body.slice(1), 10));
    }
    return ENTITIES[body] ?? whole;
  });
}

/**
 * Un document tronqué — téléchargement interrompu, copie partielle — peut
 * s'arrêter pile entre deux enregistrements : chaque enregistrement lu
 * serait alors complet, et il en manquerait des centaines sans que rien ne
 * le dise. Un vrai document se termine par la fermeture de sa racine.
 */
function assertRootClosed(xml: string): void {
  // La racine : le premier élément, après le prologue `<?xml … ?>`.
  const root = /<([A-Za-z_][\w.-]*)/.exec(xml)?.[1];
  if (root === undefined || !new RegExp(`</${root}\\s*>\\s*$`).test(xml)) {
    throw new XmlFormatError(
      `le document ne se termine pas par </${root ?? '…'}>, la fermeture de sa racine : fichier tronqué ?`,
    );
  }
}

/** Les champs d'UN enregistrement, noms en minuscules. */
function recordFields(body: string, where: string): Record<string, string> {
  const fields: Record<string, string> = {};
  // Une balise ouvrante, ses éventuels attributs, et le `/` d'un élément vide.
  const openingTag = /<([A-Za-z_][\w.-]*)((?:\s[^<>]*?)?)(\/?)>/g;
  let match: RegExpExecArray | null;
  while ((match = openingTag.exec(body)) !== null) {
    const tag = match[1] ?? '';
    const key = tag.toLowerCase();
    let value = '';
    if (match[3] !== '/') {
      const closing = body.indexOf(`</${tag}`, openingTag.lastIndex);
      const end = closing === -1 ? -1 : body.indexOf('>', closing);
      if (end === -1) {
        throw new XmlFormatError(`${where} : balise <${tag}> jamais fermée.`);
      }
      value = decodeXmlEntities(body.slice(openingTag.lastIndex, closing)).trim();
      openingTag.lastIndex = end + 1;
    }
    if (key in fields) {
      throw new XmlFormatError(`${where} : le champ <${tag}> apparaît deux fois.`);
    }
    fields[key] = value;
  }
  return fields;
}

/**
 * Parcourt les enregistrements `<recordTag>…</recordTag>` du document, dans
 * l'ordre, sans les garder tous en mémoire (le fichier des teneurs en
 * compte plus de deux cent mille).
 */
export function* xmlRecords(xml: string, recordTag: string): Generator<Record<string, string>> {
  const document = xml.replace(/<!--[\s\S]*?-->/g, '');
  assertRootClosed(document);
  const opening = new RegExp(`<${recordTag}(?:\\s[^<>]*)?>`, 'g');
  const closingTag = `</${recordTag}>`;
  let index = 0;
  while (opening.exec(document) !== null) {
    index += 1;
    const start = opening.lastIndex;
    const end = document.indexOf(closingTag, start);
    if (end === -1) {
      throw new XmlFormatError(`enregistrement <${recordTag}> n° ${index} jamais fermé.`);
    }
    yield recordFields(document.slice(start, end), `enregistrement <${recordTag}> n° ${index}`);
    opening.lastIndex = end + closingTag.length;
  }
}
