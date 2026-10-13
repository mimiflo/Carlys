import { Module } from '@nestjs/common';
import { AdminAccessModule } from '../admin/admin-access.module';
import { AdminUsersModule } from '../admin/admin-users.module';
import { AuditModule } from '../audit/audit.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { CommunityChallengesService } from './application/community-challenges.service';
import { CommunityModerationDecisionService } from './application/community-moderation-decision.service';
import { CommunityModerationService } from './application/community-moderation.service';
import { CommunityNotifier } from './application/community-notifier';
import { CommunityService } from './application/community.service';
import { CommunityWithdrawalService } from './application/community-withdrawal.service';
import { EncouragementsService } from './application/encouragements.service';
import { FriendChallengesService } from './application/friend-challenges.service';
import { LeaguesService } from './application/leagues.service';
import { CommunityChallengesRepository } from './infrastructure/community-challenges.repository';
import { CommunityModerationRepository } from './infrastructure/community-moderation.repository';
import { CommunityRepository } from './infrastructure/community.repository';
import { FriendChallengesRepository } from './infrastructure/friend-challenges.repository';
import { LeaguesRepository } from './infrastructure/leagues.repository';
import { ModerationDecisionRepository } from './infrastructure/moderation-decision.repository';
import { AdminCommunityController } from './presentation/http/admin-community.controller';
import { CommunityChallengesController } from './presentation/http/community-challenges.controller';
import { CommunityModerationController } from './presentation/http/community-moderation.controller';
import { CommunityController } from './presentation/http/community.controller';
import { LeaguesController } from './presentation/http/leagues.controller';

/**
 * Communauté : amis, encouragements, défis (collectifs et entre amis),
 * ligues et modération.
 * Importe `AdminAccessModule` et `AuditModule` pour ses routes
 * d'administration (signalements), soumises au même RBAC et au même audit
 * que le reste du back-office, comme les médias.
 */
@Module({
  // Notifications : demandes d'ami, acceptations et encouragements poussent.
  // Comptes admin : une décision de modération suspend par le même chemin.
  imports: [NotificationsModule, AdminAccessModule, AdminUsersModule, AuditModule],
  controllers: [
    CommunityController,
    CommunityChallengesController,
    CommunityModerationController,
    LeaguesController,
    AdminCommunityController,
  ],
  providers: [
    CommunityService,
    CommunityWithdrawalService,
    EncouragementsService,
    CommunityNotifier,
    CommunityChallengesService,
    FriendChallengesService,
    LeaguesService,
    CommunityModerationService,
    CommunityModerationDecisionService,
    CommunityRepository,
    CommunityChallengesRepository,
    FriendChallengesRepository,
    LeaguesRepository,
    CommunityModerationRepository,
    ModerationDecisionRepository,
  ],
  // Exportés pour la clôture de séance (contribution aux défis SPORT) et
  // pour la suppression du compte (retrait immédiat de la communauté).
  exports: [CommunityService, CommunityWithdrawalService],
})
export class CommunityModule {}
