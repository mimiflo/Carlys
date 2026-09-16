import { AGE_YEARS_MAX, AGE_YEARS_MIN } from '@carlys/api-contracts';
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

  it('reste facultative : un profil sans date de naissance est valide', () => {
    expect(champsFautifs({ displayName: 'Camille' })).toEqual([]);
  });
});
