import { HttpException, ServiceUnavailableException } from '@nestjs/common';
import { setTimeout as wait } from 'node:timers/promises';
import { type AppConfigService } from '../../../config/app-config.service';
import { PROPOSE_SESSION_TOOL } from '../application/coach.tool-definitions';
import {
  COACH_GAVE_UP_TEXT,
  COACH_MAX_TOOL_ROUNDS,
  CoachProviderUnavailableException,
  type CoachModelPort,
  type CoachToolCall,
  type CoachToolResult,
  type CoachTurnInput,
  type CoachTurnOutput,
  type CoachTurnUsage,
  turnSignal,
} from '../domain/coach-model.port';
import { type ChatCompletion, readChatStream } from './chat-completion-stream';
import { type CoachWorkerPool } from './coach-worker-pool';

/**
 * Nouvelles tentatives sur un 429, un 5xx ou un worker injoignable, comme le
 * SDK Anthropic — chacune sur un AUTRE worker quand il y en a un.
 */
const RETRIES = 2;
const RETRY_DELAY_MS = 1000;

/**
 * Client d'une API **compatible OpenAI** (Chat Completions) : le fournisseur
 * LOCAL — nos Ollama, un ou plusieurs (`CoachWorkerPool`, ADR 0013) — ou
 * tout service qui parle la même langue. `fetch` natif, sans SDK : un seul
 * `POST`, comme `subscriptions/infrastructure/stripe-form-request.ts`.
 *
 * Aucun cache explicite ici : `cacheReadTokens` vaut ce que le fournisseur
 * déclare (souvent 0), ce n'est pas un préfixe cassé.
 */
export class OpenAiCompatibleCoachClient implements CoachModelPort {
  constructor(
    private readonly config: AppConfigService,
    private readonly pool: CoachWorkerPool,
  ) {}

  async reply(input: CoachTurnInput): Promise<CoachTurnOutput> {
    // UNE échéance pour tout le tour, tentatives et outils compris.
    const signal = turnSignal(input, this.config.coachGateway.requestTimeoutMs);
    const messages: Record<string, unknown>[] = [
      { role: 'system', content: input.system },
      ...(input.systemPerUser ? [{ role: 'system', content: input.systemPerUser }] : []),
      ...input.history,
    ];
    const tools = input.tools.map((tool) => ({
      type: 'function',
      function: { name: tool.name, description: tool.description, parameters: tool.inputSchema },
    }));
    const usage = { inputTokens: 0, outputTokens: 0, cacheReadTokens: 0 };
    let proposal: Record<string, unknown> | null = null;
    // Dernier texte non vide : la phrase dite AVEC une proposition survit à
    // un dernier tour vide.
    let said = '';
    // En flux : du texte déjà montré (`shown`), et dans CE tour (`spoke`). Un
    // tour d'outils qui parlait ne se colle pas au suivant : un saut de
    // paragraphe les sépare, le temps que la réplique archivée les remplace.
    let shown = false;
    let spoke = false;
    let worker: string | undefined;
    const onText =
      input.onText &&
      ((text: string) => {
        if (shown && !spoke) input.onText?.('\n\n');
        shown = spoke = true;
        input.onText?.(text);
      });

    for (let round = 0; round < COACH_MAX_TOOL_ROUNDS; round++) {
      spoke = false;
      const { completion, served } = await this.complete(
        { messages, tools },
        signal,
        onText,
        input.maxOutputTokens ?? this.config.coachGateway.maxOutputTokens,
      ).catch((error: unknown) => unavailable(error, usage, shown));
      worker = served;
      usage.inputTokens += completion.usage?.prompt_tokens ?? 0;
      usage.outputTokens += completion.usage?.completion_tokens ?? 0;
      usage.cacheReadTokens += completion.usage?.prompt_tokens_details?.cached_tokens ?? 0;

      const choice = completion.choices?.[0];
      if (choice?.finish_reason === 'error') {
        // Mistral : génération coupée chez lui, texte tronqué à ne pas archiver.
        throw new CoachProviderUnavailableException('Coach : génération interrompue.', usage);
      }
      said = textOf(choice?.message?.content) || said;
      // Sur la PRÉSENCE d'appels, jamais sur `finish_reason` : certains
      // fournisseurs rendent « stop » avec des appels d'outils.
      const toolCalls = choice?.message?.tool_calls ?? [];
      if (toolCalls.length === 0) {
        return {
          text: said || COACH_GAVE_UP_TEXT,
          proposal,
          usage,
          refused: false,
          worker,
          model: this.config.coachProvider.model,
        };
      }

      // Appel sans `function` (passerelle non conforme) : nom vide, que les
      // outils refusent comme inconnu, plutôt qu'un 500.
      const calls: CoachToolCall[] = toolCalls.map((call) => ({
        id: call.id,
        name: call.function?.name ?? '',
        input: parseArguments(call.function?.arguments),
      }));
      // `propose_session` n'est pas exécutée : elle est RETENUE, puis validée
      // par le serveur avant d'exister.
      proposal = calls.find((call) => call.name === PROPOSE_SESSION_TOOL)?.input ?? proposal;
      const results = await input.runTools(calls.filter((c) => c.name !== PROPOSE_SESSION_TOOL));

      messages.push({
        role: 'assistant',
        // Chaîne vide plutôt que null : la forme de l'exemple de Mistral.
        content: choice?.message?.content ?? '',
        tool_calls: toolCalls,
      });
      for (const call of calls) {
        messages.push({ role: 'tool', tool_call_id: call.id, content: toolReply(call, results) });
      }
    }

    return {
      text: COACH_GAVE_UP_TEXT,
      proposal,
      usage,
      refused: false,
      worker,
      model: this.config.coachProvider.model,
    };
  }

