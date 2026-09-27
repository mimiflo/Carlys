/**
 * `deleted-accounts-purge --compte-actif <uuid> --confirmer <adresse>` :
 * l'effacement d'un compte ENCORE ACTIF, sur demande écrite. Voir l'en-tête
 * de `deleted-accounts-purge.ts`. À part parce que cette voie, et elle
 * seule, démarre l'application : la purge quotidienne reste un client
 * Prisma nu.
 */
import { randomUUID } from 'node:crypto';
import { type INestApplicationContext } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AuditService } from '../modules/audit/audit.service';
import {
  AccountService,
  type WrittenRequestOutcome,
} from '../modules/auth/application/account.service';

/** Un compte ENCORE ACTIF à effacer sur demande écrite, et l'adresse recopiée. */
export interface ActiveAccountRequest {
  readonly id: string;
  readonly confirmEmail: string;
}

/** Ce qu'une demande écrite a fait (ou ferait, à blanc). */
export function formatWrittenRequest(
  outcome: Exclude<WrittenRequestOutcome, { status: 'refused' }>,
  id: string,
): string {
  const simulation = outcome.status === 'planned';
  const lignes = [
    simulation
      ? `Simulation (--a-blanc) : RIEN n’a été supprimé. Compte ${id}, demande écrite :`
      : `Compte ${id} supprimé comme par DELETE /users/me, ligne d’audit account.deleted_by_operator.`,
    `  abonnements Stripe ${simulation ? 'à résilier' : 'résiliés'} : ${outcome.stripeSubscriptions}`,
  ];
  if (outcome.storeSubscriptionStillActive) {
    lignes.push(
      '  ATTENTION : un abonnement App Store ou Play Store court encore. Le serveur ne',
      '  peut pas le résilier : dis à la personne de le résilier dans le magasin.',
    );
  }
  if (simulation) {
    lignes.push('  puis : suppression (même chemin que DELETE /users/me) et effacement immédiat.');
  }
  return `${lignes.join('\n')}\n`;
}

export interface CliOutput {
  readonly out: (text: string) => void;
  readonly err: (text: string) => void;
}

/**
 * `--compte-actif`, premier temps : la suppression par le chemin de la
 * route. Rend `'deleted'` quand le compte est supprimé et sa ligne d'audit
 * posée — l'appelant l'efface alors comme `--compte` —, sinon le code de
 * sortie (2 : refus, 0 : simulation faite, 1 : audit non écrit).
 */
export async function deleteActiveAccount(
  app: INestApplicationContext,
  request: ActiveAccountRequest,
  dryRun: boolean,
  io: CliOutput,
): Promise<number | 'deleted'> {
  const outcome = await app
    .get(AccountService)
    .deleteOnWrittenRequest(request.id, request.confirmEmail, dryRun, `cli-${randomUUID()}`);
  if (outcome.status === 'refused') {
    io.err(`${outcome.reason}\n`);
    return 2;
  }
  io.out(formatWrittenRequest(outcome, request.id));
  if (outcome.status === 'planned') {
    return 0;
  }
  // La ligne d'audit s'écrit en tâche de fond et NOMME le compte : posée
  // après l'effacement, elle violerait la clé étrangère et se perdrait.
  const audit = await app.get(AuditService).flush();
  if (audit.echouees > 0 || audit.abandonnees > 0) {
    io.err(
      `La ligne d’audit n’a pas pu être écrite : le compte est supprimé, PAS effacé. ` +
        `Relancer avec --compte ${request.id} une fois la base réparée.\n`,
    );
    return 1;
  }
  return 'deleted';
}

/** L'application entière, le temps d'un travail : le chemin de la route, pas une copie. */
export async function withApplication<T>(
  work: (app: INestApplicationContext) => Promise<T>,
): Promise<T> {
  // Le compte rendu est pour un humain : les journaux d'information de
  // l'application le noieraient. Avertissements et erreurs restent.
  process.env.LOG_LEVEL = 'warn';
  // Import DIFFÉRÉ : charger `AppModule` valide la configuration de toute
  // l'application ; la purge quotidienne, qui n'en a pas besoin, n'a pas à
  // en dépendre.
  const { AppModule } = await import('../app/app.module.js');
  const app = await NestFactory.createApplicationContext(AppModule, { logger: ['error', 'warn'] });
  try {
    return await work(app);
  } finally {
    await app.close();
  }
}
