import { type ApiErrorDetail } from '@carlys/api-contracts';
import { BadRequestException } from '@nestjs/common';
import { type ValidationError } from 'class-validator';

/**
 * Le CHAMP fautif, enfin transmis.
 *
 * Le contrat publie `details[].field` depuis l'origine — et il n'était JAMAIS
 * posé. Le filtre d'exceptions ne recevait de `ValidationPipe` qu'un tableau
 * de phrases déjà aplaties, sans savoir à quoi les rattacher ; il les rendait
 * telles quelles sous un message générique. Le client mobile, lui, lit bien
 * `field` (`api_error_mapper.dart` remplit `fieldErrors`) : le chaînon
 * manquant était ici.
 *
 * Ce que cela change pour l'utilisateur : l'API écrit des messages destinés
 * à un humain (« Adresse e-mail invalide. »), qui restaient inatteignables
 * derrière « Certaines données sont invalides. ».
 */
export function flattenValidationErrors(
  errors: readonly ValidationError[],
  prefix = '',
): ApiErrorDetail[] {
  const details: ApiErrorDetail[] = [];
  for (const error of errors) {
    // Chemin pointé, comme le corps l'est : `days.0.label`. Un champ imbriqué
    // sans son chemin ne désignerait rien pour un formulaire.
    const field = prefix === '' ? error.property : `${prefix}.${error.property}`;
    for (const message of Object.values(error.constraints ?? {})) {
      details.push({ field, message });
    }
    if (error.children !== undefined && error.children.length > 0) {
      details.push(...flattenValidationErrors(error.children, field));
    }
  }
  return details;
}

/**
 * Remplace la fabrique par défaut de `ValidationPipe`.
 *
 * Le message reste générique EXPRÈS : il s'affiche en tête de formulaire,
 * au-dessus des messages de champ, et répéter le premier d'entre eux y
 * ferait doublon. Le détail, lui, est désormais exploitable champ par champ.
 */
export function validationExceptionFactory(errors: ValidationError[]): BadRequestException {
  return new BadRequestException({
    message: 'Certaines données sont invalides.',
    details: flattenValidationErrors(errors),
  });
}
