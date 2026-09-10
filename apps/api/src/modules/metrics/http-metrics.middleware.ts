import { Injectable, type NestMiddleware } from '@nestjs/common';
import { type NextFunction, type Request, type Response } from 'express';
import { type AuthenticatedRequest } from '../../common/types/authenticated-request';
import { PresenceService } from '../../infrastructure/presence/presence.service';
import { HttpMetricsCollectors } from './http-metrics.collectors';
import { routeLabel } from './route-label';

const NS_PER_SECOND = 1e9;

/**
 * Mesure chaque requête HTTP, et note au passage que son utilisateur est en
 * ligne.
 *
 * POURQUOI UN INTERGICIEL, ET PAS UN INTERCEPTEUR NEST. Un intercepteur
 * n'entoure que le HANDLER : quand un guard refuse la requête — 401 sans
 * jeton, 403 sans permission, 429 sur limitation de débit — l'intercepteur
 * n'est jamais appelé. Ces trois codes sont exactement ceux qu'on veut voir
 * quand quelque chose ne va pas. Un intergiciel Express entoure toute la
 * chaîne, y compris les 404 qui n'atteignent aucun contrôleur.
 *
 * POURQUOI LA PRÉSENCE ICI AUSSI. Le principal est posé sur la requête par le
 * guard d'authentification, donc APRÈS le passage de l'intergiciel à l'aller —
 * mais il est bien là au moment où la réponse se termine. Le même point
 * d'observation sert donc les deux mesures, et l'API n'a qu'un seul crochet
 * sur son chemin chaud au lieu de deux.
 */
@Injectable()
export class HttpMetricsMiddleware implements NestMiddleware {
  constructor(
    private readonly collectors: HttpMetricsCollectors,
    private readonly presence: PresenceService,
  ) {}

  use(request: Request, response: Response, next: NextFunction): void {
    const startedAt = process.hrtime.bigint();
    this.collectors.started();

    // `finish` (réponse envoyée) et `close` (client parti avant la fin)
    // peuvent survenir tous les deux ; sans ce drapeau, la requête serait
    // comptée deux fois et la jauge « en vol » deviendrait négative.
    let recorded = false;
    const record = (): void => {
      if (recorded) {
        return;
      }
      recorded = true;
      const seconds = Number(process.hrtime.bigint() - startedAt) / NS_PER_SECOND;
      this.collectors.finished(request.method, routeLabel(request), response.statusCode, seconds);
      this.recordPresence(request);
    };

    response.on('finish', record);
    response.on('close', record);
    next();
  }

  /**
   * Volontairement non attendue : la réponse est déjà partie, et faire
   * traîner le traitement d'une requête terminée pour un compteur serait
   * payer la mesure au prix de la latence. Les erreurs sont absorbées par le
   * service de présence, qui les journalise.
   */
  private recordPresence(request: Request): void {
    const userId = (request as AuthenticatedRequest).authUser?.userId;
    if (userId === undefined) {
      return;
    }
    void this.presence.touch(userId);
  }
}
