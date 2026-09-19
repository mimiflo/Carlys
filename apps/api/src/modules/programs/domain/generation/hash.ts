/**
 * FNV-1a 32 bits — un hachage, pas un générateur aléatoire.
 *
 * Il sert la ROTATION : deux créneaux, deux semaines, deux programmes tombent
 * sur des décalages différents dans le pool d'exercices, donc la sélection
 * varie — sans qu'une seule valeur aléatoire n'entre dans le moteur. Rejouer
 * le calcul rend le même décalage, pour toujours, sur n'importe quelle
 * machine : c'est ce qui rend la génération reproductible et donc auditable.
 *
 * `Math.random()` aurait donné la même variété et l'aurait rendue
 * invérifiable : impossible de rejouer une génération pour expliquer un
 * programme, impossible de la tester par instantané.
 */
export function fnv1a32(text: string): number {
  let hash = 0x811c9dc5;
  for (let index = 0; index < text.length; index += 1) {
    hash ^= text.charCodeAt(index);
    // Multiplication par 16 777 619 en arithmétique 32 bits non signée.
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash >>> 0;
}

/**
 * Le décalage d'entrée dans un pool, pour un créneau et une semaine donnés.
 *
 * `seed` contient l'identifiant du programme ET tout le profil (voir
 * `seedOf`) : deux personnes au profil identique reçoivent donc des
 * programmes différents, et « régénérer » côté mobile revient à envoyer un
 * nouvel identifiant. Le déterminisme n'impose pas l'uniformité.
 */
export function rotationOffset(
  seed: string,
  slotIndex: number,
  week: number,
  poolSize: number,
): number {
  if (poolSize <= 0) return 0;
  return (fnv1a32(seed) + slotIndex * 31 + week * 7) % poolSize;
}
