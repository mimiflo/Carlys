import {
  type ProgramSummaryRow,
  type ProgramWithDays,
} from '../infrastructure/programs.repository';
import { presentProgramSummary } from './program.presenter';

/**
 * CE QUE CE FICHIER PROTÈGE : que la LISTE des programmes n'aille pas
 * chercher ce qu'elle ne montre pas.
 *
 * Le résumé n'affiche qu'un NOMBRE de jours, mais la liste chargeait les
 * jours eux-mêmes pour le calculer — jusqu'à 7 lignes par semaine et par
 * programme, sur chaque page. Le compte se demande à PostgreSQL (`_count`) ;
 * le détail, lui, a déjà ses jours sous la main et les compte sans requête
 * supplémentaire. Les deux formes doivent rendre le même nombre.
 */

const BASE = {
  id: 'programme-1',
  userId: 'user-1',
  name: 'Prise de masse',
  description: null,
  weeksCount: 4,
  isActive: true,
  startsOn: null,
  createdAt: new Date('2026-01-01T00:00:00.000Z'),
  updatedAt: new Date('2026-01-02T00:00:00.000Z'),
  deletedAt: null,
};

describe('presentProgramSummary', () => {
  it('compte les jours SANS les charger quand la ligne vient de la liste', () => {
    const row = { ...BASE, _count: { days: 12 } } as unknown as ProgramSummaryRow;

    expect(presentProgramSummary(row)).toMatchObject({ id: 'programme-1', daysCount: 12 });
  });

  it('les deux formes de ligne rendent le MÊME résumé', () => {
    const fromList = { ...BASE, _count: { days: 2 } } as unknown as ProgramSummaryRow;
    const fromDetail = {
      ...BASE,
      days: [{ id: 'j-1' }, { id: 'j-2' }],
    } as unknown as ProgramWithDays;

    expect(presentProgramSummary(fromList)).toEqual(presentProgramSummary(fromDetail));
  });

  it('un programme sans aucun jour rend zéro, pas une absence', () => {
    const row = { ...BASE, _count: { days: 0 } } as unknown as ProgramSummaryRow;

    expect(presentProgramSummary(row).daysCount).toBe(0);
  });

  it('rend la date de début en JOUR CIVIL, pas en instant', () => {
    const row = {
      ...BASE,
      startsOn: new Date('2026-09-21T00:00:00.000Z'),
      _count: { days: 0 },
    } as unknown as ProgramSummaryRow;

    // Une chaîne `YYYY-MM-DD`, jamais un ISO 8601 complet : le client
    // applique `.toLocal()` à tout ce qui ressemble à un instant, et le 21
    // deviendrait le 20 à l'ouest de Greenwich.
    expect(presentProgramSummary(row).startsOn).toBe('2026-09-21');
  });
});
