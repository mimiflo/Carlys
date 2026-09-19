import { registerDecorator, type ValidationOptions } from 'class-validator';

/**
 * Le champ ne porte pas plus de `decimals` décimales — jugé sur la VALEUR,
 * jamais sur son écriture.
 *
 * `@IsNumber({ maxDecimalPlaces })` compte les chiffres de `toString()` :
 * `175.10000000000002`, artefact flottant d'une conversion d'unités côté
 * client, y devient « 14 décimales » et prend un 400 — alors que le contrat
 * (`heightCmSchema`) l'accepte explicitement, son commentaire précisant que
 * le contrôle se fait sur la valeur arrondie, « jamais sur l'écriture
 * décimale ». Ici, même règle que le contrat : la valeur est bonne si elle
 * coïncide (à 1e-9 près) avec son arrondi au pas demandé.
 */
export function HasDecimalPrecision(
  decimals: number,
  options?: ValidationOptions,
): PropertyDecorator {
  const scale = 10 ** decimals;
  return function (object: object, propertyName: string | symbol): void {
    registerDecorator({
      name: 'hasDecimalPrecision',
      target: object.constructor,
      propertyName: propertyName as string,
      options: {
        message: `Au plus ${decimals} décimale${decimals > 1 ? 's' : ''}.`,
        ...options,
      },
      validator: {
        validate: (value: unknown) =>
          typeof value === 'number' &&
          Number.isFinite(value) &&
          Math.abs(value * scale - Math.round(value * scale)) < 1e-9,
      },
    });
  };
}
