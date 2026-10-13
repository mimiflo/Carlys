import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { type AdminUsersService } from '../../admin/application/admin-users.service';
import { type PinoLogger } from 'nestjs-pino';
import { type AuditService } from '../../audit/audit.service';
import {
  type CommunityModerationRepository,
  type CommunityReportRow,
} from '../infrastructure/community-moderation.repository';
import { type ModerationDecisionRepository } from '../infrastructure/moderation-decision.repository';
import { CommunityModerationDecisionService } from './community-moderation-decision.service';

const REPORTED = 'personne-signalee';
const MODERATOR = {
  adminUserId: 'admin-1',
  ipAddress: '127.0.0.1',
  requestId: 'req-1',
  permissions: ['community:moderate', 'user:update'],
};
const MODERATOR_ONLY = { ...MODERATOR, permissions: ['community:moderate'] };

function reportRow(overrides: Partial<CommunityReportRow> = {}): CommunityReportRow {
  return {
    id: 'signalement-1',
    reporterId: 'signalant',
    reportedUserId: REPORTED,
    encouragementId: 'encouragement-1',
    encouragementMessage: 'Texte blessant',
    friendChallengeId: null,
    friendChallengeTitle: null,
    friendChallengeMessage: null,
    reason: 'HARCELEMENT',
    details: null,
    status: 'OPEN',
    createdAt: new Date('2026-10-01T10:00:00Z'),
    resolvedAt: null,
    resolvedByAdminId: null,
    resolutionNote: null,
    contentRemoved: false,
    userSuspended: false,
    reporter: { id: 'signalant', email: 's@carlys.test', profile: null },
    reportedUser: { id: REPORTED, email: 'v@carlys.test', status: 'ACTIVE', profile: null },
    resolvedBy: null,
    friendChallenge: null,
    ...overrides,
  };
}

function setup(report: CommunityReportRow | null = reportRow()) {
  const moderation = {
    findReportById: jest.fn().mockResolvedValue(report),
    reportCountsFor: jest.fn().mockResolvedValue(new Map([[REPORTED, { total: 2, open: 0 }]])),
  };
  const decisions = {
    decide: jest.fn().mockResolvedValue({
      kind: 'decided',
      report: reportRow({ status: 'RESOLVED', contentRemoved: true }),
      siblingReportIds: ['signalement-frere'],
    }),
    clearSuspension: jest.fn().mockResolvedValue(undefined),
  };
  const users = { setUserStatus: jest.fn().mockResolvedValue(undefined) };
  const audit = { record: jest.fn() };
  const logger = { warn: jest.fn() };
  const service = new CommunityModerationDecisionService(
    moderation as unknown as CommunityModerationRepository,
    decisions as unknown as ModerationDecisionRepository,
    users as unknown as AdminUsersService,
    audit as unknown as AuditService,
    logger as unknown as PinoLogger,
  );
  return { service, moderation, decisions, users, audit, logger };
}

const KEEP = { removeContent: false, suspendUser: false };

