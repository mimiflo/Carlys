/**
 * La PAIRE ordonnée que forment deux personnes.
 *
 * Une amitié n'a pas de sens : « A et B » est le même lien que « B et A ».
 * La base, elle, ne sait rendre unique qu'un couple de colonnes dans un
 * ordre donné — d'où ces deux identifiants toujours rangés pareil, quel que
 * soit celui qui a demandé. C'est ce qui permet à PostgreSQL de refuser la
 * seconde ligne quand les deux personnes se demandent en même temps, là où
 * une lecture suivie d'une écriture laissait passer les deux.
 */
export interface FriendshipPair {
  readonly userLowId: string;
  readonly userHighId: string;
}

export function friendshipPair(a: string, b: string): FriendshipPair {
  return a < b ? { userLowId: a, userHighId: b } : { userLowId: b, userHighId: a };
}
