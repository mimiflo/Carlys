import { PROGRAM_FREE_LIMIT, type ProgramDetail, type ProgramSummary } from '@carlys/api-contracts';
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { type Prisma } from '@prisma/client';
import { columnOfDayKey, dayKeyOfColumn } from '../../../common/utilities/civil-day';
import { EntitlementsService } from '../../subscriptions/application/entitlements.service';
import { anchorOf, dateOfSlot } from '../domain/calendar-dates';
import { ProgramsRepository, type ProgramWithDays } from '../infrastructure/programs.repository';
import { presentProgramDetail, presentProgramSummary } from './program.presenter';
import { type CursorPage, cursorPage } from '../../../common/utilities/cursor-page';

interface ProgramDayInput {
  id: string;
  weekNumber: number;
  dayOfWeek: number;
  templateId?: string | null;
  label?: string | null;
  isRest?: boolean;
}

export interface SaveProgramInput {
  name: string;
  description?: string | null;
  weeksCount: number;
  isActive?: boolean;
  /** Jour civil `YYYY-MM-DD`, ou `null` pour un programme sans calendrier. */
  startsOn?: string | null;
  days: ProgramDayInput[];
}

export interface SavedProgram {
  /** 201 à la création, 200 au remplacement. */
  created: boolean;
  program: ProgramDetail;
}

/**
 * Programmes multi-semaines : le plan dans le TEMPS.
 *
 * Même mécanique d'écriture que les modèles de séance — identifiants venus de
 * l'appareil, `PUT` de remplacement complet en une transaction — donc un rejeu
 * après coupure redonne le même état sans journal d'idempotence.
 */
@Injectable()
export class ProgramsService {
  constructor(
    private readonly programs: ProgramsRepository,
    private readonly entitlements: EntitlementsService,
  ) {}

  async list(userId: string, limit: number, cursor?: string): Promise<CursorPage<ProgramSummary>> {
    const rows = await this.programs.listPage(userId, limit, cursor);
    return cursorPage(rows, limit, presentProgramSummary);
  }

  /** Nom du programme en cours, ou `null` s'il n'y en a pas. */
  activeProgramName(userId: string): Promise<string | null> {
    return this.programs.findActiveName(userId);
  }

  async detail(id: string, userId: string): Promise<ProgramDetail> {
    const program = await this.programs.findById(id);
    // Inconnu, supprimé ou à autrui : 404 dans les TROIS cas — répondre 403
    // pour le programme d'un autre révélerait qu'il existe.
    if (program === null || program.deletedAt !== null || program.userId !== userId) {
      throw new NotFoundException('Programme introuvable.');
    }
    return presentProgramDetail(program);
  }

  async save(id: string, userId: string, input: SaveProgramInput): Promise<SavedProgram> {
    const existing = await this.programs.findById(id);
    if (existing !== null && existing.userId !== userId) {
      throw new ConflictException('Cet identifiant appartient à un autre compte.');
    }
    if (existing !== null && existing.deletedAt !== null) {
      throw new NotFoundException('Programme supprimé.');
    }

    const isCreation = existing === null;
    if (isCreation) {
      await this.assertQuota(userId);
    } else {
      await this.assertDoneDaysStay(existing, userId, input);
    }

    const days = await this.buildDays(id, userId, input);

    const saved = await this.programs.save(
      {
        id,
        userId,
        name: input.name,
        description: input.description ?? null,
        weeksCount: input.weeksCount,
        isActive: input.isActive ?? false,
        // Le `PUT` décrit l'état COMPLET : une date absente du corps est une
        // date retirée, comme un jour absent de `days` est un jour retiré.
        startsOn: input.startsOn == null ? null : columnOfDayKey(input.startsOn),
      },
      days,
      input.isActive ?? false,
    );
    return { created: isCreation, program: presentProgramDetail(saved) };
  }

  async remove(id: string, userId: string): Promise<void> {
    const program = await this.programs.findById(id);
    // Rejouable : inconnu ou déjà supprimé → succès. Programme d'autrui → 404.
    if (program !== null && program.userId !== userId) {
      throw new NotFoundException('Programme introuvable.');
    }
    await this.programs.softDelete(id, userId);
  }

