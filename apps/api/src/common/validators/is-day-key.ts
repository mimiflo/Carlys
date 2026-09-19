import { registerDecorator, type ValidationOptions } from 'class-validator';
import { isDayKey } from '../utilities/civil-day';

/**
 * Le champ porte un JOUR CIVIL `YYYY-MM-DD` qui existe vraiment.
 *
 * Sans parenté avec `IsRecentDayKey`, qui borne en plus le jour à la fenêtre
 * du serveur : ici aucune borne de temps, parce que la date de début d'un
 * programme est LIBRE — commencer lundi prochain est le cas normal, et
 * reprendre un plan commencé le mois dernier l'est aussi.
 *
 * « Qui existe vraiment » n'est pas une formule : le motif seul laisse
 * passer `2026-02-31`, que `Date` normalise silencieusement au 3 mars. Une
 * date corrigée en douce derrière le dos de la personne est pire qu'un refus.
 *
 * `null` est accepté et vaut « pas de date » : le décorateur ne se prononce
 * que sur les chaînes, `@IsOptional()` se charge du reste.
 */
export function IsDayKey(options?: ValidationOptions): PropertyDecorator {
  return function (object: object, propertyName: string | symbol): void {
    registerDecorator({
      name: 'isDayKey',
      target: object.constructor,
      propertyName: propertyName as string,
      options: {
        message: 'Jour attendu au format AAAA-MM-JJ, et réellement existant.',
        ...options,
      },
      validator: {
        validate: (value: unknown) => value === null || isDayKey(value),
      },
    });
  };
}
