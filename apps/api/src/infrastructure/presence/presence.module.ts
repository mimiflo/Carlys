import { Global, Module } from '@nestjs/common';
import { PresenceService } from './presence.service';

/**
 * Global comme le module Redis dont il dépend : la présence est lue par les
 * métriques et écrite par l'intergiciel HTTP, deux points d'entrée qui n'ont
 * pas de raison de se déclarer un import mutuel.
 */
@Global()
@Module({
  providers: [PresenceService],
  exports: [PresenceService],
})
export class PresenceModule {}
