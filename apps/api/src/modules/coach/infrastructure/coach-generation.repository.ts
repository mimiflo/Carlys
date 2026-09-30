import { Injectable } from '@nestjs/common';
import { type CoachGenerationStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

export interface GenerationStart {
  id: string;
  userId: string;
  conversationId: string;
  messageId: string;
}

export interface GenerationEnd {
  status: Extract<CoachGenerationStatus, 'COMPLETED' | 'FAILED' | 'CANCELLED'>;
  inputTokens?: number;
  outputTokens?: number;
  model?: string;
  worker?: string;
  errorCode?: string;
}

/** Ce que l'état de santé dit de la dernière heure, tous exemplaires confondus. */
export interface GenerationStats {
  completed: number;
  failed: number;
  cancelled: number;
  avgQueueWaitMs: number | null;
  avgGenerationMs: number | null;
  avgTimeToFirstTokenMs: number | null;
}

/**
 * Les mesures des générations (ADR 0013) : des instants et des compteurs,
 * jamais le texte. Une écriture ratée ici ne doit jamais faire échouer une
 * réponse : la passerelle journalise et continue.
 */
@Injectable()
export class CoachGenerationRepository {
  constructor(private readonly prisma: PrismaService) {}

  async queued(start: GenerationStart): Promise<void> {
    await this.prisma.coachGeneration.create({ data: start });
  }

  // `updateMany` gardé par le statut : une écriture intermédiaire en retard
  // n'écrase jamais un statut final déjà posé.
  async started(id: string, at: Date): Promise<void> {
    await this.prisma.coachGeneration.updateMany({
      where: { id, status: 'QUEUED' },
      data: { status: 'PROCESSING', startedAt: at },
    });
  }

  async streaming(id: string, at: Date): Promise<void> {
    await this.prisma.coachGeneration.updateMany({
      where: { id, status: { in: ['QUEUED', 'PROCESSING'] } },
      data: { status: 'STREAMING', firstTokenAt: at },
    });
  }

  async ended(id: string, at: Date, end: GenerationEnd): Promise<void> {
    await this.prisma.coachGeneration.update({
      where: { id },
      data: { ...end, completedAt: at },
    });
  }

  async statsSince(since: Date): Promise<GenerationStats> {
    const [row] = await this.prisma.$queryRaw<
      {
        completed: bigint;
        failed: bigint;
        cancelled: bigint;
        wait: number | null;
        generation: number | null;
        ttft: number | null;
      }[]
    >(Prisma.sql`
      SELECT
        count(*) FILTER (WHERE status = 'COMPLETED') AS completed,
        count(*) FILTER (WHERE status = 'FAILED') AS failed,
        count(*) FILTER (WHERE status = 'CANCELLED') AS cancelled,
        avg(extract(epoch FROM "startedAt" - "createdAt") * 1000)::float AS wait,
        avg(extract(epoch FROM "completedAt" - "startedAt") * 1000)
          FILTER (WHERE status = 'COMPLETED')::float AS generation,
        avg(extract(epoch FROM "firstTokenAt" - "startedAt") * 1000)::float AS ttft
      FROM "CoachGeneration"
      WHERE "createdAt" >= ${since}
    `);
    const rounded = (value: number | null | undefined) =>
      value === null || value === undefined ? null : Math.round(value);
    return {
      completed: Number(row?.completed ?? 0),
      failed: Number(row?.failed ?? 0),
      cancelled: Number(row?.cancelled ?? 0),
      avgQueueWaitMs: rounded(row?.wait),
      avgGenerationMs: rounded(row?.generation),
      avgTimeToFirstTokenMs: rounded(row?.ttft),
    };
  }
}
