import Anthropic from '@anthropic-ai/sdk';
import { ServiceUnavailableException } from '@nestjs/common';
import { type AppConfigService } from '../../../config/app-config.service';
import {
  COACH_GAVE_UP_TEXT,
  COACH_MAX_TOOL_ROUNDS,
  COACH_REFUSAL_TEXT,
  CoachProviderUnavailableException,
  type CoachModelPort,
  type CoachToolCall,
  type CoachTurnInput,
  type CoachTurnOutput,
  type CoachTurnUsage,
  turnSignal,
} from '../domain/coach-model.port';
import { PROPOSE_SESSION_TOOL } from '../application/coach.tool-definitions';

/**
 * Client Anthropic : choisi quand `COACH_API_BASE_URL` est absente (voir
 * coach.module.ts). Seul fichier du dépôt qui importe le SDK Anthropic.
 *
 * Le point de césure du cache est posé sur le **dernier bloc système** : tout
 * ce qui précède — définitions d'outils puis prompt — est stable et se relit
 * à un dixième du prix. Rien de volatile ne doit remonter dans ce préfixe.
 */
/** Le modèle sans `COACH_MODEL` : le défaut vit ici, pas dans le schéma. */
export const ANTHROPIC_DEFAULT_MODEL = 'claude-opus-5-5';
const DEFAULT_MODEL = ANTHROPIC_DEFAULT_MODEL;

export class AnthropicCoachClient implements CoachModelPort {
  /** Créé paresseusement : sans clé, le module reste chargeable. */
  private client: Anthropic | null = null;

  /**
   * `model` : imposé quand ce client sert de REPLI — `COACH_MODEL` nomme
   * alors le modèle de nos workers, qu'Anthropic ne connaît pas.
   */
  constructor(
    private readonly config: AppConfigService,
    private readonly model?: string,
  ) {}

  private get modelName(): string {
    return this.model ?? this.config.coachProvider.model ?? DEFAULT_MODEL;
  }

