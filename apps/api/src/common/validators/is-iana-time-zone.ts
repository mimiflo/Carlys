import { registerDecorator, type ValidationOptions } from 'class-validator';
import { isIanaTimeZone } from '../utilities/time-zone';

/**
 * Le champ doit porter un identifiant de fuseau IANA reconnu.
 *
 * `@IsString() @Length(1, 60)` laissait passer n'importe quoi. Ce n'est pas
 * une coquetterie : le fuseau sert à découper les journées d'entraînement en
 * base (`date_trunc(… AT TIME ZONE …)`), et PostgreSQL refuse un fuseau
 * inconnu — une chaîne fantaisiste écrite ici transformait la lecture des
 * statistiques en erreur serveur.
 */
export function IsIanaTimeZone(options?: ValidationOptions): PropertyDecorator {
  return function (object: object, propertyName: string | symbol): void {
    registerDecorator({
      name: 'isIanaTimeZone',
      target: object.constructor,
      propertyName: propertyName as string,
      options: {
        message: 'Fuseau horaire inconnu (identifiant IANA attendu, ex. Europe/Paris).',
        ...options,
      },
      validator: {
        validate: (value: unknown) => isIanaTimeZone(value),
      },
    });
  };
}
