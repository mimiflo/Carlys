import { type HealthComponent } from '@carlys/api-contracts';
import { Injectable } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { PrismaService } from '../../../database/prisma/prisma.service';
import { runProbe } from './run-probe';

@Injectable()
export class DatabaseHealthProbe {
  readonly key = 'database';

  constructor(
    private readonly prisma: PrismaService,
    @InjectPinoLogger(DatabaseHealthProbe.name)
    private readonly logger: PinoLogger,
  ) {}

  check(): Promise<HealthComponent> {
    return runProbe('PostgreSQL', () => this.prisma.$queryRaw`SELECT 1`, this.logger);
  }
}
