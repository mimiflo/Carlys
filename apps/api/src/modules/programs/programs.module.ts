import { Module } from '@nestjs/common';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module';
import { UsersModule } from '../users/users.module';
import { ProgramCalendarService } from './application/program-calendar.service';
import { ProgramGenerationService } from './application/program-generation.service';
import { ProgramsService } from './application/programs.service';
import { GenerationRepository } from './infrastructure/generation.repository';
import { ProgramsRepository } from './infrastructure/programs.repository';
import { ProgramsController } from './presentation/http/programs.controller';

/**
 * Programmes multi-semaines.
 *
 * Importe `SubscriptionsModule` pour le plafond du plan gratuit : combien de
 * programmes un compte peut garder est une décision SERVEUR, jamais un réglage
 * du client. Et `UsersModule` pour les entrées de génération — l'objectif, le
 * niveau, le rythme et le matériel vivent au profil, jamais dans le corps de
 * la requête.
 */
@Module({
  imports: [SubscriptionsModule, UsersModule],
  controllers: [ProgramsController],
  providers: [
    ProgramsService,
    ProgramGenerationService,
    ProgramCalendarService,
    ProgramsRepository,
    GenerationRepository,
  ],
  exports: [ProgramsService, ProgramsRepository],
})
export class ProgramsModule {}
