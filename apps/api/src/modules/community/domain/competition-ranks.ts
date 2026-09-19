/**
 * Le classement SPORTIF standard, et il n'en existe qu'une copie.
 *
 * À score ÉGAL, même rang, et le suivant saute : deux personnes à 12 séances
 * sont deuxièmes ex æquo, la suivante est quatrième. Départager par
 * l'identifiant serait un tirage au sort déguisé — celui dont l'UUID commence
 * par un `0` gagnerait toujours.
 *
 * Partagé par les défis entre amis et les ligues, parce que deux copies
 * divergeraient exactement sur l'ex æquo, qui est le seul endroit où la règle
 * demande à réfléchir.
 */
export function competitionRanks<T>(
  entries: readonly T[],
  scoreOf: (entry: T) => number,
  keyOf: (entry: T) => string,
): Map<string, number> {
  const classes = [...entries].sort((a, b) => scoreOf(b) - scoreOf(a));

  const rangs = new Map<string, number>();
  let rang = 0;
  let precedent: number | null = null;
  classes.forEach((entry, index) => {
    const score = scoreOf(entry);
    if (precedent === null || score !== precedent) {
      rang = index + 1;
      precedent = score;
    }
    rangs.set(keyOf(entry), rang);
  });
  return rangs;
}
