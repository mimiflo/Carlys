import { type ProgramCalendarDay, type ProgramCalendarWeek } from '@carlys/api-contracts';
import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { type ProgramDay } from '@prisma/client';
import { dayKeyInZone, dayKeyOfColumn } from '../../../common/utilities/civil-day';
import { safeTimeZone } from '../../../common/utilities/time-zone';
import { anchorOf, dateOfSlot, statusOfSlot, weekOfDate } from '../domain/calendar-dates';
import { ProgramsRepository } from '../infrastructure/programs.repository';

/**
 * LE CALENDRIER DATÉ d'un programme — une semaine à la fois.
 *
 * Un programme sans `startsOn` n'a pas de calendrier, et c'est un refus
 * NOMMÉ (400), pas une semaine vide : « ce programme n'a pas encore de date
 * de début » se corrige en deux gestes, « aucune séance » ne se corrige pas
 * du tout.
 *
 * Rien n'est stocké ici. « Fait » découle du lien séance → jour, « manqué »
 * de la date et du fuseau de la personne, « hors période » du départ réel.
 * Trois déductions, zéro colonne d'état — donc rien qui puisse mentir après
 * coup, ni qu'il faille réconcilier quand une séance est supprimée.
 */
@Injectable()
export class ProgramCalendarService {
  constructor(private readonly programs: ProgramsRepository) {}

  async week(
    programId: string,
    userId: string,
    weekNumber: number | undefined,
  ): Promise<ProgramCalendarWeek> {
    const program = await this.programs.findById(programId);
    // Inconnu, supprimé ou à autrui : 404 dans les trois cas, comme partout
    // ailleurs dans ce module.
    if (program === null || program.deletedAt !== null || program.userId !== userId) {
      throw new NotFoundException('Programme introuvable.');
    }
    if (program.startsOn === null) {
      throw new BadRequestException(
        'Ce programme n’a pas de date de début : choisis-en une pour ouvrir son calendrier.',
      );
    }

    const startsOn = dayKeyOfColumn(program.startsOn);
    const anchor = anchorOf(startsOn);
    // Le fuseau décide ce que « déjà passé » veut dire : une séance du mardi
    // soir à Paris ne doit pas devenir « manquée » parce qu'il est déjà
    // mercredi à Greenwich.
    const today = dayKeyInZone(new Date(), safeTimeZone(await this.programs.userTimeZone(userId)));
    const currentWeek = weekOfDate(anchor, program.weeksCount, today);
    // Sans semaine demandée, on ouvre sur CELLE D'AUJOURD'HUI : trois
    // semaines après le départ, personne ne veut relire la semaine 1.
    const semaine = weekNumber ?? currentWeek ?? 1;
    if (semaine < 1 || semaine > program.weeksCount) {
      throw new BadRequestException(
        `Semaine ${semaine} hors du programme (${program.weeksCount} semaines).`,
      );
    }

    const { days, doneByDayId } = await this.programs.weekWithSessions(programId, userId, semaine);
    const parJour = new Map(days.map((day) => [day.dayOfWeek, day]));

    return {
      programId: program.id,
      name: program.name,
      weeksCount: program.weeksCount,
      startsOn,
      weekNumber: semaine,
      currentWeek,
      today,
      // SEPT jours, toujours : un calendrier qui saute les jours vides n'est
      // plus un calendrier, et l'écran ne saurait plus où poser la colonne du
      // mercredi.
      days: [1, 2, 3, 4, 5, 6, 7].map((dayOfWeek) =>
        this.presentDay({
          day: parJour.get(dayOfWeek),
          weekNumber: semaine,
          dayOfWeek,
          date: dateOfSlot(anchor, semaine, dayOfWeek),
          sessionId: doneByDayId,
          startsOn,
          today,
        }),
      ),
    };
  }

  private presentDay(input: {
    day: ProgramDay | undefined;
    weekNumber: number;
    dayOfWeek: number;
    date: string;
    sessionId: Map<string, string>;
    startsOn: string;
    today: string;
  }): ProgramCalendarDay {
    const done = input.day === undefined ? undefined : input.sessionId.get(input.day.id);
    return {
      id: input.day?.id ?? null,
      weekNumber: input.weekNumber,
      dayOfWeek: input.dayOfWeek,
      templateId: input.day?.templateId ?? null,
      label: input.day?.label ?? null,
      isRest: input.day?.isRest ?? false,
      date: input.date,
      status: statusOfSlot({
        date: input.date,
        planned: input.day !== undefined,
        isRest: input.day?.isRest ?? false,
        done: done !== undefined,
        startsOn: input.startsOn,
        today: input.today,
      }),
      sessionId: done ?? null,
    };
  }
}
