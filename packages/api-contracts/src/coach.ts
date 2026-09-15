import { z } from 'zod';
import { workoutSetKindSchema } from './workouts';

/**
 * Contrats du coach IA (/api/v1/coach).
 *
 * **L'IA propose, l'application exécute.** Le coach n'écrit rien : sa seule
 * sortie structurée est une proposition de séance, que l'utilisateur accepte
 * explicitement. La création passe ensuite par le chemin de séance existant.
 *
 * Les identifiants de fil et de message sont des UUID générés SUR L'APPAREIL :
 * un message peut être composé avant que le serveur n'ait jamais entendu
 * parler du fil, et l'envoi est rejouable.
 */

export const coachMessageRoleSchema = z.enum(['USER', 'ASSISTANT']);
export type CoachMessageRole = z.infer<typeof coachMessageRoleSchema>;

/**
 * Série proposée — MÊME FORME qu'une série prévue de séance
 * (`WorkoutSessionPlanItem`), volontairement : accepter une proposition est
 * alors une copie, pas une traduction.
 */
export const coachProposalItemSchema = z.object({
  id: z.string(),
  exercisePosition: z.number(),
  /** Toujours un exercice RÉEL du catalogue — vérifié côté serveur. */
  exerciseId: z.string(),
  exerciseName: z.string(),
  setPosition: z.number(),
  kind: workoutSetKindSchema,
  targetReps: z.number().nullable(),
  targetWeightKg: z.number().nullable(),
  restSeconds: z.number().nullable(),
});
export type CoachProposalItem = z.infer<typeof coachProposalItemSchema>;

export const coachSessionProposalSchema = z.object({
  id: z.string(),
  name: z.string(),
  estimatedMinutes: z.number(),
  /** Modèle dont la proposition est dérivée, s'il y en a un. */
  sourceTemplateId: z.string().nullable(),
  /** Séance réellement lancée depuis cette proposition, le cas échéant. */
  acceptedSessionId: z.string().nullable(),
  items: z.array(coachProposalItemSchema),
});
export type CoachSessionProposal = z.infer<typeof coachSessionProposalSchema>;

export const coachMessageSchema = z.object({
  id: z.string(),
  role: coachMessageRoleSchema,
  content: z.string(),
  /** Proposition rattachée au message, quand le coach en a formulé une. */
  proposal: coachSessionProposalSchema.nullable(),
  createdAt: z.string(),
});
export type CoachMessage = z.infer<typeof coachMessageSchema>;

export const coachConversationSummarySchema = z.object({
  id: z.string(),
  title: z.string().nullable(),
  messagesCount: z.number(),
  updatedAt: z.string(),
});
export type CoachConversationSummary = z.infer<typeof coachConversationSummarySchema>;

export const coachConversationSchema = coachConversationSummarySchema.extend({
  messages: z.array(coachMessageSchema),
});
export type CoachConversation = z.infer<typeof coachConversationSchema>;

/** Réponse à un envoi : le message écrit ET la réplique du coach. */
export const coachReplySchema = z.object({
  userMessage: coachMessageSchema,
  assistantMessage: coachMessageSchema,
  /** Messages restants pour la période en cours, après cet échange. */
  remainingToday: z.number(),
});
export type CoachReply = z.infer<typeof coachReplySchema>;

// Les AMORCES de conversation ne sont pas un contrat d'API, et ne l'ont
// jamais été. Un `coachSuggestionsSchema` vivait ici, présenté comme « calculé
// depuis l'état réel de l'utilisateur » côté serveur : aucune route ne le
// servait, aucun client ne le lisait. Le calcul est LOCAL et l'a toujours été
// (`apps/mobile/lib/features/coaching/domain/services/coach_suggestions.dart`,
// branché par `coach_controllers.dart`) — c'est d'ailleurs le bon endroit :
// les amorces dépendent de ce que l'appareil sait déjà, et n'ont pas à coûter
// un aller-retour réseau. Un contrat publié qui décrit un comportement
// inexistant est pire qu'une absence : il se lit comme une promesse.

// ── Requêtes ──────────────────────────────────────────────────────────────

export const createCoachConversationRequestSchema = z.object({
  id: z.string().uuid(),
});
export type CreateCoachConversationRequest = z.infer<typeof createCoachConversationRequestSchema>;

export const sendCoachMessageRequestSchema = z.object({
  /** UUID du message, généré sur l'appareil : l'envoi est rejouable. */
  id: z.string().uuid(),
  content: z.string().min(1).max(2000),
});
export type SendCoachMessageRequest = z.infer<typeof sendCoachMessageRequestSchema>;

export const acceptCoachProposalRequestSchema = z.object({
  /** Séance née sur l'appareil depuis cette proposition. */
  sessionId: z.string().uuid(),
});
export type AcceptCoachProposalRequest = z.infer<typeof acceptCoachProposalRequestSchema>;
