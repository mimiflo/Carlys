import { type ProgramDetail, type ProgramSummary } from '@carlys/api-contracts';
import { type ProgramWithDays } from '../infrastructure/programs.repository';

export function presentProgramSummary(program: ProgramWithDays): ProgramSummary {
  return {
    id: program.id,
    name: program.name,
    description: program.description,
    weeksCount: program.weeksCount,
    isActive: program.isActive,
    daysCount: program.days.length,
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
