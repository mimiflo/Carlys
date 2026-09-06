import {
  type CommunityFriend,
  type CommunityProfile,
  type Encouragement as EncouragementContract,
  type FriendCodePreview,
  type FriendRequest,
} from '@carlys/api-contracts';
import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { FriendRequestStatus } from '@prisma/client';
import { CommunityModerationRepository } from '../infrastructure/community-moderation.repository';
import { CommunityRepository, type FriendRow } from '../infrastructure/community.repository';
import { normalizeFriendCode } from '../../users/domain/friend-code';
import { CommunityChallengesService } from './community-challenges.service';
import { CommunityNotifier } from './community-notifier';
import { computeStreakDays } from './streak.calculator';

const FEED_LIMIT = 50;
/** Historique suffisant pour toute série plausible affichée (60 jours). */
const STREAK_WINDOW_DAYS = 60;
/** Après un refus, le même demandeur attend 30 jours avant de pouvoir redemander. */
const DECLINE_COOLDOWN_MS = 30 * 24 * 3_600_000;

/**
 * Amis, demandes, encouragements et préférence de partage.
 *
 * Les blocages sont consultés PARTOUT où deux personnes se rencontrent
 * (demande, aperçu de code, encouragement, listes) et la réponse est
 * OPAQUE : celle d'un compte qui n'existe pas, jamais « tu es bloqué ».
 */
@Injectable()
export class CommunityService {
  constructor(
    private readonly community: CommunityRepository,
    private readonly moderation: CommunityModerationRepository,
    private readonly challenges: CommunityChallengesService,
    /** Les envois n'échouent jamais un flux métier : voir CommunityNotifier. */
    private readonly notifier: CommunityNotifier,
  ) {}

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
    await this.requestFriendTo(userId, target.id);
  }

  /**
   * Demande d'ami par code — le chemin du QR et de l'identifiant partagé.
   * Même réponse opaque que par e-mail : donner un code, c'est déjà dire
   * « ajoute-moi », mais la demande reste une demande, jamais un lien
   * automatique.
   */
  async requestFriendByCode(userId: string, code: string): Promise<void> {
    const normalized = normalizeFriendCode(code);
    if (normalized === null) {
      return; // Un code mal formé ne mérite pas plus de détail qu'un inconnu.
    }
    const target = await this.community.findUserByFriendCode(normalized);
    if (target === null || target.id === userId) {
      return;
    }
    await this.requestFriendTo(userId, target.id);
  }

  /**
   * Aperçu d'un code AVANT d'envoyer la demande : juste le nom, pour que
   * la personne qui scanne ou tape confirme « c'est bien lui ». Un code se
   * partage volontairement et l'espace de recherche (26⁸) rend l'essai en
   * rafale vain — le throttler global coupe court de toute façon.
   */
  async lookupFriendCode(userId: string, code: string): Promise<FriendCodePreview> {
    const normalized = normalizeFriendCode(code);
    const target =
      normalized === null ? null : await this.community.findUserByFriendCode(normalized);
    if (target === null || (await this.moderation.isBlockedEitherWay(userId, target.id))) {
      throw new NotFoundException('Aucun compte ne porte ce code ami.');
    }
    return { displayName: target.profile?.displayName ?? 'Membre Carlys' };
  }

  /**
   * Cœur des demandes : une seule ligne par paire, et trois règles.
   * Demandes croisées = amitié. Un refus est OPPOSABLE : le même demandeur
   * reste muet pendant `DECLINE_COOLDOWN_MS`, sans notification, sinon
   * connaître une adresse suffirait à harceler à coups de demandes. La
   * personne qui a refusé peut, elle, prendre contact quand elle veut : la
   * demande repart alors dans SON sens, comme une demande neuve.
   */
  private async requestFriendTo(userId: string, targetId: string): Promise<void> {
    if (await this.moderation.isBlockedEitherWay(userId, targetId)) {
      return; // Pour chacun des deux, l'autre n'existe plus.
    }
    const existing = await this.community.findFriendshipBetween(userId, targetId);
    if (existing === null) {
      await this.community.createRequest(userId, targetId);
      await this.notifier.newRequest(userId, targetId);
      return;
    }
    if (existing.status === FriendRequestStatus.PENDING) {
      if (existing.requesterId === targetId) {
        // Demandes croisées = amitié voulue des deux côtés.
        await this.community.setRequestStatus(existing.id, FriendRequestStatus.ACCEPTED);
        await this.notifier.requestAccepted(userId, targetId);
      }
      return; // Ma propre demande est déjà en attente : rien à refaire.
    }
    if (existing.status !== FriendRequestStatus.DECLINED) {
      return; // Déjà amis.
    }
    const declinedByMe = existing.requesterId === targetId;
    const declinedAt = (existing.respondedAt ?? existing.createdAt).getTime();
    if (!declinedByMe && Date.now() - declinedAt < DECLINE_COOLDOWN_MS) {
      return; // Refus opposable : même silence qu'un compte inexistant.
    }
    await this.community.reopenRequest(existing.id, userId, targetId);
    await this.notifier.newRequest(userId, targetId);
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
      await this.notifier.requestAccepted(userId, request.requesterId);
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
    const [allFriends, hidden] = await Promise.all([
      this.community.listFriends(userId),
      this.moderation.blockedUserIdsEitherWay(userId),
    ]);
    // Bloquer retire déjà l'amitié ; le filtre garantit qu'aucune ligne
    // résiduelle ne ressorte, dans un sens comme dans l'autre.
    const friends = allFriends.filter((friend) => !hidden.has(friend.userId));
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

  /** Le fil tait les personnes bloquées, dans un sens comme dans l'autre. */
  async feed(userId: string): Promise<EncouragementContract[]> {
    const hidden = await this.moderation.blockedUserIdsEitherWay(userId);
    const rows = await this.community.listEncouragements(userId, FEED_LIMIT, [...hidden]);
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
    if (
      friendship === null ||
      friendship.status !== FriendRequestStatus.ACCEPTED ||
      (await this.moderation.isBlockedEitherWay(userId, recipientUserId))
    ) {
      // On n'écrit pas chez quelqu'un qui n'est pas un ami. 403, pas 404 :
      // l'appelant connaît déjà cet identifiant (il vient de sa liste d'amis).
      // Un blocage répond pareil : rien ne distingue « bloqué » de « plus ami ».
      throw new ForbiddenException('Tu ne peux encourager que tes amis.');
    }
    await this.community.createEncouragement(userId, recipientUserId, message);
    await this.notifier.encouragement(recipientUserId, userId, message);
  }

  // ── Défis (point d'entrée des autres modules) ───────────────────────────

  /**
   * Contribution des défis SPORT à la clôture d'une séance. Le module des
   * séances ne connaît que ce service : la logique vit dans
   * `CommunityChallengesService`, ceci ne fait que déléguer.
   */
  recordWorkoutCompleted(userId: string, completedAt: Date): Promise<void> {
    return this.challenges.recordWorkoutCompleted(userId, completedAt);
  }

  // ── Préférence de partage ───────────────────────────────────────────────

  async profile(userId: string): Promise<CommunityProfile> {
    return {
      sharesProgress: await this.community.sharesProgress(userId),
      friendCode: await this.community.friendCodeOf(userId),
    };
  }

  async updateProfile(userId: string, sharesProgress: boolean): Promise<CommunityProfile> {
    await this.community.setSharesProgress(userId, sharesProgress);
    return { sharesProgress, friendCode: await this.community.friendCodeOf(userId) };
  }
}