describe('CommunityModerationDecisionService', () => {
  it('retirer un encouragement : transaction avec la cible, deux audits sans aucun texte', async () => {
    const { service, decisions, users, audit } = setup();

    const result = await service.decide(
      'signalement-1',
      { removeContent: true, suspendUser: false, note: '  Insulte.  ' },
      MODERATOR,
    );

    expect(decisions.decide).toHaveBeenCalledWith({
      reportId: 'signalement-1',
      adminUserId: 'admin-1',
      note: 'Insulte.',
      content: { kind: 'encouragement', id: 'encouragement-1' },
      userSuspended: false,
    });
    expect(users.setUserStatus).not.toHaveBeenCalled();
    expect(result).toMatchObject({ status: 'RESOLVED', reportedUserReportsCount: 2 });
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'admin.community_report_decided',
        resourceId: 'signalement-1',
        userId: REPORTED,
        metadata: {
          reason: 'HARCELEMENT',
          removeContent: true,
          suspendUser: false,
          userSuspended: false,
          siblingReportsResolved: 1,
          siblingReportIds: ['signalement-frere'],
        },
      }),
    );
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'admin.community_content_removed',
        resourceType: 'encouragement',
        resourceId: 'encouragement-1',
      }),
    );
    expect(JSON.stringify(audit.record.mock.calls)).not.toContain('Texte blessant');
    expect(JSON.stringify(audit.record.mock.calls)).not.toContain('Insulte');
  });

  const challengeReport = (overrides: Partial<CommunityReportRow> = {}) =>
    reportRow({
      encouragementId: null,
      encouragementMessage: null,
      friendChallengeId: 'defi-1',
      friendChallengeTitle: 'Qui court le plus',
      friendChallengeMessage: 'Vous êtes nuls.',
      friendChallenge: { messageRemovedAt: null },
      ...overrides,
    });

  it('retirer le mot d’un défi : la cible est le défi', async () => {
    const { service, decisions } = setup(challengeReport());

    await service.decide('signalement-1', { removeContent: true, suspendUser: false }, MODERATOR);

    expect(decisions.decide).toHaveBeenCalledWith(
      expect.objectContaining({ content: { kind: 'friend_challenge', id: 'defi-1' } }),
    );
  });

  it('classer sans suite : ni retrait ni suspension, un seul audit', async () => {
    const { service, decisions, audit } = setup();

    await service.decide('signalement-1', KEEP, MODERATOR_ONLY);

    expect(decisions.decide).toHaveBeenCalledWith(
      expect.objectContaining({ content: null, note: null, userSuspended: false }),
    );
    expect(audit.record).toHaveBeenCalledTimes(1);
  });

  it('défi sans mot au signalement, ou mot déjà effacé : 409 avant toute écriture ou suspension', async () => {
    for (const report of [
      challengeReport({ friendChallengeMessage: null }),
      challengeReport({ friendChallenge: { messageRemovedAt: new Date() } }),
    ]) {
      const { service, decisions, users } = setup(report);
      await expect(
        service.decide(
          'signalement-1',
          { removeContent: true, suspendUser: true, note: 'Récidive' },
          MODERATOR,
        ),
      ).rejects.toThrow('Rien à retirer');
      expect(decisions.decide).not.toHaveBeenCalled();
      expect(users.setUserStatus).not.toHaveBeenCalled();
    }
  });

  it('suspendre un compte supprimé : 409 avant la transaction', async () => {
    const { service, decisions, users } = setup(
      reportRow({
        reportedUser: { id: REPORTED, email: 'v@carlys.test', status: 'DELETED', profile: null },
      }),
    );

    await expect(
      service.decide(
        'signalement-1',
        { removeContent: true, suspendUser: true, note: 'Récidive' },
        MODERATOR,
      ),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(decisions.decide).not.toHaveBeenCalled();
    expect(users.setUserStatus).not.toHaveBeenCalled();
  });

  it('un 409 de course dans la transaction ne suspend personne', async () => {
    for (const kind of ['nothing_to_remove', 'already_resolved']) {
      const { service, decisions, users } = setup();
      decisions.decide.mockResolvedValue({ kind });
      await expect(
        service.decide(
          'signalement-1',
          { removeContent: true, suspendUser: true, note: 'Récidive' },
          MODERATOR,
        ),
      ).rejects.toBeInstanceOf(ConflictException);
      expect(users.setUserStatus).not.toHaveBeenCalled();
    }
  });

  it('compte supprimé entre-temps : décision gardée, drapeau retiré, avertissement, erreur remontée', async () => {
    const { service, decisions, users, audit, logger } = setup();
    const refusal = new ConflictException('Compte supprimé — statut non modifiable.');
    users.setUserStatus.mockRejectedValue(refusal);

    await expect(
      service.decide(
        'signalement-1',
        { removeContent: true, suspendUser: true, note: 'Récidive' },
        MODERATOR,
      ),
    ).rejects.toBe(refusal);
    expect(decisions.clearSuspension).toHaveBeenCalledWith(['signalement-1', 'signalement-frere']);
    expect(logger.warn).toHaveBeenCalledWith(
      expect.objectContaining({ reportId: 'signalement-1', requestId: 'req-1' }),
      expect.any(String),
    );
    const decidedAudit = audit.record.mock.calls
      .map(([entry]) => entry as { action: string; metadata: Record<string, unknown> })
      .find((entry) => entry.action === 'admin.community_report_decided');
    expect(decidedAudit?.metadata).toMatchObject({ suspendUser: true, userSuspended: false });
  });

  it('suspendre passe par la gestion des comptes, APRÈS le commit, puis relit le signalement', async () => {
    const { service, decisions, users, moderation } = setup();
    const order: string[] = [];
    users.setUserStatus.mockImplementation(() => {
      order.push('suspension');
      return Promise.resolve();
    });
    decisions.decide.mockImplementation(() => {
      order.push('transaction');
      return Promise.resolve({ kind: 'decided', report: reportRow(), siblingReportIds: [] });
    });

    await service.decide(
      'signalement-1',
      { removeContent: false, suspendUser: true, note: 'Récidive' },
      MODERATOR,
    );

    expect(users.setUserStatus).toHaveBeenCalledWith(
      REPORTED,
      'SUSPENDED',
      expect.objectContaining({ adminUserId: 'admin-1', requestId: 'req-1' }),
    );
    expect(decisions.decide).toHaveBeenCalledWith(
      expect.objectContaining({ userSuspended: true, note: 'Récidive' }),
    );
    expect(order).toEqual(['transaction', 'suspension']);
    // Lu une fois pour décider, une fois après la suspension.
    expect(moderation.findReportById).toHaveBeenCalledTimes(2);
  });

  it('suspendre sans note (ou une note blanche) : 400, rien n’est lu', async () => {
    const { service, moderation } = setup();
    for (const note of [undefined, '   ']) {
      await expect(
        service.decide(
          'signalement-1',
          { removeContent: false, suspendUser: true, note },
          MODERATOR,
        ),
      ).rejects.toBeInstanceOf(BadRequestException);
    }
    expect(moderation.findReportById).not.toHaveBeenCalled();
  });

  it('suspendre sans la permission user:update : 403, rien n’est écrit', async () => {
    const { service, users, decisions } = setup();

    await expect(
      service.decide(
        'signalement-1',
        { removeContent: false, suspendUser: true, note: 'Récidive' },
        MODERATOR_ONLY,
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(users.setUserStatus).not.toHaveBeenCalled();
    expect(decisions.decide).not.toHaveBeenCalled();
  });

  it('signalement inconnu : 404 ; déjà résolu : 409', async () => {
    await expect(setup(null).service.decide('x', KEEP, MODERATOR)).rejects.toBeInstanceOf(
      NotFoundException,
    );
    const resolved = setup(reportRow({ status: 'RESOLVED' }));
    await expect(resolved.service.decide('x', KEEP, MODERATOR)).rejects.toBeInstanceOf(
      ConflictException,
    );
    expect(resolved.decisions.decide).not.toHaveBeenCalled();
  });

  it('retirer quand le signalement vise la personne en général : 400', async () => {
    const { service, decisions } = setup(
      reportRow({ encouragementId: null, encouragementMessage: null }),
    );

    await expect(
      service.decide('signalement-1', { removeContent: true, suspendUser: false }, MODERATOR),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(decisions.decide).not.toHaveBeenCalled();
  });

  it('retirer un contenu déjà disparu (cliché sans référence) : 409, avant toute suspension', async () => {
    for (const gone of [
      reportRow({ encouragementId: null }),
      reportRow({
        encouragementId: null,
        encouragementMessage: null,
        friendChallengeTitle: 'Défi supprimé',
      }),
    ]) {
      const { service, users } = setup(gone);
      await expect(
        service.decide(
          'signalement-1',
          { removeContent: true, suspendUser: true, note: 'Récidive' },
          MODERATOR,
        ),
      ).rejects.toThrow('Rien à retirer');
      expect(users.setUserStatus).not.toHaveBeenCalled();
    }
  });

  it('la transaction ne trouve plus rien à retirer, ou un signalement déjà tranché : 409, aucun audit', async () => {
    for (const kind of ['nothing_to_remove', 'already_resolved']) {
      const { service, decisions, audit } = setup();
      decisions.decide.mockResolvedValue({ kind });
      await expect(
        service.decide('signalement-1', { removeContent: true, suspendUser: false }, MODERATOR),
      ).rejects.toBeInstanceOf(ConflictException);
      expect(audit.record).not.toHaveBeenCalled();
    }
  });
});
