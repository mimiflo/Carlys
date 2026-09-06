import { BadRequestException, NotFoundException } from '@nestjs/common';
import { type AuditService } from '../../audit/audit.service';
import {
  type CommunityModerationRepository,
  type CommunityReportRow,
} from '../infrastructure/community-moderation.repository';
import { CommunityModerationService } from './community-moderation.service';

const ME = 'utilisateur-moi';
const OTHER = 'utilisateur-autre';
const ADMIN = { adminUserId: 'admin-1', ipAddress: '127.0.0.1', requestId: 'req-1' };

interface Stubs {
  isBlockedEitherWay: jest.Mock;
  blockedUserIdsEitherWay: jest.Mock;
  block: jest.Mock;
  unblock: jest.Mock;
  listBlocks: jest.Mock;
  userExists: jest.Mock;
  deleteEncouragementFor: jest.Mock;
  findOpenReport: jest.Mock;
  createReport: jest.Mock;
  findReportById: jest.Mock;
  listReports: jest.Mock;
  setReportStatus: jest.Mock;
}

function reportRow(overrides: Partial<CommunityReportRow> = {}): CommunityReportRow {
  return {
    id: 'signalement-1',
    reporterId: ME,
    reportedUserId: OTHER,
    encouragementId: null,
    encouragementMessage: null,
    reason: 'SPAM',
    details: null,
    status: 'OPEN',
    createdAt: new Date('2026-09-01T10:00:00Z'),
    resolvedAt: null,
    reporter: { id: ME, email: 'moi@carlys.test', profile: { displayName: 'Moi' } },
    reportedUser: { id: OTHER, email: 'autre@carlys.test', profile: null },
    ...overrides,
  };
}

function buildStubs(): Stubs {
  return {
    isBlockedEitherWay: jest.fn().mockResolvedValue(false),
    blockedUserIdsEitherWay: jest.fn().mockResolvedValue(new Set<string>()),
    block: jest.fn().mockResolvedValue(undefined),
    unblock: jest.fn().mockResolvedValue(undefined),
    listBlocks: jest.fn().mockResolvedValue([]),
    userExists: jest.fn().mockResolvedValue(true),
    deleteEncouragementFor: jest.fn().mockResolvedValue(undefined),
    findOpenReport: jest.fn().mockResolvedValue(null),
    createReport: jest
      .fn()
      .mockImplementation((input: Partial<CommunityReportRow>) =>
        Promise.resolve(reportRow(input)),
      ),
    findReportById: jest.fn().mockResolvedValue(null),
    listReports: jest.fn().mockResolvedValue([]),
    setReportStatus: jest.fn().mockResolvedValue(reportRow({ status: 'RESOLVED' })),
  };
}

const auditStub = { record: jest.fn() };

function buildService(stubs: Stubs): CommunityModerationService {
  return new CommunityModerationService(
    stubs as unknown as CommunityModerationRepository,
    auditStub as unknown as AuditService,
  );
}

beforeEach(() => {
  auditStub.record.mockClear();
});

describe('CommunityModerationService — blocages', () => {
  it('on ne se bloque pas soi-même', async () => {
    const stubs = buildStubs();
    await expect(buildService(stubs).block(ME, ME)).rejects.toBeInstanceOf(BadRequestException);
    expect(stubs.block).not.toHaveBeenCalled();
  });

  it('bloquer un compte inexistant (ou supprimé) est un 404', async () => {
    const stubs = buildStubs();
    stubs.userExists.mockResolvedValue(false);
    await expect(buildService(stubs).block(ME, OTHER)).rejects.toBeInstanceOf(NotFoundException);
    expect(stubs.block).not.toHaveBeenCalled();
  });

  it('bloquer délègue au dépôt, qui retire aussi l’amitié et les demandes', async () => {
    const stubs = buildStubs();
    await buildService(stubs).block(ME, OTHER);
    expect(stubs.block).toHaveBeenCalledWith(ME, OTHER);
  });

  it('la liste des bloqués rend le nom courant, ou un nom neutre', async () => {
    const stubs = buildStubs();
    const at = new Date('2026-09-02T08:00:00Z');
    stubs.listBlocks.mockResolvedValue([
      { blockedId: OTHER, createdAt: at, blocked: { profile: { displayName: 'Tom' } } },
      { blockedId: 'tiers', createdAt: at, blocked: { profile: null } },
    ]);

    await expect(buildService(stubs).listBlocks(ME)).resolves.toEqual([
      { userId: OTHER, displayName: 'Tom', blockedAt: at.toISOString() },
      { userId: 'tiers', displayName: 'Membre Carlys', blockedAt: at.toISOString() },
    ]);
  });
});