  async reply(input: CoachTurnInput): Promise<CoachTurnOutput> {
    const client = this.ensureClient();
    // Une seule échéance pour tout le tour : le SDK, seul, attendrait 10 min.
    const signal = turnSignal(input, this.config.coachGateway.requestTimeoutMs);

    const messages: Anthropic.Beta.BetaMessageParam[] = input.history.map((turn) => ({
      role: turn.role,
      content: turn.content,
    }));
    // Les lectures faites avant lui, comme s'il les avait demandées.
    const prefetched = input.prefetched ?? [];
    if (prefetched.length > 0) {
      messages.push(
        {
          role: 'assistant',
          content: prefetched.map(({ call }) => ({
            type: 'tool_use' as const,
            id: call.id,
            name: call.name,
            input: call.input,
          })),
        },
        {
          role: 'user',
          content: prefetched.map(({ result }) => ({
            type: 'tool_result' as const,
            tool_use_id: result.id,
            content: result.content,
            is_error: result.isError ?? false,
          })),
        },
      );
    }

    // Le préfixe partagé porte la césure de cache ; le bloc par utilisateur
    // (profil Carlys) vient APRÈS, sans cache_control — sinon le préfixe se
    // fragmenterait en une variante par profil.
    const system: Anthropic.Beta.BetaTextBlockParam[] = [
      {
        type: 'text',
        text: input.system,
        // Césure : outils + prompt système sont relus depuis le cache.
        cache_control: { type: 'ephemeral' },
      },
    ];
    if (input.systemPerUser !== undefined && input.systemPerUser !== '') {
      system.push({ type: 'text', text: input.systemPerUser });
    }

    let proposal: Record<string, unknown> | null = null;
    const usage = { inputTokens: 0, outputTokens: 0, cacheReadTokens: 0 };

    for (let round = 0; round < COACH_MAX_TOOL_ROUNDS; round++) {
      const response = await client.beta.messages
        .create(
          {
            model: this.modelName,
            max_tokens: input.maxOutputTokens ?? this.config.coachGateway.maxOutputTokens,
            // Un refus d'un classifieur de sécurité — un faux positif sur des
            // compléments ou une blessure — est repris par un autre modèle
            // dans le même appel, choisi par l'API selon la catégorie.
            betas: ['server-side-fallback-2026-07-01'],
            fallbacks: 'default',
            // Le défaut de Claude Opus 5.5 ; posé pour qu'un changement de
            // modèle ne change pas la profondeur de réflexion en silence.
            output_config: { effort: 'medium' },
            system,
            tools: input.tools.map((tool) => ({
              name: tool.name,
              description: tool.description,
              input_schema: tool.inputSchema as Anthropic.Beta.BetaTool.InputSchema,
            })),
            messages,
          },
          { signal },
        )
        .catch((error: unknown) => unavailable(error, usage));

      usage.inputTokens += response.usage.input_tokens;
      usage.outputTokens += response.usage.output_tokens;
      usage.cacheReadTokens += response.usage.cache_read_input_tokens ?? 0;

      if (response.stop_reason === 'refusal') {
        return {
          text: COACH_REFUSAL_TEXT,
          proposal: null,
          usage,
          refused: true,
          model: this.modelName,
        };
      }

      const calls: CoachToolCall[] = [];
      for (const block of response.content) {
        if (block.type !== 'tool_use') {
          continue;
        }
        if (block.name === PROPOSE_SESSION_TOOL) {
          // La proposition n'est pas exécutée : elle est RETENUE, puis validée
          // par le serveur avant d'exister.
          proposal = block.input as Record<string, unknown>;
        }
        calls.push({
          id: block.id,
          name: block.name,
          input: (block.input ?? {}) as Record<string, unknown>,
        });
      }

      if (calls.length === 0 || response.stop_reason !== 'tool_use') {
        return { text: textOf(response), proposal, usage, refused: false, model: this.modelName };
      }

      input.onToolCalls?.(calls);
      const results = await input.runTools(
        calls.filter((call) => call.name !== PROPOSE_SESSION_TOOL),
      );

      const blocks: Anthropic.Beta.BetaToolResultBlockParam[] = results.map((result) => ({
        type: 'tool_result',
        tool_use_id: result.id,
        content: result.content,
        is_error: result.isError ?? false,
      }));
      // `propose_session` n'est pas exécuté : on accuse réception pour que le
      // modèle puisse conclure son tour.
      for (const call of calls) {
        if (call.name === PROPOSE_SESSION_TOOL) {
          blocks.push({
            type: 'tool_result',
            tool_use_id: call.id,
            content: 'Proposition reçue.',
          });
        }
      }

      messages.push({ role: 'assistant', content: response.content });
      messages.push({ role: 'user', content: blocks });
    }

    return { text: COACH_GAVE_UP_TEXT, proposal, usage, refused: false, model: this.modelName };
  }

  private ensureClient(): Anthropic {
    const apiKey = this.config.anthropicApiKey;
    if (apiKey === undefined) {
      throw new ServiceUnavailableException('Le coach n’est pas configuré.');
    }
    this.client ??= new Anthropic({ apiKey });
    return this.client;
  }
}

/**
 * Erreur du SDK (réseau, échéance, statut du fournisseur) : 503, que le
 * mobile sait afficher, au lieu du 500 d'une exception inconnue, avec les
 * jetons déjà consommés. Le message ne sert qu'aux JOURNAUX (le filtre masque
 * tout 5xx) : il porte le statut, jamais le corps de la réponse ni la clé.
 * Toute autre erreur est un bogue et repart telle quelle.
 */
function unavailable(error: unknown, usage: CoachTurnUsage): never {
  if (error instanceof Anthropic.APIError) {
    throw new CoachProviderUnavailableException(
      `Coach : Anthropic en échec (${error.status ?? error.name}).`,
      usage,
    );
  }
  throw error;
}

function textOf(response: Anthropic.Beta.BetaMessage): string {
  return response.content
    .filter((block): block is Anthropic.Beta.BetaTextBlock => block.type === 'text')
    .map((block) => block.text)
    .join('\n')
    .trim();
}
