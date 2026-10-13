import { type AdminCommunityReport, type CommunityReportDecision } from '@carlys/api-contracts';
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { blankToNull } from '../../../common/utilities/blank-to-null';
import { AdminUsersService } from '../../admin/application/admin-users.service';
import { type AdminActor, AuditService } from '../../audit/audit.service';
import {
  CommunityModerationRepository,
  type CommunityReportRow,
} from '../infrastructure/community-moderation.repository';
import {
  ModerationDecisionRepository,
  type RemovableContent,
} from '../infrastructure/moderation-decision.repository';
import { presentOneAdminReport } from './community-report.presenter';

/** Suspendre est un geste de gestion des comptes : sa permission, en plus. */
export const SUSPEND_PERMISSION = 'user:update';

const NOTHING_TO_REMOVE = 'Rien à retirer : le contenu n’existe plus.';

/**
 * Le contenu qu'un signalement permet de retirer. Un signalement de la
 * personne en général n'en vise aucun (400) ; un contenu déjà disparu —
 * cliché présent, référence à NULL — ne se retire plus (409).
 */
function removableContentOf(report: CommunityReportRow): RemovableContent {
  if (report.encouragementId !== null) {
    return { kind: 'encouragement', id: report.encouragementId };
  }
  if (report.friendChallengeId !== null) {
    // Seul le MOT d'un défi se retire : sans mot au signalement (le cliché
    // le dit, un mot ne s'ajoute jamais après), ou mot déjà effacé, rien.
    if (
      report.friendChallengeMessage === null ||
      (report.friendChallenge?.messageRemovedAt ?? null) !== null
    ) {
      throw new ConflictException(NOTHING_TO_REMOVE);
    }
    return { kind: 'friend_challenge', id: report.friendChallengeId };
  }
  if (report.encouragementMessage !== null || report.friendChallengeTitle !== null) {
    throw new ConflictException(NOTHING_TO_REMOVE);
  }
  throw new BadRequestException(
    'Ce signalement vise la personne, pas un contenu : il n’y a rien à retirer.',
  );
}

/**
 * Trancher un signalement OUVERT : retirer le contenu visé, suspendre la
 * personne, ou classer sans suite — puis le résoudre en gardant qui a
 * décidé, pourquoi et quoi. Tout est audité ; aucun texte de membre ne part
 * dans le journal.
 */
@Injectable()
export class CommunityModerationDecisionService {
  constructor(
    private readonly moderation: CommunityModerationRepository,
    private readonly decisions: ModerationDecisionRepository,
    private readonly users: AdminUsersService,
    private readonly audit: AuditService,
    @InjectPinoLogger(CommunityModerationDecisionService.name)
    private readonly logger: PinoLogger,
  ) {}

  async decide(
    reportId: string,
    decision: CommunityReportDecision,
    actor: AdminActor & { permissions: readonly string[] },
  ): Promise<AdminCommunityReport> {
    const note = blankToNull(decision.note);
    if (decision.suspendUser && note === null) {
      throw new BadRequestException('Une suspension se justifie : la note est obligatoire.');
    }
    if (decision.suspendUser && !actor.permissions.includes(SUSPEND_PERMISSION)) {
      throw new ForbiddenException(`Permission manquante : ${SUSPEND_PERMISSION}.`);
    }
    const report = await this.moderation.findReportById(reportId);
    if (report === null) {
      throw new NotFoundException('Signalement introuvable.');
    }
    if (report.status !== 'OPEN') {
      throw new ConflictException('Signalement déjà traité : rouvre-le pour trancher à nouveau.');
    }
    const content = decision.removeContent ? removableContentOf(report) : null;
    if (decision.suspendUser && report.reportedUser.status === 'DELETED') {
      throw new ConflictException('Compte supprimé — statut non modifiable.');
    }
    const outcome = await this.decisions.decide({
      reportId,
      adminUserId: actor.adminUserId,
      note,
      content,
      userSuspended: decision.suspendUser,
    });
    if (outcome.kind === 'already_resolved') {
      throw new ConflictException('Signalement déjà traité entre-temps.');
    }
    if (outcome.kind === 'nothing_to_remove') {
      throw new ConflictException(NOTHING_TO_REMOVE);
    }
    const decided = [reportId, ...outcome.siblingReportIds];
    let suspended = false;
    try {
      if (decision.suspendUser) {
        await this.suspendAfterCommit(report, decided, actor);
        suspended = true;
      }
    } finally {
      // La décision est COMMITÉE : elle s'audite, suspension réussie ou non.
      this.recordAudit(report, decision, suspended, content, outcome.siblingReportIds, actor);
    }
    // Relu après la suspension : `reportedUserStatus` doit dire SUSPENDED.
    const fresh = suspended ? await this.moderation.findReportById(reportId) : null;
    return presentOneAdminReport(this.moderation, fresh ?? outcome.report);
  }

  /**
   * Suspendre APRÈS le commit : un 409 de course (signalement tranché
   * entre-temps, contenu disparu) n'a ainsi jamais suspendu personne. La
   * suspension garde son chemin (sessions révoquées, audit propre) et se
   * rejoue sans effet sur un compte déjà suspendu.
   *
   * Cas résiduel : le compte est supprimé entre la vérification et cet
   * appel. La décision reste (contenu retiré, signalements résolus), mais
   * ses signalements cessent de prétendre avoir suspendu, un avertissement
   * structuré est journalisé et l'erreur (409) remonte telle quelle.
   */
  private async suspendAfterCommit(
    report: CommunityReportRow,
    decided: readonly string[],
    actor: AdminActor,
  ): Promise<void> {
    try {
      await this.users.setUserStatus(report.reportedUserId, 'SUSPENDED', actor);
    } catch (error) {
      await this.decisions.clearSuspension(decided);
      this.logger.warn(
        {
          err: error,
          reportId: report.id,
          reportedUserId: report.reportedUserId,
          requestId: actor.requestId,
        },
        'Décision de modération enregistrée, suspension impossible',
      );
      throw error;
    }
  }

  private recordAudit(
    report: CommunityReportRow,
    decision: CommunityReportDecision,
    suspended: boolean,
    content: RemovableContent | null,
    siblingReportIds: readonly string[],
    actor: AdminActor,
  ): void {
    const base = {
      actorType: 'ADMIN' as const,
      adminUserId: actor.adminUserId,
      userId: report.reportedUserId,
      requestId: actor.requestId,
      ipAddress: actor.ipAddress,
    };
    this.audit.record({
      ...base,
      action: 'admin.community_report_decided',
      resourceType: 'community_report',
      resourceId: report.id,
      metadata: {
        reason: report.reason,
        removeContent: decision.removeContent,
        suspendUser: decision.suspendUser,
        // Demandée ET faite : diffère de `suspendUser` dans le seul cas
        // résiduel où le compte a été supprimé entre-temps.
        userSuspended: suspended,
        siblingReportsResolved: siblingReportIds.length,
        siblingReportIds: [...siblingReportIds],
      },
    });
    if (content !== null) {
      this.audit.record({
        ...base,
        action: 'admin.community_content_removed',
        resourceType: content.kind,
        resourceId: content.id,
        metadata: { reportId: report.id },
      });
    }
  }
}
