/**
 * Élague une chaîne AVANT que les validateurs ne la mesurent.
 *
 * L'ordre compte : sans cette transformation, `@MinLength(1)` accepte trois
 * espaces, et `@MaxLength(120)` refuse un nom de 119 caractères suivi d'un
 * espace. Les contrats Zod du paquet partagé élaguent, eux, avant de mesurer
 * (`z.string().trim().min(1)`) : l'API doit dire la même chose que le contrat
 * qu'elle publie.
 *
 * Extrait de `workout-template.dto.ts`, où il vivait seul : le module jumeau
 * des programmes en avait besoin, et recopier trois lignes est le début d'une
 * divergence.
 *
 * Laisse passer ce qui n'est pas une chaîne — c'est au validateur de type de
 * le refuser, pas à une transformation de le déguiser.
 */
export const trimmed = ({ value }: { value: unknown }): unknown =>
  typeof value === 'string' ? value.trim() : value;
