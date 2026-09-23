import { codePointLength } from '@carlys/api-contracts';
import { registerDecorator, type ValidationOptions } from 'class-validator';

/**
 * Le texte tient en `max` POINTS DE CODE Unicode : la même unité que le
 * contrat Zod publié (`codePointLength`, dans `@carlys/api-contracts`), et
 * que `maxLength` en JSON Schema, donc que Swagger.
 *
 * Pas `@MaxLength` : validator.js y compte une paire de substitution pour un
 * mais efface les sélecteurs de variante (U+FE0E, U+FE0F) qui suivent un
 * caractère. Le contrat comptait, lui, les unités UTF-16. La même constante
 * donnait donc deux règles : l'API acceptait `'😀'.repeat(280)` que le
 * contrat refusait dès 141, et `'❤️'.repeat(280)` (560 unités) passait
 * pour « 280 caractères ».
 *
 * Ne se prononce que sur les chaînes : `@IsString()` refuse le reste, et
 * `@IsOptional()` laisse passer `null`. À poser APRÈS `@Transform(trimmed)`
 * quand le contrat découpe avant de mesurer.
 */
export function MaxCodePoints(max: number, options?: ValidationOptions): PropertyDecorator {
  return function (object: object, propertyName: string | symbol): void {
    registerDecorator({
      name: 'maxCodePoints',
      target: object.constructor,
      propertyName: propertyName as string,
      constraints: [max],
      options: {
        message: `${String(propertyName)} : ${max} caractères au plus.`,
        ...options,
      },
      validator: {
        validate: (value: unknown) => typeof value !== 'string' || codePointLength(value) <= max,
      },
    });
  };
}
