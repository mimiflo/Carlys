import { z } from 'zod';

/**
 * Contrats de la communauté (/api/v1/community).
 *
 * La séparation public/privé est décidée par le SERVEUR : quand un ami ne
 * partage pas sa progression, `streakDays` et `weeklySessions` sont `null`
 * — le client n'a jamais la donnée, il ne peut donc pas la montrer.
 */

export const communityFriendSchema = z.object({
  userId: z.string(),
  displayName: z.string(),
  sharesProgress: z.boolean(),
  /** Jours consécutifs avec séance — `null` si la progression est privée. */
  streakDays: z.number().nullable(),
  /** Séances terminées sur les 7 derniers jours — `null` si privée. */
  weeklySessions: z.number().nullable(),
});
export type CommunityFriend = z.infer<typeof communityFriendSchema>;

/** Demande d'ami REÇUE. Les demandes envoyées ne sont jamais listées :
 *  c'est ce qui rend l'envoi par e-mail non énumérable. */
export const friendRequestSchema = z.object({
  id: z.string(),
  fromDisplayName: z.string(),
  createdAt: z.string(),
});
export type FriendRequest = z.infer<typeof friendRequestSchema>;

export const encouragementSchema = z.object({
  id: z.string(),
  fromUserId: z.string(),
  fromDisplayName: z.string(),
  message: z.string(),
  sentAt: z.string(),
});
export type Encouragement = z.infer<typeof encouragementSchema>;

export const challengeKindSchema = z.enum(['SPORT', 'CULTURE']);
export type ChallengeKind = z.infer<typeof challengeKindSchema>;

/**
 * CE QU'UN DÉFI COMPTE. `kind` ne disait que la famille ; l'unité vivait en
 * prose dans le catalogue et en `+1` codé en dur côté serveur, donc un défi
 * « 500 km ensemble » ne pouvait pas s'exprimer.
 */
export const challengeMetricSchema = z.enum([
  'WORKOUTS',
  'QUIZ_CORRECT',
  'ACTIVE_SECONDS',
  'DISTANCE_METERS',
]);
export type ChallengeMetric = z.infer<typeof challengeMetricSchema>;

export const communityChallengeSchema = z.object({
  id: z.string(),
  kind: challengeKindSchema,
  metric: challengeMetricSchema,
  /**
   * L'unité écrite en toutes lettres (« séances », « mètres »), servie par
   * le serveur comme le titre et la description : deux endroits où nommer la
   * même unité, c'est un endroit de trop pour la faire diverger.
   */
  unit: z.string(),
  title: z.string(),
  description: z.string(),
  /** Objectif collectif, dans l'unité de `metric`. */
  target: z.number(),
  /**
   * Somme BRUTE des contributions, non bornée : c'est elle qui permet
   * d'écrire « 127 / 500 séances » là où le seul ratio ne disait rien, et
   * un groupe qui dépasse son objectif mérite de le voir.
   */
  totalContribution: z.number(),
  /** Progression COLLECTIVE, bornée à [0, 1]. */
  progress: z.number(),
  participants: z.number(),
  joined: z.boolean(),
  endsAt: z.string(),
});
export type CommunityChallenge = z.infer<typeof communityChallengeSchema>;

/** Forme canonique d'un code ami : 8 caractères d'un alphabet sans
 *  ambiguïté visuelle (ni 0/O, ni 1/I/L…) — la normalisation des saisies
 *  (casse, tirets, préfixe QR) est faite AVANT validation. */
export const friendCodeSchema = z.string().regex(/^[23456789ACDEFHJKMNPRTUVWXY]{8}$/);
export type FriendCode = z.infer<typeof friendCodeSchema>;

/** Aperçu renvoyé par la résolution d'un code ami : juste de quoi
 *  confirmer « c'est bien elle/lui » avant d'envoyer la demande. */
export const friendCodePreviewSchema = z.object({
  displayName: z.string(),
});
export type FriendCodePreview = z.infer<typeof friendCodePreviewSchema>;

export const communityProfileSchema = z.object({
  sharesProgress: z.boolean(),
  /** Mon code ami — affiché en XXXX-XXXX et porté par le QR de profil. */
  friendCode: friendCodeSchema,
});
export type CommunityProfile = z.infer<typeof communityProfileSchema>;

// ── Modération : blocages et signalements ─────────────────────────────────

