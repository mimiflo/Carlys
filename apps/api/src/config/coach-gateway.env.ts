import { type ConfigService } from '@nestjs/config';
import { z } from 'zod';
import { type Env } from './env.schema';

/**
 * Réglages de la passerelle du coach (ADR 0013) : combien de générations à la
 * fois, combien d'attentes, quelles limites par personne, quels workers.
 *
 * Tous ont un défaut sûr pour UNE machine sans carte graphique : une
 * génération à la fois, vingt attentes au plus. Passer à plusieurs workers,
 * c'est relever `COACH_MAX_CONCURRENT_REQUESTS` à la somme de leurs
 * `OLLAMA_NUM_PARALLEL` et lister leurs adresses dans `COACH_WORKER_URLS`.
 */
const int = (min: number, max: number, fallback: number) =>
  z.coerce.number().int().min(min).max(max).default(fallback);

export const coachGatewayEnv = {
  /** Générations simultanées, tous exemplaires de l'API et tous workers confondus. */
  COACH_MAX_CONCURRENT_REQUESTS: int(1, 256, 1),
  /** Attentes au-delà desquelles une demande est refusée (503 SERVICE_BUSY). */
  COACH_QUEUE_MAX_SIZE: int(0, 10_000, 20),
  /** Attente maximale dans la file avant d'abandonner la demande. */
  COACH_QUEUE_TIMEOUT_MS: int(1_000, 600_000, 120_000),
  /**
   * Plafond d'une génération EN FLUX, file non comprise — reprises comprises.
   * Un plafond, pas la mesure d'une panne : c'est le rôle du délai
   * d'inactivité ci-dessous.
   */
  COACH_REQUEST_TIMEOUT_MS: int(10_000, 900_000, 600_000),
  /** Silence toléré d'un flux déjà commencé avant de le tenir pour mort. */
  COACH_STREAM_IDLE_TIMEOUT_MS: int(5_000, 300_000, 60_000),
  /** Jetons de sortie par appel au modèle (une reprise est un autre appel). */
  COACH_MAX_OUTPUT_TOKENS: int(16, 8_192, 2_048),
  /** Reprises d'une réponse coupée, au plus, par appel au modèle. */
  COACH_MAX_CONTINUATIONS: int(0, 5, 2),
  /**
   * Contexte du modèle, en jetons : celui des workers (`OLLAMA_CONTEXT_LENGTH`).
   * L'historique le plus ancien cède pour y garder la place de la réponse.
   */
  COACH_CONTEXT_TOKENS: int(2_048, 1_000_000, 8_192),
  /** Générations simultanées pour UNE personne (file comprise). */
  COACH_MAX_CONCURRENT_PER_USER: int(1, 10, 1),
  /** Messages par personne et par minute, en plus du plafond quotidien. */
  COACH_MESSAGES_PER_MINUTE: int(1, 120, 6),
  /** Taille d'un message ; le contrat d'API en borne déjà 2 000. */
  COACH_MAX_MESSAGE_CHARS: int(1, 2_000, 2_000),
  /** Derniers messages relus tels quels ; les plus anciens passent par le résumé. */
  COACH_HISTORY_MESSAGES: int(2, 50, 20),
  /**
   * Adresses « …/v1 » des workers, séparées par des virgules. Absente : le
   * seul worker est `COACH_API_BASE_URL`.
   */
  COACH_WORKER_URLS: z
    .string()
    .optional()
    .refine(
      (value) =>
        value === undefined ||
        value
          .split(',')
          .map((entry) => entry.trim())
          .filter((entry) => entry !== '')
          .every(
            (entry) => z.string().url().safeParse(entry).success && /^https?:\/\//.test(entry),
          ),
      'COACH_WORKER_URLS doit lister des URL http(s) séparées par des virgules',
    ),
  /** Mise à l'écart d'un worker en panne avant de le réessayer. */
  COACH_WORKER_COOLDOWN_MS: int(1_000, 600_000, 30_000),
  /**
   * Repli sur le fournisseur cloud (Anthropic) quand aucun worker ne répond.
   * ÉTEINT par défaut : payant, et les textes légaux doivent le nommer avant.
   */
  COACH_CLOUD_FALLBACK: z
    .enum(['true', 'false'])
    .default('false')
    .transform((value) => value === 'true'),
};

export interface CoachGatewaySettings {
  dailyMessageLimit: number;
  maxConcurrent: number;
  queueMaxSize: number;
  queueTimeoutMs: number;
  requestTimeoutMs: number;
  streamIdleTimeoutMs: number;
  maxOutputTokens: number;
  maxContinuations: number;
  contextTokens: number;
  maxConcurrentPerUser: number;
  messagesPerMinute: number;
  maxMessageChars: number;
  historyMessages: number;
  workerUrls: string[];
  workerCooldownMs: number;
  cloudFallback: boolean;
}

/** Les réglages lus, et la liste des workers dépliée. */
export function coachGatewaySettings(config: ConfigService<Env, true>): CoachGatewaySettings {
  const get = <K extends keyof Env>(key: K): Env[K] => config.get(key, { infer: true });
  const fallbackBaseUrl = get('COACH_API_BASE_URL');
  const listed = (get('COACH_WORKER_URLS') ?? '')
    .split(',')
    .map((entry) => entry.trim())
    .filter((entry) => entry !== '');
  return {
    dailyMessageLimit: get('COACH_DAILY_MESSAGE_LIMIT'),
    maxConcurrent: get('COACH_MAX_CONCURRENT_REQUESTS'),
    queueMaxSize: get('COACH_QUEUE_MAX_SIZE'),
    queueTimeoutMs: get('COACH_QUEUE_TIMEOUT_MS'),
    requestTimeoutMs: get('COACH_REQUEST_TIMEOUT_MS'),
    streamIdleTimeoutMs: get('COACH_STREAM_IDLE_TIMEOUT_MS'),
    maxOutputTokens: get('COACH_MAX_OUTPUT_TOKENS'),
    maxContinuations: get('COACH_MAX_CONTINUATIONS'),
    contextTokens: get('COACH_CONTEXT_TOKENS'),
    maxConcurrentPerUser: get('COACH_MAX_CONCURRENT_PER_USER'),
    messagesPerMinute: get('COACH_MESSAGES_PER_MINUTE'),
    maxMessageChars: get('COACH_MAX_MESSAGE_CHARS'),
    historyMessages: get('COACH_HISTORY_MESSAGES'),
    workerUrls: listed.length > 0 ? listed : fallbackBaseUrl === undefined ? [] : [fallbackBaseUrl],
    workerCooldownMs: get('COACH_WORKER_COOLDOWN_MS'),
    cloudFallback: get('COACH_CLOUD_FALLBACK'),
  };
}