  private async complete(
    payload: Record<string, unknown>,
    signal: AbortSignal,
    onText: ((delta: string) => void) | undefined,
    maxOutputTokens: number,
  ): Promise<{ completion: ChatCompletion; served: string }> {
    // En flux, l'usage n'arrive que si on le demande (dernier morceau).
    const stream = onText ? { stream: true, stream_options: { include_usage: true } } : {};
    const { apiKey, model } = this.config.coachProvider;
    const body = JSON.stringify({
      model,
      max_tokens: maxOutputTokens,
      ...payload,
      ...stream,
    });
    const tried = new Set<string>();
    for (let attempt = 0; ; attempt++) {
      const worker = this.pool.acquire(tried);
      // Panne DU WORKER (réseau, 5xx, flux rompu) : il est écarté un temps.
      // Jamais une annulation ni une échéance, qui ne disent rien de lui.
      let failed = false;
      try {
        const response = await fetch(`${worker.url.replace(/\/+$/, '')}/chat/completions`, {
          method: 'POST',
          signal,
          headers: {
            'Content-Type': 'application/json',
            ...(apiKey === undefined ? {} : { Authorization: `Bearer ${apiKey}` }),
          },
          body,
        }).catch((error: unknown) => {
          failed = !signal.aborted;
          if (signal.aborted || attempt === RETRIES) throw error;
          return null;
        });
        if (response?.ok) {
          const completion = await readCompletion(response, onText).catch((error: unknown) => {
            failed = !signal.aborted;
            throw error;
          });
          return { completion, served: worker.name };
        }
        if (response !== null) {
          const retryable = response.status === 429 || response.status >= 500;
          failed = response.status >= 500;
          if (!retryable || attempt === RETRIES) {
            // Jamais relayé tel quel : un 429 du fournisseur (quota GLOBAL)
            // s'afficherait « limite du jour » sur le téléphone.
            throw new ServiceUnavailableException(
              `Coach : le fournisseur a répondu ${response.status}${await refusalReason(response, retryable)}.`,
            );
          }
          await response.body?.cancel();
        }
      } finally {
        this.pool.release(worker, failed);
      }
      tried.add(worker.url);
      await wait(RETRY_DELAY_MS * (attempt + 1), undefined, { signal });
    }
  }
}

/** Le flux recomposé, ou le corps JSON d'une réponse d'un bloc. */
async function readCompletion(
  response: Response,
  onText?: (delta: string) => void,
): Promise<ChatCompletion> {
  if (onText) {
    return readChatStream(response, onText);
  }
  const body: unknown = await response.json();
  if (typeof body !== 'object' || body === null) {
    throw new ServiceUnavailableException('Coach : réponse illisible.');
  }
  return body;
}

