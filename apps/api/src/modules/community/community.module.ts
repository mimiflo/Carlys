import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { CommunityChallengesService } from './application/community-challenges.service';
import { CommunityService } from './application/community.service';
import { CommunityChallengesRepository } from './infrastructure/community-challenges.repository';
import { CommunityRepository } from './infrastructure/community.repository';
import { CommunityChallengesController } from './presentation/http/community-challenges.controller';
import { CommunityController } from './presentation/http/community.controller';

@Module({
  // Notifications : demandes d'ami, acceptations et encouragements poussent.
  imports: [NotificationsModule],
  controllers: [CommunityController, CommunityChallengesController],
  providers: [
    CommunityService,
    CommunityChallengesService,
    CommunityRepository,
    CommunityChallengesRepository,
  ],
  // Exporté pour la clôture de séance (contribution aux défis SPORT).
  exports: [CommunityService],
})
export class CommunityModule {}
