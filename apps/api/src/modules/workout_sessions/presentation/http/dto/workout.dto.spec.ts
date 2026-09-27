import { plainToInstance } from 'class-transformer';
import { validateSync } from 'class-validator';
import { CreateWorkoutSetDto, UpdateWorkoutSetDto } from './workout-set.dto';
import { CreateWorkoutSessionDto } from './workout.dto';

/**
 * CE QUE CE FICHIER PROTÈGE : une horloge d'appareil remise à une date
 * d'usine ne rend pas une séance insynchronisable.
 *
 * Une borne basse (« rien avant 2020 ») avait été posée sur le début de
 * séance et la fin de série. Or la file de synchronisation traite tout 4xx
 * comme DÉFINITIF : la séance datée du 1er janvier 2000 par un téléphone
 * resté sans réseau ne quittait jamais l'appareil, et ses séries non plus.
 * Elle ne protégeait rien : le crédit est borné au créneau de 24 h
 * (`creditedEffort`), et la ligue n'ouvre pas une semaine close. Seul le
 * futur aberrant reste refusé.
 */

type Dto = new () => object;

function champsFautifs(dto: Dto, payload: Record<string, unknown>): string[] {
  return validateSync(plainToInstance(dto, payload), {
    whitelist: true,
    forbidNonWhitelisted: true,
  }).map((erreur) => erreur.property);
}

const DATE_D_USINE = '2000-01-01T00:00:00.000Z';
const FUTUR = '2099-06-15T12:00:00.000Z';
const seance = { id: '1f0c1b2e-3d4a-4b5c-8d6e-7f8091a2b3c4' };
const serie = { id: '2f0c1b2e-3d4a-4b5c-8d6e-7f8091a2b3c4', position: 0 };

describe('Dates posées par l’appareil', () => {
  it('une séance commencée à une date d’usine reste acceptée', () => {
    expect(champsFautifs(CreateWorkoutSessionDto, { ...seance, startedAt: DATE_D_USINE })).toEqual(
      [],
    );
  });

  it('une série finie à une date d’usine reste acceptée, à la création comme à la correction', () => {
    expect(champsFautifs(CreateWorkoutSetDto, { ...serie, completedAt: DATE_D_USINE })).toEqual([]);
    expect(champsFautifs(UpdateWorkoutSetDto, { completedAt: DATE_D_USINE })).toEqual([]);
  });

  it('le futur aberrant reste refusé', () => {
    expect(champsFautifs(CreateWorkoutSessionDto, { ...seance, startedAt: FUTUR })).toEqual([
      'startedAt',
    ]);
    expect(champsFautifs(CreateWorkoutSetDto, { ...serie, completedAt: FUTUR })).toEqual([
      'completedAt',
    ]);
    expect(champsFautifs(UpdateWorkoutSetDto, { completedAt: FUTUR })).toEqual(['completedAt']);
  });
});
