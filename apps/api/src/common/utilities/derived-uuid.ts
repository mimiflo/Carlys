import { createHash } from 'node:crypto';

/**
 * UUID DÉRIVÉ d'une clé : reproductible, valide, sans registre.
 *
 * Deux appels avec la même clé rendent le même identifiant, sur n'importe
 * quelle machine et à n'importe quel moment. C'est ce qui rend une écriture
 * rejouable sans journal d'idempotence : le second passage écrase la même
 * ligne au lieu d'en créer une seconde.
 *
 * Le `namespace` sépare les familles d'identifiants. Deux clés identiques
 * sous deux namespaces distincts donnent deux UUID distincts — sans lui, le
 * média du slug « pompes » et un éventuel autre objet dérivé du même slug
 * entreraient en collision.
 *
 * L'UUID rendu se DÉCLARE version 4 alors qu'il n'est pas aléatoire. C'est
 * délibéré : PostgreSQL et Prisma exigent un UUID bien formé, et la version 5
 * (SHA-1) que la RFC destine à cet usage n'existe ni dans `node:crypto` ni
 * dans les dépendances du dépôt. Un UUID v5 maison serait une dépendance de
 * plus pour un résultat identique en pratique.
 *
 * Cette fonction vient du seed des médias, où elle était écrite à demeure
 * (`catalog-media-sync.ts`). Elle est remontée ici le jour où la génération
 * de programme en a eu besoin : une seule définition décide de la forme d'un
 * identifiant reproductible, plutôt que deux copies qui divergeront.
 */
export function derivedUuid(namespace: string, key: string): string {
  const hash = createHash('sha256').update(`${namespace}:${key}`).digest();
  const bytes = Buffer.from(hash.subarray(0, 16));
  // Version 4 et variante RFC 4122 : un UUID valide, mais reproductible.
  bytes[6] = (bytes[6]! & 0x0f) | 0x40;
  bytes[8] = (bytes[8]! & 0x3f) | 0x80;
  const hex = bytes.toString('hex');
  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    hex.slice(12, 16),
    hex.slice(16, 20),
    hex.slice(20),
  ].join('-');
}
