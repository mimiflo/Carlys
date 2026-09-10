import { Injectable } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { AppConfigService } from '../../config/app-config.service';
import { RedisService } from '../cache/redis.service';

/** Préfixe des compteurs de présence — une clé par minute d'horloge. */
const KEY_PREFIX = 'carlys:presence:m:';
const MINUTE_MS = 60_000;

/**
 * Compte les utilisateurs actifs sur une fenêtre glissante, DANS Redis.
 *
 * POURQUOI DANS REDIS, ET PAS EN MÉMOIRE. C'est cette valeur qui pilote la
 * mise à l'échelle : l'orchestrateur y lit la charge réelle avant d'ajouter ou
 * de retirer un réplica d'API. Comptée en mémoire, chaque réplica ne verrait
 * que SA part du trafic et la somme dépendrait du nombre de réplicas — la
 * mesure qui décide de la taille de la pile varierait avec la taille de la
 * pile. Dans Redis, les réplicas écrivent dans les mêmes compteurs : la
 * valeur est la même quel que soit celui qu'on interroge.
 *
 * POURQUOI UN HYPERLOGLOG, ET PAS UN SET. Il faut un compte de personnes
 * DISTINCTES : un utilisateur qui envoie cent requêtes reste un utilisateur.
 * Un `SET` le ferait, au prix d'un identifiant de 36 octets stocké par
 * personne et par minute. Un HyperLogLog répond à la même question dans
 * 12 Kio par clé, quel que soit le nombre d'utilisateurs, et `PFCOUNT`
 * fusionne plusieurs clés pour donner l'union sans rien matérialiser. Le prix
 * est une erreur d'environ 0,8 % — sans importance pour un signal qui décide
 * d'ajouter un réplica à partir de plusieurs centaines d'utilisateurs.
 *
 * FENÊTRE PAR SEAUX D'UNE MINUTE. Une clé par minute d'horloge, expirée peu
 * après la fenêtre : lire la présence revient à un `PFCOUNT` sur les clés des
 * dernières minutes. Aucun nettoyage à programmer, aucune clé qui traîne.
 */
@Injectable()
export class PresenceService {
  constructor(
    private readonly redis: RedisService,
    private readonly config: AppConfigService,
    @InjectPinoLogger(PresenceService.name)
    private readonly logger: PinoLogger,
  ) {}

  /**
   * Enregistre une activité. Appelée une fois par requête authentifiée, donc
   * sur le chemin chaud : deux commandes envoyées en un seul aller-retour, et
   * jamais d'attente qui retarderait la réponse (l'appelant ne l'attend pas).
   */
  async touch(userId: string): Promise<void> {
    const key = this.bucketKey(Date.now());
    try {
      await this.redis
        .getClient()
        .pipeline()
        .pfadd(key, userId)
        // La clé doit survivre à toute la fenêtre qui la relira, plus une
        // minute de marge : la relire expirée ferait chuter le compte d'un
        // cran à chaque tour d'horloge.
        .expire(key, this.config.presenceWindowSeconds + 60)
        .exec();
    } catch (error) {
      this.logger.warn({ err: error, userId }, 'Présence non enregistrée (Redis indisponible)');
    }
  }

  /**
   * Nombre d'utilisateurs distincts vus pendant la fenêtre.
   *
   * Lève si Redis est indisponible : l'appelant doit distinguer « personne en
   * ligne » de « je ne sais pas ». Rendre 0 dans les deux cas ferait réduire
   * la pile au moment précis où l'on a perdu la mesure.
   */
  async onlineUsers(): Promise<number> {
    const keys = this.windowKeys(Date.now());
    return this.redis.getClient().pfcount(...keys);
  }

  /** Durée de la fenêtre, en secondes — pour documenter la mesure rendue. */
  get windowSeconds(): number {
    return this.config.presenceWindowSeconds;
  }

  private bucketKey(now: number): string {
    return `${KEY_PREFIX}${Math.floor(now / MINUTE_MS)}`;
  }

  /**
   * Les clés à fusionner. La minute en cours est INCLUSE en plus des minutes
   * pleines de la fenêtre : au tout début d'une minute, elle ne contient
   * presque rien, et s'en tenir aux minutes pleines écarterait précisément les
   * arrivants les plus récents.
   */
  private windowKeys(now: number): [string, ...string[]] {
    const minutes = Math.ceil(this.config.presenceWindowSeconds / 60);
    const current = Math.floor(now / MINUTE_MS);
    const keys: string[] = [];
    for (let offset = 0; offset <= minutes; offset += 1) {
      keys.push(`${KEY_PREFIX}${current - offset}`);
    }
    // `minutes` vaut au moins 1 (la fenêtre est un entier positif de secondes),
    // donc keys contient au moins deux éléments : le tuple non vide est réel.
    return keys as [string, ...string[]];
  }
}
