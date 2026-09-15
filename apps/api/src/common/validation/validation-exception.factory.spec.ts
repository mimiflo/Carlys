import { type ValidationError } from 'class-validator';
import {
  flattenValidationErrors,
  validationExceptionFactory,
} from './validation-exception.factory';

/**
 * CE QUE CE FICHIER PROTÈGE : le CHAMP fautif arrive jusqu'au client.
 *
 * `details[].field` figure au contrat depuis l'origine et n'était jamais
 * posé : le filtre d'exceptions ne recevait qu'un tableau de phrases
 * aplaties. Les messages que l'API écrit pour un humain (« Adresse e-mail
 * invalide. ») restaient donc inatteignables derrière un générique
 * « Certaines données sont invalides. », alors que le client mobile sait
 * déjà les ranger par champ.
 */

function erreur(
  property: string,
  constraints: Record<string, string>,
  children: ValidationError[] = [],
): ValidationError {
  return { property, constraints, children };
}

describe('flattenValidationErrors', () => {
  it('rattache chaque message à son champ', () => {
    const details = flattenValidationErrors([
      erreur('email', { isEmail: 'Adresse e-mail invalide.' }),
      erreur('password', { minLength: 'Mot de passe trop court.' }),
    ]);

    expect(details).toEqual([
      { field: 'email', message: 'Adresse e-mail invalide.' },
      { field: 'password', message: 'Mot de passe trop court.' },
    ]);
  });

  it('rend TOUTES les contraintes d’un même champ', () => {
    // Un champ peut violer plusieurs règles à la fois : n'en montrer qu'une
    // ferait corriger la première pour découvrir la suivante au renvoi.
    const details = flattenValidationErrors([
      erreur('name', { minLength: 'Trop court.', matches: 'Caractères interdits.' }),
    ]);

    expect(details).toHaveLength(2);
    expect(details.every((detail) => detail.field === 'name')).toBe(true);
  });

  it('un champ IMBRIQUÉ porte son chemin complet', () => {
    // Sans le chemin, « label » ne désigne rien dans un formulaire qui en
    // compte un par jour de programme.
    const details = flattenValidationErrors([
      erreur('days', {}, [erreur('0', {}, [erreur('label', { minLength: 'Intitulé requis.' })])]),
    ]);

    expect(details).toEqual([{ field: 'days.0.label', message: 'Intitulé requis.' }]);
  });

  it('un champ sans contrainte ni enfant ne produit rien', () => {
    expect(flattenValidationErrors([erreur('vide', {})])).toEqual([]);
  });
});

describe('validationExceptionFactory', () => {
  it('rend un 400 dont le corps porte le message générique ET les détails', () => {
    // Le message reste générique exprès : il coiffe le formulaire, au-dessus
    // des messages de champ, où répéter le premier ferait doublon.
    const exception = validationExceptionFactory([
      erreur('email', { isEmail: 'Adresse e-mail invalide.' }),
    ]);

    expect(exception.getStatus()).toBe(400);
    expect(exception.getResponse()).toEqual({
      message: 'Certaines données sont invalides.',
      details: [{ field: 'email', message: 'Adresse e-mail invalide.' }],
    });
  });
});
