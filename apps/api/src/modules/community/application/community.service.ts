import {
  type CommunityChallenge as ChallengeContract,
  type CommunityFriend,
  type CommunityProfile,
  type Encouragement as EncouragementContract,
  type FriendRequest,
  type NotificationCategory,
} from '@carlys/api-contracts';
import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { FriendRequestStatus } from '@prisma/client';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { NotificationsService } from '../../notifications/application/notifications.service';
import { type PushMessage } from '../../notifications/domain/push-sender.port';
import {
  type ChallengeWithStats,
  CommunityRepository,
  type FriendRow,
} from '../infrastructure/community.repository';
import { computeStreakDays } from './streak.calculator';

const FEED_LIMIT = 50;
/** Historique suffisant pour toute série plausible affichée (60 jours). */
const STREAK_WINDOW_DAYS = 60;

function presentChallenge(challenge: ChallengeWithStats, userId: string): ChallengeContract {
  const total = challenge.participations.reduce((sum, p) => sum + p.contribution, 0);
  return {
    id: challenge.id,
    kind: challenge.kind,
    title: challenge.title,
    description: challenge.description,
    target: challenge.target,
    progress: challenge.target <= 0 ? 0 : Math.min(1, total / challenge.target),
    participants: challenge.participations.length,
    joined: challenge.participations.some((p) => p.userId === userId),
    endsAt: challenge.endsAt.toISOString(),
  };
}

@Injectable()
export class CommunityService {
  constructor(
    private readonly community: CommunityRepository,
    private readonly notifications: NotificationsService,
    @InjectPinoLogger(CommunityService.name)
    private readonly logger: PinoLogger,
  ) {}

  /**
   * Notification poussée au nom de `fromUserId`. N'échoue JAMAIS un flux
   * métier : l'échec est journalisé, l'appel métier aboutit quand même.
   */
  private async notify(
    recipientId: string,
    fromUserId: string,
    category: NotificationCategory,
    compose: (fromName: string) => PushMessage,
  ): Promise<void> {
    if (!this.notifications.pushEnabled) {
      return;
    }
    try {
      const fromName = await this.community.displayNameOf(fromUserId);
      await this.notifications.sendToUser(recipientId, compose(fromName), category);
    } catch (error) {
      this.logger.error({ err: error, recipientId }, 'Notification communauté non envoyée');
    }
  }

  private notifyNewRequest(requesterId: string, addresseeId: string): Promise<void> {
    return this.notify(addresseeId, requesterId, 'FRIEND_REQUESTS', (fromName) => ({
      title: 'Nouvelle demande d’ami',
      body: `${fromName} souhaite devenir ton ami.`,
    }));
  }

  private notifyRequestAccepted(accepterId: string, requesterId: string): Promise<void> {
    return this.notify(requesterId, accepterId, 'FRIEND_REQUESTS', (fromName) => ({
      title: 'Demande acceptée',
      body: `${fromName} a accepté ta demande d’ami.`,
    }));
  }

  // ── Demandes d'ami ──────────────────────────────────────────────────────

  /**
   * Demande par e-mail EXACT — et réponse OPAQUE : l'appelant ne sait jamais
   * si le compte existe (pas d'énumération d'adresses). Si l'autre personne
   * avait déjà demandé, les deux se veulent amis : la demande inverse est
   * acceptée. Les demandes envoyées ne sont pas listées, pour la même raison.
   */
  async requestFriend(userId: string, rawEmail: string): Promise<void> {
    const email = rawEmail.trim().toLowerCase();
    const target = await this.community.findUserIdByEmail(email);
    if (target === null || target.id === userId) {
      return; // Réponse identique dans tous les cas.
    }
    const existing = await this.community.findFriendshipBetween(userId, target.id);
    if (existing === null) {
      await this.community.createRequest(userId, target.id);
      await this.notifyNewRequest(userId, target.id);
      return;
    }
    if (existing.status === FriendRequestStatus.PENDING && existing.requesterId === target.id) {
      // Demandes croisées = amitié voulue des deux côtés.
      await this.community.setRequestStatus(existing.id, FriendRequestStatus.ACCEPTED);
      await this.notifyRequestAccepted(userId, target.id);
      return;
    }
    if (existing.status === FriendRequestStatus.DECLINED && existing.requesterId === userId) {
      // Redemander après un refus : la demande redevient visible chez l'autre.
      await this.community.setRequestStatus(existing.id, FriendRequestStatus.PENDING);
      await this.notifyNewRequest(userId, target.id);
    }
  }

  async listReceivedRequests(userId: string): Promise<FriendRequest[]> {
    const requests = await this.community.listReceivedRequests(userId);
    return requests.map((request) => ({
      id: request.id,
      fromDisplayName: request.requester.profile?.displayName ?? 'Membre Carlys',
      createdAt: request.createdAt.toISOString(),
    }));
  }

  async respondToRequest(userId: string, requestId: string, accept: boolean): Promise<void> {
    const request = await this.community.findRequestById(requestId);
    // Seul le DESTINATAIRE d'une demande en attente peut y répondre.
    if (
      request === null ||
      request.addresseeId !== userId ||
      request.status !== FriendRequestStatus.PENDING
    ) {
      throw new NotFoundException('Demande introuvable.');
    }
    await this.community.setRequestStatus(
      requestId,
      accept ? FriendRequestStatus.ACCEPTED : FriendRequestStatus.DECLINED,
    );
    if (accept) {
      // Le refus, lui, reste SILENCIEUX : personne n'est notifié d'un non.
      await this.notifyRequestAccepted(userId, request.requesterId);
    }
  }

