/**
 * Ce que le contexte du modèle peut encore contenir.
 *
 * Qwen3-4B tourne avec 8 192 jetons de contexte (`OLLAMA_CONTEXT_LENGTH`).
 * Mesuré le 2 octobre 2026 : une question de 7 059 jetons et un plafond de
 * 2 048 débordaient ; Ollama DÉCALE alors le contexte et continue — 915 s
 * pour une réponse, au lieu de deux minutes. Et un message plus long que le
 * contexte est refusé (400). Le client garde donc toujours la place de la
 * réponse : l'historique le plus ancien cède, puis chaque appel borne sa
 * sortie à ce qui reste.
 *
 * L'estimation part des caractères (mesuré sur Qwen3 : 3,6 caractères par
 * jeton pour les consignes, 3,3 pour les outils et le français, 2,6 pour le
 * JSON des lectures ; ≈ 4 jetons de gabarit par message), puis se recale sur
 * le compte EXACT que le moteur rend après chaque appel. La marge couvre
 * l'écart du JSON avant le premier recalage.
 */
const CHARS_PER_TOKEN = 3;
const MESSAGE_TOKENS = 5;
const MARGIN = 256;

type ChatMessage = Record<string, unknown>;

export class ContextBudget {
  private scale = 1;
  private readonly toolChars: number;

  constructor(
    private readonly size: number,
    tools: unknown[],
  ) {
    this.toolChars = JSON.stringify(tools).length;
  }

  /** Jetons de ces messages, outils compris, réglés sur le dernier compte exact. */
  tokens(messages: readonly ChatMessage[]): number {
    return Math.ceil(this.raw(messages) * this.scale);
  }

  /** Le compte exact du moteur pour ces messages (`usage.prompt_tokens`). */
  calibrate(messages: readonly ChatMessage[], promptTokens: number | undefined): void {
    if (promptTokens !== undefined && promptTokens > 0) {
      this.scale = promptTokens / this.raw(messages);
    }
  }

  /** Jetons qu'une réponse à ces messages peut encore produire. */
  room(messages: readonly ChatMessage[]): number {
    return this.size - MARGIN - this.tokens(messages);
  }

  /**
   * Retire de `messages`, en place, l'historique le plus ancien (`count`
   * messages à partir de `from`) tant que la réponse n'a pas `reserve`
   * jetons — les résultats d'outils s'accumulent d'un tour à l'autre, et
   * une séance proposée ne doit jamais être coupée en plein JSON. Rend le
   * nombre de messages retirés ; la dernière question reste.
   */
  trim(messages: ChatMessage[], from: number, count: number, reserve: number): number {
    let removed = 0;
    while (count - removed > 1 && this.room(messages) < reserve) {
      messages.splice(from, 1);
      removed += 1;
      while (count - removed > 1 && messages[from]?.role !== 'user') {
        messages.splice(from, 1);
        removed += 1;
      }
    }
    return removed;
  }

  private raw(messages: readonly ChatMessage[]): number {
    let chars = this.toolChars;
    for (const message of messages) {
      const content = message.content;
      chars += typeof content === 'string' ? content.length : JSON.stringify(content ?? '').length;
      if (message.tool_calls !== undefined) chars += JSON.stringify(message.tool_calls).length;
    }
    return chars / CHARS_PER_TOKEN + messages.length * MESSAGE_TOKENS;
  }
}
