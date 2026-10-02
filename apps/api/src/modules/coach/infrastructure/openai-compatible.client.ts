import { type AppConfigService } from '../../../config/app-config.service';
import { PROPOSE_PROGRAM_TOOL, PROPOSE_SESSION_TOOL } from '../application/coach.tool-definitions';
import {
  COACH_GAVE_UP_TEXT,
  COACH_MAX_TOOL_ROUNDS,
  CoachProviderUnavailableException,
  type CoachGeneration,
  type CoachModelPort,
  type CoachToolCall,
  type CoachTurnInput,
  type CoachTurnOutput,
  type CoachTurnUsage,
  turnSignal,
} from '../domain/coach-model.port';
import { completeAnswer } from './answer-continuation';
import { type CoachWorkerPool } from './coach-worker-pool';
import { CoachWorkerRequests } from './coach-worker-requests';
import { probeFor, probeForAction } from './announced-action';
import { ContextBudget } from './context-budget';
import { endOfError } from './generation-end';
import { runToolRound, WRAP_UP_ROUNDS } from './tool-round';
import {
  parseArguments,
  prefetchedMessages,
  textOf,
  unavailable,
} from './openai-compatible.helpers';

/**
 * Occasions d'agir par tour (announced-action.ts) : la seconde rattrape le
 * modèle qui, après avoir lu ce qu'il annonçait, promet encore la suite
 * (« Je te propose une séance d'ouverture… », constaté).
 */
const MAX_PROBES = 2;

/**
 * Jetons gardés, en plus du plafond d'un appel, pour finir une réponse
 * coupée : la reprise relit la réponse partielle, puis écrit sa fin.
 */
const CONTINUATION_ROOM = 512;

