import Anthropic from '@anthropic-ai/sdk';
import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { AppConfigService } from '../../../config/app-config.service';
import {
  type CoachModelPort,
  type CoachToolCall,
  type CoachTurnInput,
  type CoachTurnOutput,
} from '../domain/coach-model.port';
import { PROPOSE_SESSION_TOOL } from '../application/coach.tools';

/**
 * Seul fichier du dépôt qui connaisse le fournisseur.
 *
 * Le point de césure du cache est posé sur le **dernier bloc système** : tout
 * ce qui précède — définitions d'outils puis prompt — est stable et se relit
 * à un dixième du prix. Rien de volatile ne doit remonter dans ce préfixe.
 */
@Injectable()
export class AnthropicCoachClient implements CoachModelPort {
  /** Créé paresseusement : sans clé, le module reste chargeable. */
  private client: Anthropic | null = null;

  constructor(private readonly config: AppConfigService) {}

  /** Tours d'outils autorisés avant d'arrêter les frais. */
  private static readonly maxToolRounds = 6;
  private static readonly maxTokens = 2048;

  async reply(input: CoachTurnInput): Promise<CoachTurnOutput> {
    const client = this.ensureClient();

    const messages: Anthropic.MessageParam[] = input.history.map((turn) => ({
      role: turn.role,
      content: turn.content,
    }));

    let proposal: Record<string, unknown> | null = null;
    let inputTokens = 0;
    let outputTokens = 0;
    let cacheReadTokens = 0;

    for (let round = 0; round < AnthropicCoachClient.maxToolRounds; round++) {
      const response = await client.messages.create({
        model: this.config.coachModel,
        max_tokens: AnthropicCoachClient.maxTokens,
        system: [
          {
            type: 'text',
            text: input.system,
            // Césure : outils + prompt système sont relus depuis le cache.
            cache_control: { type: 'ephemeral' },
          },
        ],
        tools: input.tools.map((tool) => ({
          name: tool.name,
          description: tool.description,
          input_schema: tool.inputSchema as Anthropic.Tool.InputSchema,
        })),
        messages,
      });

      inputTokens += response.usage.input_tokens;
      outputTokens += response.usage.output_tokens;
      cacheReadTokens += response.usage.cache_read_input_tokens ?? 0;

      if (response.stop_reason === 'refusal') {
        // Un refus est un CONTENU, pas une panne : l'utilisateur doit le lire.
        return {
          text: 'Je ne peux pas répondre à cette demande.',
          proposal: null,
          usage: { inputTokens, outputTokens, cacheReadTokens },
          refused: true,
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
        return {
          text: textOf(response),
          proposal,
          usage: { inputTokens, outputTokens, cacheReadTokens },
          refused: false,
        };
      }

      const results = await input.runTools(
        calls.filter((call) => call.name !== PROPOSE_SESSION_TOOL),
      );

      const blocks: Anthropic.ToolResultBlockParam[] = results.map((result) => ({
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

    // Plafond de tours atteint : on rend ce qu'on a plutôt que de boucler.
    return {
      text: 'Je n’ai pas réussi à aboutir. Reformule ta demande ?',
      proposal,
      usage: { inputTokens, outputTokens, cacheReadTokens },
      refused: false,
    };
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

function textOf(response: Anthropic.Message): string {
  return response.content
    .filter((block): block is Anthropic.TextBlock => block.type === 'text')
    .map((block) => block.text)
    .join('\n')
    .trim();
}
