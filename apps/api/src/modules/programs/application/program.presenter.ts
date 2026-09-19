import { type ProgramDetail, type ProgramSummary } from '@carlys/api-contracts';
import { dayKeyOfColumn } from '../../../common/utilities/civil-day';
import {
  type ProgramSummaryRow,
  type ProgramWithDays,
} from '../infrastructure/programs.repository';

/**
 * Le nombre de jours, qu'il vienne du COMPTE de la liste ou des jours
 * chargés par le détail : les deux formes de ligne disent la même chose,
 * sans que la liste ait à rapatrier ce qu'elle ne montre pas.
 */
function daysCountOf(program: ProgramSummaryRow | ProgramWithDays): number {
  return '_count' in program ? program._count.days : program.days.length;
}

export function presentProgramSummary(
  program: ProgramSummaryRow | ProgramWithDays,
): ProgramSummary {
  return {
    id: program.id,
    name: program.name,
    description: program.description,
    weeksCount: program.weeksCount,
    isActive: program.isActive,
    // Un JOUR CIVIL, pas un instant : servi en ISO 8601 complet, le client
    // lui appliquerait son `.toLocal()` habituel et le 21 deviendrait le 20
    // à l'ouest de Greenwich.
    startsOn: program.startsOn === null ? null : dayKeyOfColumn(program.startsOn),
    daysCount: daysCountOf(program),
    updatedAt: program.updatedAt.toISOString(),
  };
}

export function presentProgramDetail(program: ProgramWithDays): ProgramDetail {
  return {
    ...presentProgramSummary(program),
    days: program.days.map((day) => ({
      id: day.id,
      weekNumber: day.weekNumber,
      dayOfWeek: day.dayOfWeek,
      templateId: day.templateId,
      label: day.label,
      isRest: day.isRest,
    })),
  };
}
