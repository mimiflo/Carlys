import { HttpException, ServiceUnavailableException } from '@nestjs/common';
import { setTimeout as wait } from 'node:timers/promises';
import { type AppConfigService } from '../../../config/app-config.service';
import { PROPOSE_SESSION_TOOL } from '../application/coach.tools';
import {
  COACH_GAVE_UP_TEXT,
  COACH_MAX_OUTPUT_TOKENS,
  COACH_MAX_TOOL_ROUNDS,
  COACH_TURN_DEADLINE_MS,
  CoachProviderUnavailableException,
  type CoachModelPort,
  type CoachToolCall,
  type CoachToolResult,
  type CoachTurnInput,
  type CoachTurnOutput,
  type CoachTurnUsage,
} from '../domain/coach-model.port';

/** Ce qu'on lit d'une réponse Chat Completions, rien de plus. */
interface ChatToolCall {
  id: string;
  function?: { name?: string; arguments?: unknown };
}
interface ChatChoice {
  finish_reason?: string;
  message?: { content?: unknown; tool_calls?: ChatToolCall[] | null };
}
interface ChatCompletion {
  choices?: ChatChoice[];
  usage?: {
    prompt_tokens?: number;
    completion_tokens?: number;
    prompt_tokens_details?: { cached_tokens?: number } | null;
  };
}

/** Nouvelles tentatives sur un 429 ou un 5xx, comme le SDK Anthropic. */
const RETRIES = 2;
const RETRY_DELAY_MS = 1000;

/**
 * Client d'une API **compatible OpenAI** (Chat Completions) : Mistral, mais
 * aussi Ollama (`…/v1`) ou Cloudflare, par simple réglage de
 * `COACH_API_BASE_URL` (voir coach.module.ts). `fetch` natif, sans SDK : un
 * seul `POST`, comme `subscriptions/infrastructure/stripe-form-request.ts`.
 *
 * Aucun cache explicite ici : `cacheReadTokens` vaut ce que le fournisseur
 * déclare (souvent 0), ce n'est pas un préfixe cassé.
 */
export class OpenAiCompatibleCoachClient implements CoachModelPort {
  constructor(private readonly config: AppConfigService) {}

  async reply(input: CoachTurnInput): Promise<CoachTurnOutput> {
    // UNE échéance pour tout le tour, tentatives et outils compris.
    const signal = AbortSignal.timeout(COACH_TURN_DEADLINE_MS);
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

    for (let round = 0; round < COACH_MAX_TOOL_ROUNDS; round++) {
      const completion = await this.complete({ messages, tools }, signal).catch((error: unknown) =>
        unavailable(error, usage),
      );
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
        return { text: said || COACH_GAVE_UP_TEXT, proposal, usage, refused: false };
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

    return { text: COACH_GAVE_UP_TEXT, proposal, usage, refused: false };
  }

  private async complete(
    payload: Record<string, unknown>,
    signal: AbortSignal,
  ): Promise<ChatCompletion> {
    const { baseUrl = '', apiKey, model } = this.config.coachProvider;
    for (let attempt = 0; ; attempt++) {
      const response = await fetch(`${baseUrl.replace(/\/+$/, '')}/chat/completions`, {
        method: 'POST',
        signal,
        headers: {
          'Content-Type': 'application/json',
          ...(apiKey === undefined ? {} : { Authorization: `Bearer ${apiKey}` }),
        },
        body: JSON.stringify({ model, max_tokens: COACH_MAX_OUTPUT_TOKENS, ...payload }),
      });
      if (response.ok) {
        const body: unknown = await response.json();
        if (typeof body !== 'object' || body === null) {
          throw new ServiceUnavailableException('Coach : réponse illisible.');
        }
        return body;
      }
      const retryable = response.status === 429 || response.status >= 500;
      if (!retryable || attempt === RETRIES) {
        // Jamais relayé tel quel : un 429 du fournisseur (quota GLOBAL)
        // s'afficherait « limite du jour » sur le téléphone.
        throw new ServiceUnavailableException(
          `Coach : le fournisseur a répondu ${response.status}${await refusalReason(response, retryable)}.`,
        );
      }
      await response.body?.cancel();
      await wait(RETRY_DELAY_MS * (attempt + 1), undefined, { signal });
    }
  }
}

/**
 * Statut refusé, réseau coupé, échéance dépassée, JSON illisible : 503, avec
 * les jetons déjà consommés. Le message ne sert qu'aux JOURNAUX (le filtre
 * masque tout 5xx) : notre propre texte (avec, pour un 429 ou un 5xx, la
 * raison du fournisseur, voir `refusalReason`), ou le NOM de l'erreur,
 * jamais son message, qui peut citer le corps de la réponse.
 */
function unavailable(error: unknown, usage: CoachTurnUsage): never {
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
 * tronqué, part au journal.
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
  return typeof message === 'string' ? ` (${message.slice(0, 160)})` : '';
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