/** En deçà, l'occasion d'agir ne pourrait pas même écrire une proposition. */
const MIN_PROBE_ROOM = 256;

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
  private readonly requests: CoachWorkerRequests;

  constructor(
    private readonly config: AppConfigService,
    pool: CoachWorkerPool,
  ) {
    this.requests = new CoachWorkerRequests(config, pool);
  }

  async reply(input: CoachTurnInput): Promise<CoachTurnOutput> {
    // UNE échéance pour tout le tour, tentatives et outils compris.
    const signal = turnSignal(input, this.config.coachGateway.requestTimeoutMs);
    const tools = input.tools.map((tool) => ({
      type: 'function',
      function: { name: tool.name, description: tool.description, parameters: tool.inputSchema },
    }));
    const { maxOutputTokens, maxContinuations, contextTokens } = this.config.coachGateway;
    const maxTokens = input.maxOutputTokens ?? maxOutputTokens;
    // La place de la réponse, et d'une reprise, toujours gardée : l'historique
    // le plus ancien cède (context-budget.ts).
    const budget = new ContextBudget(contextTokens, tools);
    const system = [
      { role: 'system', content: input.system },
      ...(input.systemPerUser ? [{ role: 'system', content: input.systemPerUser }] : []),
    ];
    const prefetched = prefetchedMessages(input.prefetched ?? []);
    const history = input.history.map((turn) => ({ role: turn.role, content: turn.content }));
    const messages: Record<string, unknown>[] = [...system, ...history, ...prefetched];
    let historyCount =
      history.length -
      budget.trim(messages, system.length, history.length, maxTokens + CONTINUATION_ROOM);
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

    const complete = this.requests.complete.bind(this.requests);
    const generation: CoachGeneration = {
      finishReason: 'UNKNOWN',
      ends: [],
      continuations: 0,
      recovered: 0,
      unneeded: 0,
      truncated: false,
    };
    // Une occasion d'agir au plus par tour (announced-action.ts).
    let probes = 0;
    // Une séance ou un programme proposé : la suite promise est là.
    let proposed = false;
    const request =
      [...input.history].reverse().find((turn) => turn.role === 'user')?.content ?? '';
    for (let round = 0; round < COACH_MAX_TOOL_ROUNDS; round++) {
      spoke = false;
      // Les résultats d'outils s'accumulent : l'historique cède encore, pas
      // la place de la réponse (une proposition coupée en plein JSON).
      historyCount -= budget.trim(messages, system.length, historyCount, maxTokens);
      // Un appel, et ses reprises si la réponse s'arrête avant sa fin.
      const served = await completeAnswer(complete, {
        messages,
        tools,
        signal,
        cancelled: input.signal,
        onText,
        maxTokens,
        worker,
        maxContinuations,
        budget,
        trustStop: proposed,
        usage,
      }).catch((error: unknown) => {
        const end = endOfError(error, signal, input.signal);
        generation.ends.push(end);
        generation.finishReason = end;
        // Le modèle a agi après une réponse déjà affichée : une panne
        // ensuite (échéance, 5xx) rend cette réponse, plutôt que rien.
        if (before + discarded !== '' && input.signal?.aborted !== true) return null;
        return unavailable(error, usage, shown, end);
      });
      if (served === null) return this.output(reply(), proposal, usage, worker, generation);
      const { completion, report } = served;
      worker = served.served;
      Object.assign(generation, {
        finishReason: report.ends.at(-1) ?? 'UNKNOWN',
        ends: [...generation.ends, ...report.ends],
        continuations: generation.continuations + report.continuations,
        recovered: generation.recovered + report.recovered,
        unneeded: generation.unneeded + report.unneeded,
        truncated: generation.truncated || report.truncated,
      });

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
        // Au dernier tour aussi : la séance que l'occasion d'agir fait
        // proposer s'ajoute à la réponse déjà écrite, rendue à la fin des tours.
        input.tools.length > 0;
      const wrapUp = round >= COACH_MAX_TOOL_ROUNDS - WRAP_UP_ROUNDS;
      const probe = mayProbe ? probeFor(textOf(choice?.message?.content), request, read) : null;
      // Plus de lecture possible : une vérification des données (`keep:
      // false`) écarterait la réponse sans pouvoir en écrire une autre.
      const question = probe !== null && (probe.keep || !wrapUp) ? probe : null;
      const answer = { role: 'assistant', content: choice?.message?.content ?? '' };
      const asked = { role: 'user', content: question?.text ?? '' };
      // L'occasion d'agir, elle aussi, dans le contexte qui reste.
      const probeRoom = Math.min(maxTokens, budget.room([...messages, answer, asked]));
      if (question !== null && probeRoom > MIN_PROBE_ROOM) {
        probes += 1;
        const acted = await probeForAction(complete, [...messages, answer, asked], {
          tools,
          signal,
          cancelled: input.signal,
          maxTokens: probeRoom,
          worker,
          usage,
        }).catch((error: unknown) =>
          unavailable(error, usage, shown, endOfError(error, signal, input.signal)),
        );
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
        return this.output(reply(), proposal, usage, worker, generation);
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
      // Les derniers tours : plus de lecture, la proposition et la réponse (tool-round.ts).
      // Jamais `read ||= await …` : lu une fois, les tours suivants ne
      // s'exécuteraient plus.
      const readNow = await runToolRound(
        input,
        calls,
        { content: choice?.message?.content, tool_calls: toolCalls },
        messages,
        wrapUp,
      );
      read ||= readNow;
    }

    // Trop de tours d'outils : ce qui est déjà écrit vaut mieux qu'un abandon.
    return this.output(reply(), proposal, usage, worker, generation);
  }

  /** La réplique du tour ; sans texte, l'abandon dit comme tel. */
  private output(
    text: string,
    proposal: Record<string, unknown> | null,
    usage: CoachTurnUsage,
    worker: string | undefined,
    generation: CoachGeneration,
  ): CoachTurnOutput {
    return {
      text: text || COACH_GAVE_UP_TEXT,
      proposal,
      usage,
      refused: false,
      worker,
      model: this.config.coachProvider.model,
      generation,
    };
  }
}
