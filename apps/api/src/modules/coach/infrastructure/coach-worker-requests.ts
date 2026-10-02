import { ServiceUnavailableException } from '@nestjs/common';
import { setTimeout as wait } from 'node:timers/promises';
import { type AppConfigService } from '../../../config/app-config.service';
import { type ChatCompletion } from './chat-completion-stream';
import { type CoachWorkerPool } from './coach-worker-pool';
import { GenerationFailure } from './generation-end';
import { readCompletion, refusalReason } from './openai-compatible.helpers';

/** Nouvelles tentatives (429, 5xx, worker injoignable), chacune sur un AUTRE worker s'il y en a. */
const RETRIES = 2;
const RETRY_DELAY_MS = 1000;

/**
 * Une requête Chat Completions à l'un de nos workers : choix du worker,
 * nouvelles tentatives, et délai d'INACTIVITÉ du flux.
 *
 * L'échéance du tour est un plafond, pas une mesure de panne : sur le
 * processeur du serveur (≈ 8 jetons/s), une longue réponse prend légitimement
 * plusieurs minutes. Un worker en panne, lui, se tait : passé
 * `COACH_STREAM_IDLE_TIMEOUT_MS` sans un octet APRÈS le premier, l'appel est
 * coupé (`TIMEOUT`) et la réponse reprend ailleurs (answer-continuation.ts).
 * Avant le premier octet, rien ne compte que l'échéance : relire un long
 * contexte prend du temps sans rien envoyer.
 */
export class CoachWorkerRequests {
  constructor(
    private readonly config: AppConfigService,
    private readonly pool: CoachWorkerPool,
  ) {}

  /** Une requête au modèle, sur `prefer` s'il est sain ; `retries` nouvelles tentatives. */
  async complete(
    payload: Record<string, unknown>,
    signal: AbortSignal,
    onText: ((delta: string) => void) | undefined,
    maxOutputTokens: number,
    prefer?: string,
    retries = RETRIES,
  ): Promise<{ completion: ChatCompletion; served: string }> {
    // En flux, l'usage n'arrive que si on le demande (dernier morceau).
    const stream = onText ? { stream: true, stream_options: { include_usage: true } } : {};
    const { apiKey, model } = this.config.coachProvider;
    const body = JSON.stringify({ model, max_tokens: maxOutputTokens, ...payload, ...stream });
    const tried = new Set<string>();
    for (let attempt = 0; ; attempt++) {
      const worker = this.pool.acquire(tried, prefer);
      const idle = this.idleWatch();
      // Panne DU WORKER (réseau, 5xx, flux rompu ou muet) : il est écarté un
      // temps. Jamais une annulation ni une échéance, qui ne disent rien de lui.
      let failed = false;
      try {
        const response = await fetch(`${worker.url.replace(/\/+$/, '')}/chat/completions`, {
          method: 'POST',
          // Sans flux, rien n'arrive avant la fin : l'échéance seule compte.
          signal: onText ? AbortSignal.any([signal, idle.signal]) : signal,
          headers: {
            'Content-Type': 'application/json',
            ...(apiKey === undefined ? {} : { Authorization: `Bearer ${apiKey}` }),
          },
          body,
        }).catch((error: unknown) => {
          failed = !signal.aborted;
          if (signal.aborted) throw error;
          if (attempt === retries) {
            const name = error instanceof Error ? error.name : 'inconnue';
            throw new GenerationFailure(
              `Coach : fournisseur injoignable (${name}).`,
              'WORKER_ERROR',
            );
          }
          return null;
        });
        if (response?.ok) {
          const completion = await readCompletion(response, onText, idle.touch).catch(
            (error: unknown) => {
              failed = !signal.aborted;
              if (signal.aborted || error instanceof GenerationFailure) throw error;
              if (idle.signal.aborted) throw new GenerationFailure('Coach : flux muet.', 'TIMEOUT');
              // Connexion coupée en plein flux (« terminated »).
              const name = error instanceof Error ? error.name : 'inconnue';
              throw new GenerationFailure(`Coach : flux rompu (${name}).`, 'STREAM_ERROR');
            },
          );
          return { completion, served: worker.name };
        }
        if (response !== null) {
          failed = response.status >= 500;
          await this.refuse(response, attempt === retries);
        }
      } finally {
        idle.stop();
        this.pool.release(worker, failed);
      }
      tried.add(worker.url);
      await wait(RETRY_DELAY_MS * (attempt + 1), undefined, { signal });
    }
  }

  /**
   * Un refus : une erreur, sauf 429 ou 5xx avec un essai restant (le corps
   * est alors jeté). Jamais relayé tel quel : un 429 du fournisseur (quota
   * GLOBAL) s'afficherait « limite du jour » sur le téléphone.
   */
  private async refuse(response: Response, last: boolean): Promise<void> {
    const retryable = response.status === 429 || response.status >= 500;
    if (response.status === 400) {
      // Lu pour sa SEULE nature, jamais journalisé : il peut citer la demande.
      const reason = await response.text().catch(() => '');
      if (/context/i.test(reason)) {
        throw new GenerationFailure('Coach : contexte du modèle dépassé.', 'CONTEXT_LIMIT');
      }
      throw new ServiceUnavailableException('Coach : le fournisseur a répondu 400.');
    }
    if (!retryable || last) {
      const message = `Coach : le fournisseur a répondu ${response.status}${await refusalReason(response, retryable)}.`;
      if (retryable) throw new GenerationFailure(message, 'WORKER_ERROR');
      throw new ServiceUnavailableException(message);
    }
    await response.body?.cancel();
  }

  /** Coupe l'appel quand le flux se tait, une fois commencé. */
  private idleWatch() {
    const controller = new AbortController();
    const idleMs = this.config.coachGateway.streamIdleTimeoutMs;
    let timer: NodeJS.Timeout | undefined;
    return {
      signal: controller.signal,
      touch: () => {
        clearTimeout(timer);
        timer = setTimeout(() => controller.abort(), idleMs);
      },
      stop: () => clearTimeout(timer),
    };
  }
}