/**
 * Personne que J'AI bloquée (GET /community/blocks). Un blocage est
 * unilatéral et opaque : l'autre n'en est jamais informé, il ne voit qu'un
 * compte qui n'existe plus (demande muette, code ami inconnu, encouragement
 * refusé). Bloquer retire l'amitié et les demandes en attente dans les deux
 * sens ; débloquer ne les rétablit pas.
 */
export const blockedUserSchema = z.object({
  userId: z.string(),
  displayName: z.string(),
  blockedAt: z.string(),
});
export type BlockedUser = z.infer<typeof blockedUserSchema>;

export const communityReportReasonSchema = z.enum([
  'HARCELEMENT',
  'SPAM',
  'CONTENU_INAPPROPRIE',
  'AUTRE',
]);
export type CommunityReportReason = z.infer<typeof communityReportReasonSchema>;

export const communityReportStatusSchema = z.enum(['OPEN', 'RESOLVED']);
export type CommunityReportStatus = z.infer<typeof communityReportStatusSchema>;

/** Longueur maximale des précisions d'un signalement. */
export const COMMUNITY_REPORT_DETAILS_MAX_LENGTH = 500;

/** POST /community/reports — signaler une personne, ou un encouragement précis. */
export const createCommunityReportSchema = z.object({
  reportedUserId: z.string().uuid(),
  /** Encouragement visé : doit avoir été envoyé PAR la personne signalée AU signalant. */
  encouragementId: z.string().uuid().optional(),
  reason: communityReportReasonSchema,
  details: z.string().max(COMMUNITY_REPORT_DETAILS_MAX_LENGTH).optional(),
});
export type CreateCommunityReport = z.infer<typeof createCommunityReportSchema>;

/**
 * Signalement tel que le voit son AUTEUR : l'accusé de réception. Un
 * signalement OUVERT identique (même personne, même encouragement) n'est pas
 * dupliqué : le rejeu rend le même.
 */
export const communityReportSchema = z.object({
  id: z.string(),
  reportedUserId: z.string(),
  encouragementId: z.string().nullable(),
  reason: communityReportReasonSchema,
  details: z.string().nullable(),
  status: communityReportStatusSchema,
  createdAt: z.string(),
  resolvedAt: z.string().nullable(),
});
export type CommunityReport = z.infer<typeof communityReportSchema>;

/**
 * GET /community/quiz-answers — les leçons de l'Academy déjà répondues,
 * relues pour reconstruire la progression sur un nouvel appareil.
 *
 * Une entrée par leçon : la PREMIÈRE réponse fait foi, comme sur l'appareil
 * (le magasin local applique « la première gagne »). `choiceIndex` est
 * `null` sur les réponses enregistrées avant que le choix ne soit transmis :
 * on sait que la leçon a été abordée, pas ce qui a été coché.
 */
export const quizAnswerRecordSchema = z.object({
  lessonId: z.string(),
  choiceIndex: z.number().int().nullable(),
  correct: z.boolean(),
  /** Jour LOCAL de l'appareil au moment de la réponse (YYYY-MM-DD). */
  answeredOn: z.string(),
});
export type QuizAnswerRecord = z.infer<typeof quizAnswerRecordSchema>;

// ── Défis entre amis (Plan 7) ───────────────────────────────────────────────

/**
 * Durées offertes. Trois valeurs, et pas un champ libre : un défi « entre
 * amis » de 400 jours n'est plus un défi, c'est une dette. La liste est du
 * CODE — l'allonger ne demande pas de migration.
 */
export const FRIEND_CHALLENGE_DURATIONS = [3, 7, 30] as const;
export type FriendChallengeDuration = (typeof FRIEND_CHALLENGE_DURATIONS)[number];

/** Nombre d'invités en plus du créateur. Au-delà, ce n'est plus « entre amis ». */
export const FRIEND_CHALLENGE_MAX_INVITES = 9;

/**
 * Défis OUVERTS qu'une personne peut avoir créés en même temps.
 *
 * Sans ce plafond, l'invitation devient un canal d'envoi de messages vers
 * quelqu'un qui ne l'a pas demandé — exactement ce que le refus opposable
 * des demandes d'ami avait fermé.
 */
export const FRIEND_CHALLENGE_MAX_OPEN_PER_CREATOR = 5;

export const friendChallengeStatusSchema = z.enum(['OPEN', 'CLOSED', 'CANCELLED']);
export type FriendChallengeStatus = z.infer<typeof friendChallengeStatusSchema>;

export const friendChallengeMemberStatusSchema = z.enum([
  'INVITED',
  'ACCEPTED',
  'DECLINED',
  'LEFT',
]);
export type FriendChallengeMemberStatus = z.infer<typeof friendChallengeMemberStatusSchema>;

