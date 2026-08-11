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

export const communityChallengeSchema = z.object({
  id: z.string(),
  kind: challengeKindSchema,
  title: z.string(),
  description: z.string(),
  /** Objectif collectif (séances, répétitions, bonnes réponses…). */
  target: z.number(),
  /** Progression COLLECTIVE, bornée à [0, 1]. */
  progress: z.number(),
  participants: z.number(),
  joined: z.boolean(),
  endsAt: z.string(),
});
export type CommunityChallenge = z.infer<typeof communityChallengeSchema>;

export const communityProfileSchema = z.object({
  sharesProgress: z.boolean(),
});
export type CommunityProfile = z.infer<typeof communityProfileSchema>;
