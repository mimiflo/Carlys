import { type HealthComponent } from '@carlys/api-contracts';
import { Injectable } from '@nestjs/common';
import { withTimeout } from '../../../common/utilities/with-timeout';
import { PrismaService } from '../../../database/prisma/prisma.service';

const PROBE_TIMEOUT_MS = 2_000;

@Injectable()
export class DatabaseHealthProbe {
  readonly key = 'database';

  constructor(private readonly prisma: PrismaService) {}

  async check(): Promise<HealthComponent> {
    const startedAt = Date.now();
    try {
      await withTimeout(
        this.prisma.$queryRaw`SELECT 1`,
        PROBE_TIMEOUT_MS,
        'PostgreSQL',
      );
      return { status: 'up', latencyMs: Date.now() - startedAt };
    } catch (error) {
      return {
        status: 'down',
        error: error instanceof Error ? error.message : 'Erreur inconnue',
      };
    }
  }
}