/** Une ligne du classement : qui, combien, et à quelle place. */
export const friendChallengeMemberSchema = z.object({
  userId: z.string(),
  displayName: z.string(),
  status: friendChallengeMemberStatusSchema,
  contribution: z.number(),
  /**
   * Rang courant pendant le défi, FIGÉ à la clôture. `null` pour qui n'a pas
   * encore accepté : on ne classe pas quelqu'un qui n'a rien accepté.
   */
  rank: z.number().nullable(),
  isMe: z.boolean(),
});
export type FriendChallengeMember = z.infer<typeof friendChallengeMemberSchema>;

export const friendChallengeSchema = z.object({
  id: z.string(),
  title: z.string(),
  metric: challengeMetricSchema,
  unit: z.string(),
  /** Objectif commun, ou `null` : c'est alors « qui en fait le plus ». */
  target: z.number().nullable(),
  status: friendChallengeStatusSchema,
  startsAt: z.string(),
  endsAt: z.string(),
  creatorDisplayName: z.string(),
  /** L'état de l'appelant DANS ce défi — ce qui décide des boutons offerts. */
  myStatus: friendChallengeMemberStatusSchema,
  members: z.array(friendChallengeMemberSchema),
});
export type FriendChallenge = z.infer<typeof friendChallengeSchema>;

/**
 * Corps de `POST /community/friend-challenges`.
 *
 * L'identifiant vient de l'appareil, comme partout ailleurs : rejouer la
 * création après une coupure ne crée pas un second défi. `endsAt` n'y figure
 * PAS — le serveur le calcule depuis la durée, sinon une seule requête
 * suffirait à poser un défi éternel.
 */
export const createFriendChallengeRequestSchema = z.object({
  id: z.string().uuid(),
  title: z.string().trim().min(1).max(80),
  metric: challengeMetricSchema,
  target: z.number().int().positive().max(10_000_000).nullable().optional(),
  durationDays: z.union([z.literal(3), z.literal(7), z.literal(30)]),
  /** Amis invités — au moins un : un défi contre personne n'en est pas un. */
  invitedUserIds: z.array(z.string().uuid()).min(1).max(FRIEND_CHALLENGE_MAX_INVITES),
});
export type CreateFriendChallengeRequest = z.infer<typeof createFriendChallengeRequestSchema>;

// ──────────────────────────────── Ligues ─────────────────────────────────

/**
 * Les cinq divisions, de la plus basse à la plus haute. L'ordre EST le
 * barème : le mobile s'en sert pour dessiner l'échelle.
 */
export const leagueDivisionSchema = z.enum(['BRONZE', 'ARGENT', 'OR', 'PLATINE', 'DIAMANT']);
export type LeagueDivision = z.infer<typeof leagueDivisionSchema>;

/** Une ligne du classement de division. */
export const leagueStandingSchema = z.object({
  userId: z.string(),
  displayName: z.string(),
  /** Points de la période, jamais l'unité brute d'une métrique. */
  score: z.number(),
  /** Rang courant, FIGÉ dès que la période est réglée. */
  rank: z.number(),
  isMe: z.boolean(),
});
export type LeagueStanding = z.infer<typeof leagueStandingSchema>;

/**
 * Ce que la ligue rend en une lecture.
 *
 * `joined` à `false` décrit une ligue à laquelle on n'a PAS adhéré : le
 * classement est alors vide, et l'écran montre l'invitation à entrer. La
 * ligue est un opt-in — voir `docs/product/community.md`, principe 5.
 */
export const leagueSchema = z.object({
  joined: z.boolean(),
  /** Semaine ISO en UTC, `YYYY-Www`. */
  periodKey: z.string(),
  /** Fin de la période, en ISO 8601 : ce qui écrit « il reste 3 jours ». */
  endsAt: z.string(),
  division: leagueDivisionSchema,
  /** Mon score de la période, 0 tant que rien n'a été versé. */
  score: z.number(),
  standings: z.array(leagueStandingSchema),
  /**
   * Le résultat de la période PRÉCÉDENTE, s'il vient d'être réglé et qu'on
   * y figurait : c'est ce qui permet d'annoncer une montée ou une descente
   * une fois, au lieu d'un changement de division sans explication.
   */
  lastResult: z
    .object({
      periodKey: z.string(),
      rank: z.number(),
      from: leagueDivisionSchema,
      to: leagueDivisionSchema,
    })
    .nullable(),
});
export type League = z.infer<typeof leagueSchema>;