describe('CommunityModerationService — signalements', () => {
  const command = { reportedUserId: OTHER, reason: 'HARCELEMENT' as const };

  it('on ne se signale pas soi-même', async () => {
    const stubs = buildStubs();
    await expect(
      buildService(stubs).report(ME, { ...command, reportedUserId: ME }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(stubs.createReport).not.toHaveBeenCalled();
  });

  it('signaler un compte inexistant est un 404', async () => {
    const stubs = buildStubs();
    stubs.userExists.mockResolvedValue(false);
    await expect(buildService(stubs).report(ME, command)).rejects.toBeInstanceOf(NotFoundException);
  });

  it('seul un encouragement REÇU de la personne signalée peut être visé', async () => {
    const stubs = buildStubs();
    // Le dépôt ne trouve pas ce message entre ces deux personnes : rien n'est écrit.
    stubs.createReport.mockResolvedValue(null);

    await expect(
      buildService(stubs).report(ME, { ...command, encouragementId: 'message-1' }),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(stubs.createReport).toHaveBeenCalledWith(
      expect.objectContaining({
        reporterId: ME,
        reportedUserId: OTHER,
        encouragementId: 'message-1',
      }),
    );
  });

  it('le signalement d’un encouragement transmet son identifiant au dépôt, qui fige le texte', async () => {
    const stubs = buildStubs();
    stubs.createReport.mockResolvedValue(
      reportRow({ encouragementId: 'message-1', encouragementMessage: 'Texte figé' }),
    );

    const report = await buildService(stubs).report(ME, {
      ...command,
      encouragementId: 'message-1',
    });

    expect(stubs.createReport).toHaveBeenCalledWith(
      expect.objectContaining({ encouragementId: 'message-1' }),
    );
    // L'accusé de réception du membre cite le message, jamais son cliché.
    expect(report.encouragementId).toBe('message-1');
    expect(report).not.toHaveProperty('encouragementMessage');
  });

  it('un signalement ouvert identique n’est pas dupliqué : le même est rendu', async () => {
    const stubs = buildStubs();
    stubs.findOpenReport.mockResolvedValue(reportRow({ id: 'déjà-là' }));

    const report = await buildService(stubs).report(ME, command);

    expect(report.id).toBe('déjà-là');
    expect(stubs.findOpenReport).toHaveBeenCalledWith(ME, OTHER, null);
    expect(stubs.createReport).not.toHaveBeenCalled();
  });

  it('les précisions sont nettoyées : vides → null, sinon sans espaces autour', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    await service.report(ME, { ...command, details: '   ' });
    expect(stubs.createReport).toHaveBeenLastCalledWith(
      expect.objectContaining({ reporterId: ME, reportedUserId: OTHER, details: null }),
    );

    await service.report(ME, { ...command, details: '  Il insiste.  ' });
    expect(stubs.createReport).toHaveBeenLastCalledWith(
      expect.objectContaining({ details: 'Il insiste.', encouragementId: null }),
    );
  });

  it('l’accusé de réception ne contient RIEN sur le signalé au-delà de son identifiant', async () => {
    const stubs = buildStubs();
    const report = await buildService(stubs).report(ME, command);

    expect(report).toEqual({
      id: 'signalement-1',
      reportedUserId: OTHER,
      encouragementId: null,
      reason: 'HARCELEMENT',
      details: null,
      status: 'OPEN',
      createdAt: '2026-09-01T10:00:00.000Z',
      resolvedAt: null,
    });
    expect(report).not.toHaveProperty('reportedUser');
  });
});

describe('CommunityModerationService — administration', () => {
  it('résoudre un signalement inconnu est un 404', async () => {
    const stubs = buildStubs();
    await expect(
      buildService(stubs).setReportStatus('inconnu', 'RESOLVED', ADMIN),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(auditStub.record).not.toHaveBeenCalled();
  });

  it('résoudre est audité, avec la personne signalée comme sujet', async () => {
    const stubs = buildStubs();
    stubs.findReportById.mockResolvedValue(reportRow());

    const resolved = await buildService(stubs).setReportStatus('signalement-1', 'RESOLVED', ADMIN);

    expect(resolved.status).toBe('RESOLVED');
    expect(resolved.reporter.email).toBe('moi@carlys.test');
    expect(resolved.reportedUser.displayName).toBeNull();
    expect(auditStub.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'admin.community_report_resolved',
        actorType: 'ADMIN',
        adminUserId: 'admin-1',
        userId: OTHER,
        resourceType: 'community_report',
        resourceId: 'signalement-1',
        requestId: 'req-1',
      }),
    );
  });

  it('rejouer le même statut ne réécrit ni n’audite rien', async () => {
    const stubs = buildStubs();
    stubs.findReportById.mockResolvedValue(reportRow({ status: 'RESOLVED' }));

    await buildService(stubs).setReportStatus('signalement-1', 'RESOLVED', ADMIN);

    expect(stubs.setReportStatus).not.toHaveBeenCalled();
    expect(auditStub.record).not.toHaveBeenCalled();
  });

  it('rouvrir est audité sous sa propre action', async () => {
    const stubs = buildStubs();
    stubs.findReportById.mockResolvedValue(reportRow({ status: 'RESOLVED' }));
    stubs.setReportStatus.mockResolvedValue(reportRow());

    await buildService(stubs).setReportStatus('signalement-1', 'OPEN', ADMIN);

    expect(auditStub.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'admin.community_report_reopened' }),
    );
  });

  it('la pagination lit limit + 1 et ne rend un curseur que s’il reste une page', async () => {
    const stubs = buildStubs();
    stubs.listReports.mockResolvedValue([
      reportRow({ id: 'a' }),
      reportRow({ id: 'b' }),
      reportRow({ id: 'c' }),
    ]);

    const page = await buildService(stubs).listReports('OPEN', 2);

    expect(stubs.listReports).toHaveBeenCalledWith('OPEN', 2, undefined);
    expect(page.items.map((item) => item.id)).toEqual(['a', 'b']);
    expect(page).toMatchObject({ hasMore: true, nextCursor: 'b' });
    expect(page.items[0]?.encouragementMessage).toBeNull();
  });

  it('l’administration lit le cliché du texte, même une fois le message retiré', async () => {
    const stubs = buildStubs();
    // Message supprimé depuis (référence à NULL) : le cliché, lui, est resté.
    stubs.listReports.mockResolvedValue([
      reportRow({ encouragementId: null, encouragementMessage: 'Texte figé' }),
    ]);

    const page = await buildService(stubs).listReports(undefined, 10);

    expect(page.items[0]).toMatchObject({
      encouragementId: null,
      encouragementMessage: 'Texte figé',
    });
  });
});
