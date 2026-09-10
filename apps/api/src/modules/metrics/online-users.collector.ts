import { Injectable } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { Gauge } from 'prom-client';
import { PresenceService } from '../../infrastructure/presence/presence.service';
import { MetricsService } from './metrics.service';

/**
 * Publie « utilisateurs en ligne » dans /metrics.
 *
 * C'est LA mesure qui pilote la mise à l'échelle : l'orchestrateur la lit
 * avant d'ajouter ou de retirer un réplica. Elle est donc calculée à la
 * demande, au moment de la collecte, et jamais mise en cache — un chiffre de
 * cinq minutes d'âge ferait grandir la pile après la vague, et la ferait
 * fondre pendant.
 *
 * TROIS SÉRIES, PAS UNE. Une jauge seule ne sait pas dire « je ne sais pas » :
 * Redis injoignable, elle rendrait 0, l'orchestrateur lirait « personne » et
 * réduirait la pile au pire moment. `carlys_api_presence_up` sépare donc la
 * valeur de sa validité, et `..._window_seconds` dit sur quelle durée elle est
 * comptée — sans quoi le chiffre n'est pas interprétable.
 */
@Injectable()
export class OnlineUsersCollector {
  constructor(
    metrics: MetricsService,
    presence: PresenceService,
    @InjectPinoLogger(OnlineUsersCollector.name)
    logger: PinoLogger,
  ) {
    const registers = [metrics.registry];
    const up = new Gauge({
      name: 'carlys_api_presence_up',
      help: 'Le dernier calcul de présence a abouti (1) ou a échoué (0).',
      registers,
    });

    new Gauge({
      name: 'carlys_api_online_users',
      help: 'Utilisateurs distincts actifs sur la fenêtre de présence.',
      registers,
      // `function` et non une lambda : prom-client appelle `collect` avec
      // `this` lié à la jauge.
      async collect(): Promise<void> {
        try {
          this.set(await presence.onlineUsers());
          up.set(1);
        } catch (error) {
          // La valeur précédente est laissée telle quelle, et `presence_up`
          // passe à 0 : mieux vaut une mesure datée et signalée comme telle
          // qu'un zéro qui ferait décider de travers.
          up.set(0);
          logger.warn({ err: error }, 'Présence illisible — la jauge garde sa valeur précédente');
        }
      },
    });

    new Gauge({
      name: 'carlys_api_online_users_window_seconds',
      help: 'Largeur de la fenêtre sur laquelle les utilisateurs en ligne sont comptés.',
      registers,
    }).set(presence.windowSeconds);
  }
}