  /** Idempotent : retirer un ami déjà retiré aboutit sans bruit. */
  async removeFriend(userId: string, friendUserId: string): Promise<void> {
    const friendship = await this.community.findFriendshipBetween(userId, friendUserId);
    if (friendship === null || friendship.status !== FriendRequestStatus.ACCEPTED) {
      return;
    }
    await this.community.deleteFriendship(friendship.id);
  }

  // ── Amis et statistiques partagées ──────────────────────────────────────

  async listFriends(userId: string): Promise<CommunityFriend[]> {
    const friends = await this.community.listFriends(userId);
    const now = new Date();
    const from = new Date(now.getTime() - STREAK_WINDOW_DAYS * 24 * 3_600_000);

    return Promise.all(
      friends.map(async (friend) => {
        if (!friend.sharesProgress) {
          // La donnée privée ne QUITTE JAMAIS le serveur.
          return this.present(friend, null, null);
        }
        const starts = await this.community.completedSessionStarts(friend.userId, from);
        const weekAgo = new Date(now.getTime() - 7 * 24 * 3_600_000);
        const weekly = starts.filter((start) => start >= weekAgo).length;
        const streak = computeStreakDays({
          sessionStarts: starts,
          timeZone: friend.timezone,
          now,
        });
        return this.present(friend, streak, weekly);
      }),
    );
  }

  private present(
    friend: FriendRow,
    streakDays: number | null,
    weeklySessions: number | null,
  ): CommunityFriend {
    return {
      userId: friend.userId,
      displayName: friend.displayName,
      sharesProgress: friend.sharesProgress,
      streakDays,
      weeklySessions,
    };
  }

  // ── Fil d'encouragements ────────────────────────────────────────────────

  async feed(userId: string): Promise<EncouragementContract[]> {
    const rows = await this.community.listEncouragements(userId, FEED_LIMIT);
    return rows.map((row) => ({
      id: row.id,
      fromUserId: row.senderId,
      fromDisplayName: row.sender.profile?.displayName ?? 'Membre Carlys',
      message: row.message,
      sentAt: row.createdAt.toISOString(),
    }));
  }

  async encourage(userId: string, recipientUserId: string, message: string): Promise<void> {
    const friendship = await this.community.findFriendshipBetween(userId, recipientUserId);
    if (friendship === null || friendship.status !== FriendRequestStatus.ACCEPTED) {
      // On n'écrit pas chez quelqu'un qui n'est pas un ami. 403, pas 404 :
      // l'appelant connaît déjà cet identifiant (il vient de sa liste d'amis).
      throw new ForbiddenException('Vous ne pouvez encourager que vos amis.');
    }
    await this.community.createEncouragement(userId, recipientUserId, message);
    await this.notify(recipientUserId, userId, 'ENCOURAGEMENTS', (fromName) => ({
      title: `Encouragement de ${fromName}`,
      body: message,
    }));
  }

  // ── Défis collectifs ────────────────────────────────────────────────────

  async listChallenges(userId: string): Promise<ChallengeContract[]> {
    const challenges = await this.community.listOpenChallenges(new Date());
    return challenges.map((challenge) => presentChallenge(challenge, userId));
  }

  async joinChallenge(userId: string, challengeId: string): Promise<ChallengeContract> {
    await this.ensureChallengeOpen(challengeId);
    await this.community.joinChallenge(challengeId, userId);
    return this.challengeOf(userId, challengeId);
  }

  async leaveChallenge(userId: string, challengeId: string): Promise<ChallengeContract> {
    await this.ensureChallengeOpen(challengeId);
    await this.community.leaveChallenge(challengeId, userId);
    return this.challengeOf(userId, challengeId);
  }

  private async ensureChallengeOpen(challengeId: string): Promise<void> {
    const challenge = await this.community.findChallengeById(challengeId);
    if (challenge === null || challenge.endsAt < new Date()) {
      throw new NotFoundException('Défi introuvable ou terminé.');
    }
  }

  private async challengeOf(userId: string, challengeId: string): Promise<ChallengeContract> {
    const challenge = await this.community.challengeStats(challengeId);
    if (challenge === null) {
      throw new NotFoundException('Défi introuvable.');
    }
    return presentChallenge(challenge, userId);
  }

  /**
   * Contribution des défis SPORT à la clôture d'une séance. Ne fait JAMAIS
   * échouer la clôture : un échec est journalisé, le compte se rattrape à la
   * prochaine séance (la barre est collective, pas comptable).
   */
  async recordWorkoutCompleted(userId: string, completedAt: Date): Promise<void> {
    try {
      await this.community.incrementSportContributions(userId, completedAt);
    } catch (error) {
      this.logger.error(
        { err: error, userId },
        'Contribution aux défis non enregistrée — rattrapage à la prochaine séance',
      );
    }
  }

  // ── Réponses de quiz (défis CULTURE) ────────────────────────────────────

  /**
   * Enregistre une réponse de quiz. Seule une réponse JUSTE et NOUVELLE
   * (première fois pour cette leçon ce jour-là) contribue aux défis CULTURE
   * rejoints — rejouer l'envoi ne compte jamais deux fois.
   */
  async recordQuizAnswer(
    userId: string,
    input: { lessonId: string; answeredOn: string; correct: boolean },
  ): Promise<void> {
    const created = await this.community.createQuizAnswer({ userId, ...input });
    if (created && input.correct) {
      await this.community.incrementCultureContributions(userId, new Date());
    }
  }

  // ── Préférence de partage ───────────────────────────────────────────────

  async profile(userId: string): Promise<CommunityProfile> {
    return { sharesProgress: await this.community.sharesProgress(userId) };
  }

  async updateProfile(userId: string, sharesProgress: boolean): Promise<CommunityProfile> {
    await this.community.setSharesProgress(userId, sharesProgress);
    return { sharesProgress };
  }
}
