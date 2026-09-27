import { type HealthComponent } from '@carlys/api-contracts';
import { type PinoLogger } from 'nestjs-pino';
import { withTimeout } from '../../../common/utilities/with-timeout';

/** Au-delà, la dépendance est déclarée en panne : une sonde lente n'aide personne. */
export const PROBE_TIMEOUT_MS = 2_000;

/**
 * Le seul libellé qu'une sonde en échec PUBLIE.
 *
 * `/health` est routé publiquement (nginx), et la page d'accueil de
 * l'administration l'affiche sans connexion. La sonde renvoyait
 * `error.message` tel quel : pour une base arrêtée, Prisma y écrit
 * « Can't reach database server at `10.20.30.40:5432` », ioredis
 * « connect ECONNREFUSED 10.20.30.41:6379 ». L'hôte et le port internes
 * partaient donc sur Internet à chaque panne franche (le délai de deux
 * secondes ne masquait que les pannes LENTES).
 *
 * Le détail n'est pas perdu pour autant : il part au journal, avec l'erreur
 * complète et le `requestId` de l'appel qui l'a constatée.
 */
export const PROBE_DOWN_LABEL = 'injoignable';

/**
 * Exécute une sonde : `up` et sa latence, ou `down` et le libellé public.
 *
 * Journalisé en `warn` et non en `error` : pendant une panne, l'orchestrateur
 * interroge `/health/ready` toutes les quelques secondes, et chaque passage
 * redirait la même chose. La panne elle-même se voit au 503.
 */
export async function runProbe(
  label: string,
  check: () => Promise<unknown>,
  logger: PinoLogger,
): Promise<HealthComponent> {
  const startedAt = Date.now();
  try {
    await withTimeout(check(), PROBE_TIMEOUT_MS, label);
    return { status: 'up', latencyMs: Date.now() - startedAt };
  } catch (error) {
    logger.warn({ err: error, component: label }, `Sonde de santé en échec : ${label}`);
    return { status: 'down', error: PROBE_DOWN_LABEL };
  }
}
