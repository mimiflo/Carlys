import { PROGRAM_FREE_LIMIT, type ProgramDetail, type ProgramSummary } from '@carlys/api-contracts';
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { type Prisma } from '@prisma/client';
import { EntitlementsService } from '../../subscriptions/application/entitlements.service';
import { ProgramsRepository } from '../infrastructure/programs.repository';
import { presentProgramDetail, presentProgramSummary } from './program.presenter';

export interface ProgramDayInput {
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
  days: ProgramDayInput[];
}

export interface ProgramsPage {
  items: ProgramSummary[];
  nextCursor: string | null;
  hasMore: boolean;
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

  async list(userId: string, limit: number, cursor?: string): Promise<ProgramsPage> {
    const rows = await this.programs.listPage(userId, limit, cursor);
    const hasMore = rows.length > limit;
    const items = rows.slice(0, limit).map(presentProgramSummary);
    return {
      items,
      hasMore,
      nextCursor: hasMore ? (items.at(-1)?.id ?? null) : null,
    };
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
