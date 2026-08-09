import { Module } from '@nestjs/common';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module';
import { ProgramsService } from './application/programs.service';
import { ProgramsRepository } from './infrastructure/programs.repository';
import { ProgramsController } from './presentation/http/programs.controller';

/**
 * Programmes multi-semaines.
 *
 * Importe `SubscriptionsModule` pour le plafond du plan gratuit : combien de
 * programmes un compte peut garder est une décision SERVEUR, jamais un réglage
 * du client.
 */
@Module({
  imports: [SubscriptionsModule],
  controllers: [ProgramsController],
  providers: [ProgramsService, ProgramsRepository],
  exports: [ProgramsService],
})
export class ProgramsModule {}