  /**
   * Une case HONORÉE par une séance terminée ne change plus de jour.
   *
   * « Fait » se déduit de l'identifiant de la case (`programDayId` de la
   * séance), pas de sa date : déplacer une case faite déplaçait donc la
   * séance dans le calendrier, qui annonçait un entraînement un jour où il
   * n'y en avait pas eu. `linkSession` refuse déjà de lier une séance à une
   * case d'une autre date ; le `PUT` du programme contournait cet invariant.
   * Garde de défense : l'application ne propose plus ce déplacement.
   *
   * DEUX GESTES déplacent une case, et la garde voit les deux. Changer sa
   * place dans la grille (semaine, jour de la semaine), d'abord. Changer le
   * premier jour (`startsOn`), ensuite : la date d'une case se DÉDUIT du
   * lundi de la semaine de départ ([anchorOf]), si bien que décaler le départ
   * d'une semaine décale toutes les cases d'autant, la faite avec (mesuré
   * avant correctif : la séance faite le 25/09 passait au 18/09 par le seul
   * réglage « Premier jour »). Daté avant ET après, c'est donc la DATE de la
   * case qui fait foi : un départ repris dans la même semaine garde le même
   * lundi, et rien ne bouge. Donner sa première date à un programme, ou la
   * lui retirer, ne revendique ni ne dément aucun jour : seule sa place dans
   * la grille reste gardée.
   */
  private async assertDoneDaysStay(
    existing: ProgramWithDays,
    userId: string,
    input: SaveProgramInput,
  ): Promise<void> {
    const done = await this.programs.completedDayIds(
      userId,
      existing.days.map((day) => day.id),
    );
    if (done.size === 0) return;
    const before = existing.startsOn === null ? null : anchorOf(dayKeyOfColumn(existing.startsOn));
    const after = input.startsOn == null ? null : anchorOf(input.startsOn);
    const next = new Map(input.days.map((day) => [day.id, day]));
    const kept = existing.days.flatMap((day) => {
      const target = next.get(day.id);
      return done.has(day.id) && target !== undefined ? [{ day, target }] : [];
    });
    const slotMoved = kept.some(
      ({ day, target }) =>
        target.weekNumber !== day.weekNumber || target.dayOfWeek !== day.dayOfWeek,
    );
    const moved =
      before !== null && after !== null
        ? kept.some(
            ({ day, target }) =>
              dateOfSlot(before, day.weekNumber, day.dayOfWeek) !==
              dateOfSlot(after, target.weekNumber, target.dayOfWeek),
          )
        : slotMoved;
    if (!moved) return;
    // Deux messages : celui qui touche au premier jour n'a déplacé aucune
    // case lui-même, il doit apprendre ce qui reste possible.
    throw new ConflictException(
      slotMoved
        ? 'Cette séance est déjà faite : sa case reste au jour où tu t’es entraîné.'
        : 'Une séance de ce programme est déjà faite : son premier jour ne peut plus changer que dans la même semaine.',
    );
  }

  /**
   * Plafond du plan gratuit. **Décision serveur**, jamais le client — et
   * seulement à la CRÉATION : un compte redevenu gratuit garde ses programmes
   * existants, il ne peut simplement plus en ajouter.
   */
  private async assertQuota(userId: string): Promise<void> {
    const unlimited = await this.entitlements.hasEntitlement(userId, 'unlimited_programs');
    if (unlimited) return;
    const count = await this.programs.countLive(userId);
    if (count >= PROGRAM_FREE_LIMIT) {
      throw new ForbiddenException(
        `Le plan gratuit garde ${PROGRAM_FREE_LIMIT} programmes. Passe Premium pour en créer davantage.`,
      );
    }
  }

  private async buildDays(
    programId: string,
    userId: string,
    input: SaveProgramInput,
  ): Promise<Prisma.ProgramDayCreateManyInput[]> {
    const seen = new Set<string>();
    for (const day of input.days) {
      if (day.weekNumber > input.weeksCount) {
        throw new BadRequestException(
          `Semaine ${day.weekNumber} hors du programme (${input.weeksCount} semaines).`,
        );
      }
      // La contrainte d'unicité existe en base ; la refuser ICI donne une
      // erreur lisible plutôt qu'un 500 venu de PostgreSQL.
      const slot = `${day.weekNumber}-${day.dayOfWeek}`;
      if (seen.has(slot)) {
        throw new BadRequestException(
          `Deux entrées pour la semaine ${day.weekNumber}, jour ${day.dayOfWeek}.`,
        );
      }
      seen.add(slot);
    }

    const requested = input.days
      .map((day) => day.templateId)
      .filter((id): id is string => typeof id === 'string');
    const owned = await this.programs.ownedTemplateIds(userId, requested);

    return input.days.map((day) => {
      // Un modèle inconnu, supprimé ou appartenant à autrui ne fait pas échouer
      // l'enregistrement : la case garde son intitulé et perd son lien. Le plan
      // reste lisible, ce qui compte plus que le lien.
      const templateId =
        day.templateId != null && owned.has(day.templateId) ? day.templateId : null;
      const isRest = day.isRest ?? false;
      const label = day.label?.trim();
      return {
        id: day.id,
        programId,
        weekNumber: day.weekNumber,
        dayOfWeek: day.dayOfWeek,
        templateId: isRest ? null : templateId,
        label: label !== undefined && label.length > 0 ? label : isRest ? 'Repos' : 'Séance',
        isRest,
      };
    });
  }
}
