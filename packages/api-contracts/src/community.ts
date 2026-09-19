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
