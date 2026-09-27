/**
 * Contraintes de mot de passe — compatibles gestionnaires de mots de passe.
 *
 * Dans un module SANS Zod, à dessein : la page publique de réinitialisation
 * (`apps/admin`, ouverte sur téléphone depuis un e-mail) n'a besoin que de
 * ces deux nombres. Les importer depuis `auth.ts` y faisait charger tout Zod
 * et tous les contrats, pour deux constantes. `auth.ts` les réexporte : pour
 * tout le reste du dépôt, rien ne change.
 */
export const PASSWORD_MIN_LENGTH = 10;
export const PASSWORD_MAX_LENGTH = 128;
