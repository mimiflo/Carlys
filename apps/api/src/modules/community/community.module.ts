import { Module } from '@nestjs/common';
import { AdminAccessModule } from '../admin/admin-access.module';
import { AuditModule } from '../audit/audit.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { CommunityChallengesService } from './application/community-challenges.service';
import { CommunityModerationService } from './application/community-moderation.service';
import { CommunityNotifier } from './application/community-notifier';
import { CommunityService } from './application/community.service';
import { CommunityChallengesRepository } from './infrastructure/community-challenges.repository';
import { CommunityModerationRepository } from './infrastructure/community-moderation.repository';
import { CommunityRepository } from './infrastructure/community.repository';
import { AdminCommunityController } from './presentation/http/admin-community.controller';
import { CommunityChallengesController } from './presentation/http/community-challenges.controller';
import { CommunityModerationController } from './presentation/http/community-moderation.controller';
import { CommunityController } from './presentation/http/community.controller';

/**
 * Communauté : amis, encouragements, défis collectifs et modération.
 * Importe `AdminAccessModule` et `AuditModule` pour ses routes
 * d'administration (signalements), soumises au même RBAC et au même audit
 * que le reste du back-office, comme les médias.
 */
@Module({
  // Notifications : demandes d'ami, acceptations et encouragements poussent.
  imports: [NotificationsModule, AdminAccessModule, AuditModule],
  controllers: [
    CommunityController,
    CommunityChallengesController,
    CommunityModerationController,
    AdminCommunityController,
  ],
  providers: [
    CommunityService,
    CommunityNotifier,
    CommunityChallengesService,
    CommunityModerationService,
    CommunityRepository,
    CommunityChallengesRepository,
    CommunityModerationRepository,
  ],
  // Exporté pour la clôture de séance (contribution aux défis SPORT).
  exports: [CommunityService],
})
export class CommunityModule {}
