import { ServiceUnavailableException } from '@nestjs/common';

/** Un appel d'outil tel que Chat Completions le rend, flux ou pas. */
interface ChatToolCall {
  id: string;
  function?: { name?: string; arguments?: unknown };
}
interface ChatChoice {
  finish_reason?: string | null;
  message?: { content?: unknown; tool_calls?: ChatToolCall[] | null };
}
export interface ChatCompletion {
  choices?: ChatChoice[];
  usage?: {
    prompt_tokens?: number;
    completion_tokens?: number;
    prompt_tokens_details?: { cached_tokens?: number } | null;
  } | null;
}

/** Un morceau du flux : `delta` au lieu de `message`, outils par `index`. */
interface ChatChunk {
  choices?: {
    finish_reason?: string | null;
    delta?: {
      content?: unknown;
      tool_calls?: {
        index?: number;
        id?: string;
        function?: { name?: string; arguments?: string };
      }[];
    };
  }[];
  usage?: ChatCompletion['usage'];
}

/**
 * Lit une réponse `stream: true` (SSE, `data: <json>` puis `data: [DONE]`) et
 * la recompose en une réponse ordinaire : le client garde UNE seule boucle
 * d'outils, flux ou pas. Chaque morceau de texte part à `onText` dès qu'il
 * arrive.
 *
 * Les appels d'outils s'assemblent par `index` : Ollama les envoie entiers,
 * d'autres fournisseurs découpent les arguments en fragments.
 *
 * Un flux qui se ferme SANS `[DONE]` ni `finish_reason` est une panne : c'est
 * le seul signe qu'Ollama donne d'une erreur en cours de génération (statut
 * déjà parti en 200, message perdu). Le texte déjà montré n'est pas archivé.
 */
export async function readChatStream(
  response: Response,
  onText: (delta: string) => void,
): Promise<ChatCompletion> {
  if (response.body === null) {
    throw new ServiceUnavailableException('Coach : flux vide.');
  }
  let content = '';
  let finish: string | null = null;
  let usage: ChatCompletion['usage'] = null;
  let done = false;
  const calls: { id: string; name: string; arguments: string }[] = [];

  const onData = (data: string): void => {
    if (data === '[DONE]') {
      done = true;
      return;
    }
    const chunk = JSON.parse(data) as ChatChunk;
    usage = chunk.usage ?? usage;
    const choice = chunk.choices?.[0];
    finish = choice?.finish_reason ?? finish;
    const text = choice?.delta?.content;
    if (typeof text === 'string' && text !== '') {
      content += text;
      onText(text);
    }
    for (const part of choice?.delta?.tool_calls ?? []) {
      const call = (calls[part.index ?? calls.length] ??= { id: '', name: '', arguments: '' });
      call.id ||= part.id ?? '';
      call.name ||= part.function?.name ?? '';
      call.arguments += part.function?.arguments ?? '';
    }
  };

  const decoder = new TextDecoder();
  let buffer = '';
  try {
    for await (const bytes of response.body) {
      buffer += decoder.decode(bytes, { stream: true });
      let end: number;
      while ((end = buffer.indexOf('\n')) >= 0) {
        const line = buffer.slice(0, end).replace(/\r$/, '');
        buffer = buffer.slice(end + 1);
        if (line.startsWith('data:')) {
          onData(line.slice(5).trim());
        }
      }
    }
  } catch (error) {
    if (error instanceof SyntaxError) {
      throw new ServiceUnavailableException('Coach : flux illisible.');
    }
    throw error;
  }
  if (!done && finish === null) {
    throw new ServiceUnavailableException('Coach : flux interrompu.');
  }

  return {
    choices: [
      {
        finish_reason: finish,
        message: {
          content,
          tool_calls: calls
            .filter((call) => call !== undefined)
            .map((call) => ({
              id: call.id,
              type: 'function',
              function: { name: call.name, arguments: call.arguments },
            })),
        },
      },
    ],
    usage,
  };
}
