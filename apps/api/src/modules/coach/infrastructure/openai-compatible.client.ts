import { ServiceUnavailableException } from '@nestjs/common';
import { setTimeout as wait } from 'node:timers/promises';
import { type AppConfigService } from '../../../config/app-config.service';
import { PROPOSE_PROGRAM_TOOL, PROPOSE_SESSION_TOOL } from '../application/coach.tool-definitions';
import {
  COACH_GAVE_UP_TEXT,
  COACH_MAX_TOOL_ROUNDS,
  CoachProviderUnavailableException,
  type CoachModelPort,
  type CoachToolCall,
  type CoachTurnInput,
  type CoachTurnOutput,
  type CoachTurnUsage,
  turnSignal,
} from '../domain/coach-model.port';
import { type ChatCompletion } from './chat-completion-stream';
import { type CoachWorkerPool } from './coach-worker-pool';
import { probeFor, probeForAction, USER_DATA_TOOLS } from './announced-action';
import {
  addUsage,
  parseArguments,
  prefetchedMessages,
  readCompletion,
  refusalReason,
  textOf,
  toolReply,
  unavailable,
} from './openai-compatible.helpers';

/** Nouvelles tentatives (429, 5xx, worker injoignable), chacune sur un AUTRE worker s'il y en a. */
const RETRIES = 2;
const RETRY_DELAY_MS = 1000;

/**
 * Occasions d'agir par tour (announced-action.ts) : la seconde rattrape le
 * modèle qui, après avoir lu ce qu'il annonçait, promet encore la suite
 * (« Je te propose une séance d'ouverture… », constaté).
 */
const MAX_PROBES = 2;

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
      ...input.history.map((turn) => ({ role: turn.role, content: turn.content })),
      ...prefetchedMessages(input.prefetched ?? []),
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
    // La réponse écrite AVANT l'occasion d'agir, quand le modèle a agi :
    // elle reste en tête de la réplique archivée, déjà lue à l'écran.
    let before = '';
    let lastKept = '';
    // Une réponse écartée (données inventées) : elle ne revient qu'à défaut d'autre.
    let discarded = '';
    // Ce qui est déjà écrit, plus ce qui s'y ajoute depuis.
    const joined = () =>
      said !== '' && said !== lastKept
        ? [before, said].filter(Boolean).join('\n\n')
        : before || said;
    const reply = () => joined() || discarded;
    // Des données de la personne lues dans ce tour, avant lui ou par lui.
    let read = (input.prefetched ?? []).some(({ result }) => result.isError !== true);
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

    const maxTokens = input.maxOutputTokens ?? this.config.coachGateway.maxOutputTokens;
    // Une occasion d'agir au plus par tour (announced-action.ts).
    let probes = 0;
    // Une séance ou un programme proposé : la suite promise est là.
    let proposed = false;
    const request =
      [...input.history].reverse().find((turn) => turn.role === 'user')?.content ?? '';
    for (let round = 0; round < COACH_MAX_TOOL_ROUNDS; round++) {
      spoke = false;
      const served = await this.complete(
        { messages, tools },
        signal,
        onText,
        maxTokens,
        worker,
      ).catch((error: unknown) => {
        // Le modèle a agi après une réponse déjà affichée : une panne
        // ensuite (échéance, 5xx) rend cette réponse, plutôt que rien.
        if (before + discarded !== '' && input.signal?.aborted !== true) return null;
        return unavailable(error, usage, shown);
      });
      if (served === null) return this.output(reply(), proposal, usage, worker);
      const { completion } = served;
      worker = served.served;
      addUsage(usage, completion);

      let choice = completion.choices?.[0];
      if (choice?.finish_reason === 'error') {
        // Mistral : génération coupée chez lui, texte tronqué à ne pas archiver.
        throw new CoachProviderUnavailableException('Coach : génération interrompue.', usage);
      }
      said = textOf(choice?.message?.content) || said;
      // Sur la PRÉSENCE d'appels, jamais sur `finish_reason` : certains
      // fournisseurs rendent « stop » avec des appels d'outils.
      let toolCalls = choice?.message?.tool_calls ?? [];
      // L'occasion d'agir (announced-action.ts) : séance demandée ou promise
      // sans carte, fin qui parle d'une suite. Rien, une fois une séance ou
      // un programme proposé : « Voici la séance : » précède sa carte.
      const mayProbe =
        toolCalls.length === 0 &&
        probes < MAX_PROBES &&
        !proposed &&
        round < COACH_MAX_TOOL_ROUNDS - 1 &&
        input.tools.length > 0;
      const question = mayProbe ? probeFor(textOf(choice?.message?.content), request, read) : null;
      if (question !== null) {
        probes += 1;
        const answer = { role: 'assistant', content: choice?.message?.content ?? '' };
        const asked = { role: 'user', content: question.text };
        const acted = await probeForAction(this.complete.bind(this), [...messages, answer, asked], {
          tools,
          signal,
          cancelled: input.signal,
          maxTokens,
          worker,
          usage,
        }).catch((error: unknown) => unavailable(error, usage, shown));
        if (acted !== null) {
          messages.push(answer, asked);
          if (question.keep) {
            // Jamais la réponse écartée : elle ne revient qu'à défaut de tout.
            before = joined();
            lastKept = said;
          } else {
            discarded = said;
            said = '';
          }
          choice = acted.choices?.[0];
          toolCalls = choice?.message?.tool_calls ?? [];
        }
      }
      if (toolCalls.length === 0) {
        return this.output(reply(), proposal, usage, worker);
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
      proposed ||= calls.some(
        (c) => c.name === PROPOSE_SESSION_TOOL || c.name === PROPOSE_PROGRAM_TOOL,
      );
      const results = await input.runTools(calls.filter((c) => c.name !== PROPOSE_SESSION_TOOL));
      // Ses données lues pour de bon : une lecture réussie d'un outil qui les rend.
      read ||= results.some(
        (r) =>
          r.isError !== true && USER_DATA_TOOLS.has(calls.find((c) => c.id === r.id)?.name ?? ''),
      );

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

    // Trop de tours d'outils : la réponse écrite avant l'occasion d'agir,
    // s'il y en a une, vaut mieux qu'un abandon.
    return this.output(before, proposal, usage, worker);
  }

  /** La réplique du tour ; sans texte, l'abandon dit comme tel. */
  private output(
    text: string,
    proposal: Record<string, unknown> | null,
    usage: CoachTurnUsage,
    worker: string | undefined,
  ): CoachTurnOutput {
    return {
      text: text || COACH_GAVE_UP_TEXT,
      proposal,
      usage,
      refused: false,
      worker,
      model: this.config.coachProvider.model,
    };
  }

  /** Une requête au modèle, sur `prefer` s'il est sain ; `retries` nouvelles tentatives. */
  private async complete(
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
    const body = JSON.stringify({
      model,
      max_tokens: maxOutputTokens,
      ...payload,
      ...stream,
    });
    const tried = new Set<string>();
    for (let attempt = 0; ; attempt++) {
      const worker = this.pool.acquire(tried, prefer);
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
          if (signal.aborted || attempt === retries) throw error;
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
          if (!retryable || attempt === retries) {
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