/**
 * Statut refusé, réseau coupé, échéance dépassée, JSON illisible : 503, avec
 * les jetons déjà consommés. Le message ne sert qu'aux JOURNAUX (le filtre
 * masque tout 5xx) : notre propre texte (avec, pour un 429 ou un 5xx, la
 * raison du fournisseur, voir `refusalReason`), ou le NOM de l'erreur,
 * jamais son message, qui peut citer le corps de la réponse.
 */
function unavailable(error: unknown, usage: CoachTurnUsage, shown = false): never {
  // Un flux coupé ne dit pas ce qu'il a coûté (l'usage n'arrive qu'à la
  // fin) : du texte montré prouve des jetons consommés, le message n'est
  // donc PAS rendu (`refundIfUnavailable` ne rend qu'à zéro jeton).
  if (shown && usage.inputTokens === 0) {
    usage.inputTokens = 1;
  }
  const reason =
    error instanceof HttpException
      ? error.message
      : `Coach : fournisseur injoignable (${error instanceof Error ? error.name : 'inconnue'}).`;
  throw new CoachProviderUnavailableException(reason, usage);
}

/**
 * Le corps d'un refus (4xx) n'est jamais lu : il peut citer le message de la
 * personne. Celui d'un 429 ou d'un 5xx dit POURQUOI le fournisseur refuse
 * (débit, volume du mois, capacité saturée) : son seul champ `message`,
 * tronqué, part au journal, avec les en-têtes de limites. Ce sont eux qui
 * départagent : `x-ratelimit-limit-req-minute=0` dit que le modèle n'a AUCUNE
 * allocation dans l'offre (changer `COACH_MODEL`), une limite pleine dit
 * qu'il faut attendre.
 */
async function refusalReason(response: Response, retryable: boolean): Promise<string> {
  if (!retryable) {
    await response.body?.cancel();
    return '';
  }
  const body = (await response.json().catch(() => null)) as {
    message?: unknown;
    error?: { message?: unknown };
  } | null;
  const message = body?.message ?? body?.error?.message;
  const limits: string[] = [];
  response.headers.forEach((value, name) => {
    if (/ratelimit|retry-after/i.test(name)) {
      limits.push(`${name}=${value.slice(0, 40)}`);
    }
  });
  return (
    (typeof message === 'string' ? ` (${message.slice(0, 160)})` : '') +
    (limits.length > 0 ? ` [${limits.join(', ').slice(0, 300)}]` : '')
  );
}

/** Ce que le modèle relit de chaque appel, dans l'ordre de ses appels. */
function toolReply(call: CoachToolCall, results: CoachToolResult[]): string {
  if (call.name === PROPOSE_SESSION_TOOL) {
    // Accusé de réception, pour que le modèle puisse conclure son tour.
    return 'Proposition reçue.';
  }
  const result = results.find((candidate) => candidate.id === call.id);
  if (result === undefined) {
    return 'Erreur : outil sans résultat.';
  }
  return result.isError ? `Erreur : ${result.content}` : result.content;
}

/** Chaîne JSON (le cas général) ou objet (Ollama) ; illisible : `{}`. */
function parseArguments(raw: unknown): Record<string, unknown> {
  try {
    const value: unknown = typeof raw === 'string' ? JSON.parse(raw) : raw;
    return typeof value === 'object' && value !== null && !Array.isArray(value)
      ? (value as Record<string, unknown>)
      : {};
  } catch {
    // Les outils retombent sur leurs défauts ; le validateur rejette une
    // proposition vide.
    return {};
  }
}

/** Texte simple, ou morceaux d'un modèle qui raisonne : seul le texte final. */
function textOf(content: unknown): string {
  if (typeof content === 'string') {
    return content.trim();
  }
  if (!Array.isArray(content)) {
    return '';
  }
  return (content as unknown[])
    .filter(
      (part): part is { type: 'text'; text: string } =>
        typeof part === 'object' && part !== null && 'type' in part && part.type === 'text',
    )
    .map((part) => part.text)
    .join('')
    .trim();
}
