/**
 * LE CURSEUR DE LA FRISE : `(occurredAt, id)`, jamais l'id seul.
 *
 * Les autres listes paginées du dépôt s'en tirent avec l'identifiant parce
 * qu'une SEULE table est triée. La frise fusionne quatre sources : deux
 * événements peuvent tomber à la même milliseconde, et un curseur sur l'id
 * seul sauterait des lignes ou les rejouerait, selon le côté du tri où
 * l'ex æquo se range.
 *
 * Base64 d'`<ISO8601>|<id>` : opaque pour l'appelant, et comparable
 * lexicographiquement côté SQL par le tuple `(occurred_at, id)`.
 */

const SEPARATEUR = '|';

export function encodeTimelineCursor(occurredAt: Date, id: string): string {
  return Buffer.from(`${occurredAt.toISOString()}${SEPARATEUR}${id}`, 'utf8').toString('base64url');
}

/**
 * Le couple, ou `null` si la chaîne ne veut rien dire.
 *
 * Un curseur illisible se traite comme ABSENT — on repart du début plutôt
 * que de refuser la lecture. Un curseur est une position, pas une
 * autorisation : le rejeter en 400 ferait échouer un écran pour une chaîne
 * tronquée par un partage de lien.
 */
export function decodeTimelineCursor(cursor?: string): { occurredAt: Date; id: string } | null {
  if (cursor === undefined || cursor === '') {
    return null;
  }
  const decode = Buffer.from(cursor, 'base64url').toString('utf8');
  const coupure = decode.indexOf(SEPARATEUR);
  if (coupure <= 0) {
    return null;
  }
  const occurredAt = new Date(decode.slice(0, coupure));
  const id = decode.slice(coupure + 1);
  if (Number.isNaN(occurredAt.getTime()) || id === '') {
    return null;
  }
  return { occurredAt, id };
}
