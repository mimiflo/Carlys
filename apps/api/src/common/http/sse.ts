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
  return (event, data) => {
    if (response.writableEnded || response.destroyed) {
      // La personne est partie : le tour continue et s'archive quand même.
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
    response.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
  };
}
