import {
  AGE_YEARS_MAX,
  AGE_YEARS_MIN,
  TRAINING_EQUIPMENT_SLUG_MAX_LENGTH,
  updateProfileRequestSchema,
} from '@carlys/api-contracts';
import { plainToInstance } from 'class-transformer';
import { validateSync } from 'class-validator';
import { UpdateProfileDto } from './update-profile.dto';

/**
 * CE QUE CE FICHIER PROTÈGE : la date de naissance n'entre plus n'importe
 * quel âge dans Mifflin-St Jeor.
 *
 * Elle était bornée à deux endroits et testée à aucun : `@MaxDate(now)` au
 * DTO refusait le futur, et un `MAX_AGE_YEARS = 120` recopié dans
 * `users.service.ts` refusait les très vieux — mais le module n'a jamais eu
 * de `.spec.ts`, donc cette seconde règle ne reposait sur rien. Entre les
 * deux, un âge de 0 an passait, et `-5 × 0` entrait dans la formule.
 */

/** Une date de naissance correspondant à un âge révolu donné. */
function neIlYa(annees: number, decalageJours = 0): string {
  const date = new Date();
  date.setUTCFullYear(date.getUTCFullYear() - annees);
  date.setUTCDate(date.getUTCDate() + decalageJours);
  return date.toISOString();
}

function champsFautifs(payload: Record<string, unknown>): string[] {
  const dto = plainToInstance(UpdateProfileDto, payload);
  return validateSync(dto, { whitelist: true, forbidNonWhitelisted: true }).map(
    (erreur) => erreur.property,
  );
}

describe('UpdateProfileDto — date de naissance', () => {
  it('accepte un âge ordinaire', () => {
    expect(champsFautifs({ birthDate: neIlYa(30) })).toEqual([]);
  });

  it('refuse une date dans le futur', () => {
    expect(champsFautifs({ birthDate: neIlYa(-1) })).toEqual(['birthDate']);
  });

  it('refuse un nouveau-né — le cas qui passait les deux anciennes gardes', () => {
    expect(champsFautifs({ birthDate: neIlYa(0) })).toEqual(['birthDate']);
  });

  it(`refuse un âge sous ${AGE_YEARS_MIN} ans, accepte le jour même`, () => {
    // La veille des 15 ans : refusé. Le jour des 15 ans : accepté.
    expect(champsFautifs({ birthDate: neIlYa(AGE_YEARS_MIN, 1) })).toEqual(['birthDate']);
    expect(champsFautifs({ birthDate: neIlYa(AGE_YEARS_MIN) })).toEqual([]);
  });

  it(`refuse un âge au-dessus de ${AGE_YEARS_MAX} ans, accepte le jour même`, () => {
    expect(champsFautifs({ birthDate: neIlYa(AGE_YEARS_MAX, -1) })).toEqual(['birthDate']);
    expect(champsFautifs({ birthDate: neIlYa(AGE_YEARS_MAX) })).toEqual([]);
  });

  it('la borne est une JOURNÉE, pas un instant', () => {
    // Le défaut qui a rendu ce fichier vert en local et rouge en CI : la
    // date testée était construite quelques millisecondes AVANT que le
    // validateur ne recalcule sa borne, et « né il y a exactement 120 ans »
    // basculait d'un côté ou de l'autre selon ce délai.
    const minuit = new Date();
    minuit.setUTCFullYear(minuit.getUTCFullYear() - AGE_YEARS_MAX);
    minuit.setUTCHours(0, 0, 0, 0);
    expect(champsFautifs({ birthDate: minuit.toISOString() })).toEqual([]);

    const justeAvantMinuit = new Date(minuit.getTime() - 1);
    expect(champsFautifs({ birthDate: justeAvantMinuit.toISOString() })).toEqual(['birthDate']);

    const finDeJournee = new Date();
    finDeJournee.setUTCFullYear(finDeJournee.getUTCFullYear() - AGE_YEARS_MIN);
    finDeJournee.setUTCHours(23, 59, 59, 999);
    expect(champsFautifs({ birthDate: finDeJournee.toISOString() })).toEqual([]);

    const justeApres = new Date(finDeJournee.getTime() + 1);
    expect(champsFautifs({ birthDate: justeApres.toISOString() })).toEqual(['birthDate']);
  });

  it('reste facultative : un profil sans date de naissance est valide', () => {
    expect(champsFautifs({ displayName: 'Camille' })).toEqual([]);
  });

  it('refuse un booléen ou un nombre — `new Date(true)` donnait 1970, un âge valide', () => {
    expect(champsFautifs({ birthDate: true })).toEqual(['birthDate']);
    expect(champsFautifs({ birthDate: 12345 })).toEqual(['birthDate']);
  });

  it('refuse une chaîne qui n’est pas une date', () => {
    expect(champsFautifs({ birthDate: 'trente ans' })).toEqual(['birthDate']);
  });
});

describe('UpdateProfileDto — nom affiché', () => {
  it('refuse un nom fait d’espaces : le service le range trimé, donc vide', () => {
    expect(champsFautifs({ displayName: '   ' })).toEqual(['displayName']);
  });

  it('accepte un nom entouré d’espaces : il reste un nom une fois trimé', () => {
    expect(champsFautifs({ displayName: '  Camille  ' })).toEqual([]);
  });
});

describe('UpdateProfileDto — taille', () => {
  it('accepte l’artefact flottant d’une valeur à une décimale', () => {
    // 175.1 n'est pas représentable en binaire : un client qui convertit des
    // unités peut produire cette écriture pour LA MÊME valeur.
    expect(champsFautifs({ heightCm: 175.10000000000002 })).toEqual([]);
  });

  it('refuse deux vraies décimales', () => {
    expect(champsFautifs({ heightCm: 175.15 })).toEqual(['heightCm']);
  });
});

/**
 * CE QUE CE BLOC PROTÈGE : le contrat (`updateProfileRequestSchema`) et le
 * DTO jugent PAREIL. Rien d'autre dans le dépôt ne les confronte, et c'est
 * ainsi que trois dérives s'étaient installées (bornes de date absentes du
 * contrat, plafond de slug absent, précision de taille comptée sur
 * l'écriture au DTO).
 */
describe('Contrat ↔ DTO — le même verdict sur les mêmes cas', () => {
  const cas: Array<[string, Record<string, unknown>]> = [
    ['taille : artefact flottant d’une décimale', { heightCm: 175.10000000000002 }],
    ['taille : deux décimales', { heightCm: 175.15 }],
    ['naissance : dix ans, trop jeune', { birthDate: neIlYa(10) }],
    ['naissance : trente ans', { birthDate: neIlYa(30) }],
    [
      'matériel : slug trop long',
      { equipmentSlugs: ['a'.repeat(TRAINING_EQUIPMENT_SLUG_MAX_LENGTH + 1)] },
    ],
    ['matériel : slug légitime', { equipmentSlugs: ['barre-olympique'] }],
    ['nom : fait d’espaces', { displayName: '   ' }],
  ];

  it.each(cas)('%s', (_nom, payload) => {
    const contrat = updateProfileRequestSchema.safeParse(payload).success;
    const dto = champsFautifs(payload).length === 0;
    expect(dto).toBe(contrat);
  });
});
