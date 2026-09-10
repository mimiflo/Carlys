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
 *
 * ── POURQUOI LES DEUX JAUGES PARTAGENT UN SEUL RAFRAÎCHISSEMENT ─────────────
 *
 * La première rédaction posait la collecte sur `online_users` seul, et lui
 * faisait écrire `presence_up` au passage. Ça paraît économe. C'est faux, et
 * le défaut est SILENCIEUX : prom-client rend chaque métrique dès que SA
 * PROPRE collecte a fini — `getMetricsAsString` fait `await metric.get()` puis
 * rend, et toutes les métriques partent en parallèle. `presence_up`, qui
 * n'avait pas de collecte, était donc rendu AVANT que celle d'`online_users`
 * n'ait joint Redis. Il publiait le verdict du tour PRÉCÉDENT, et 0 au tout
 * premier — ce que l'orchestrateur lit « je ne sais pas » alors que Redis
 * répondait parfaitement.
 *
 * D'où ce rafraîchissement unique, appelé par les DEUX collectes et
 * déduplique : la première qui passe lance la lecture, la seconde attend la
 * même promesse. L'ordre de rendu n'a plus d'importance, ce qui est la seule
 * propriété qui tienne — il ne dépend ni de l'ordre d'enregistrement, ni de la
 * version de prom-client.
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
      collect: rafraichir,
    });

    const enLigne = new Gauge({
      name: 'carlys_api_online_users',
      help: 'Utilisateurs distincts actifs sur la fenêtre de présence.',
      registers,
      collect: rafraichir,
    });

    new Gauge({
      name: 'carlys_api_online_users_window_seconds',
      help: 'Largeur de la fenêtre sur laquelle les utilisateurs en ligne sont comptés.',
      registers,
    }).set(presence.windowSeconds);

    /** La lecture en cours, s'il y en a une. Déclarée après les jauges, mais
     * lue seulement à la collecte — donc après la construction. */
    let enCours: Promise<void> | null = null;

    /**
     * Déclaration de fonction et non `const` : elle est nommée dans les deux
     * `collect` ci-dessus, donc avant sa position dans le fichier. Le hissage
     * rend l'ordre de lecture libre — on peut décrire les métriques d'abord et
     * la mécanique ensuite.
     */
    function rafraichir(): Promise<void> {
      if (enCours !== null) {
        return enCours;
      }
      enCours = (async (): Promise<void> => {
        try {
          enLigne.set(await presence.onlineUsers());
          up.set(1);
        } catch (error) {
          // La valeur précédente d'`enLigne` est laissée telle quelle, et
          // `up` passe à 0 : mieux vaut une mesure datée et signalée comme
          // telle qu'un zéro qui ferait décider de travers.
          up.set(0);
          logger.warn({ err: error }, 'Présence illisible — la jauge garde sa valeur précédente');
        } finally {
          enCours = null;
        }
      })();
      return enCours;
    }
  }
}
