import { type Response } from 'express';

/**
 * Émetteur Server-Sent Events sur une réponse Express.
 *
 * Les en-têtes ne partent qu'au PREMIER évènement : tout refus survenu avant
 * (quota, droit, fil inconnu) garde son vrai statut HTTP et son enveloppe
 * d'erreur ordinaire. Après, une erreur devient l'évènement `error` (voir
 * `AllExceptionsFilter`). `X-Accel-Buffering: no` demande à Nginx de relayer
 * chaque évènement sans l'accumuler.
 */
export function sseEmitter(response: Response): (event: string, data: unknown) => void {
  return (event, data) => write(response, `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
}

/**
 * Battement d'un flux qui se tait longtemps — le coach sur processeur relit
 * des séances une minute durant avant son premier mot. Un commentaire SSE
 * (`: ping`), que tout client ignore, part toutes les [everyMs] : nginx ne
 * coupe qu'après 60 s SANS octet, et le mobile n'attend ses en-têtes que 65 s.
 *
 * Le premier battement ne part qu'après [everyMs] : les refus, rendus en
 * quelques millisecondes, gardent leur statut HTTP. Rend de quoi l'arrêter.
 */
export function sseKeepAlive(response: Response, everyMs: number): () => void {
  const timer = setInterval(() => write(response, ': ping\n\n'), everyMs);
  return () => clearInterval(timer);
}

function write(response: Response, chunk: string): void {
  if (response.writableEnded || response.destroyed) {
    // La personne est partie : plus rien à écrire. La génération, elle,
    // continue et s'archive (ADR 0013, mise à jour du 3 octobre 2026).
    return;
  }
  if (!response.headersSent) {
    response.status(200).set({
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-cache, no-transform',
      'X-Accel-Buffering': 'no',
    });
    response.flushHeaders();
  }
  response.write(chunk);
}
