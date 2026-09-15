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
 *
 * Le message NOMME le cas qui arrive vraiment. Un téléphone dont le fuseau
 * est réglé sur un décalage brut renvoie `+05:30` ou `-08:00`, et ICU les
 * accepte depuis sa version 72 : c'est par là que le contrôle fuyait. Dire
 * « inconnu » à qui envoie `+05:30` l'enverrait chercher une faute de frappe
 * dans une valeur parfaitement lisible.
 */
export function IsIanaTimeZone(options?: ValidationOptions): PropertyDecorator {
  return function (object: object, propertyName: string | symbol): void {
    registerDecorator({
      name: 'isIanaTimeZone',
      target: object.constructor,
      propertyName: propertyName as string,
      options: {
        message:
          'Fuseau horaire invalide : un identifiant IANA est attendu (ex. Europe/Paris). ' +
          'Un décalage seul (+05:30, -08:00) n’en est pas un.',
        ...options,
      },
      validator: {
        validate: (value: unknown) => isIanaTimeZone(value),
      },
    });
  };
}
