/**
 * Où vit la photo d'un repas dans le bucket privé.
 *
 * `meal-photos/<userId>/<uuid>.jpg` :
 * - un UUID NEUF à chaque dépôt, jamais le nom du fichier envoyé ni
 *   l'identifiant du repas : une clé ne se devine pas, et remplacer une
 *   photo n'écrase jamais l'objet qu'une lecture en cours est en train de
 *   servir ;
 * - un préfixe PAR PERSONNE : supprimer un compte efface tout ce préfixe,
 *   y compris un objet qu'aucune ligne ne cite plus (dépôt interrompu,
 *   suppression manquée). L'identifiant de compte y est un UUID, sans rien
 *   qui nomme la personne.
 */
export const MEAL_PHOTO_PREFIX = 'meal-photos/';

export function mealPhotoPrefixOf(userId: string): string {
  return `${MEAL_PHOTO_PREFIX}${userId}/`;
}

export function mealPhotoKey(userId: string, photoId: string): string {
  return `${mealPhotoPrefixOf(userId)}${photoId}.jpg`;
}
