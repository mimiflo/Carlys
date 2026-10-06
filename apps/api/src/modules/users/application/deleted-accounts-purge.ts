import {
  deleteEverythingUnder,
  type PrivateObjectStore,
} from '../../../infrastructure/storage/private-object-store';
import { mealPhotoPrefixOf } from '../../nutrition/domain/meal-photo-key';

/**
 * Délai de conservation, par défaut, des données d'un compte SUPPRIMÉ avant
 * leur effacement définitif : 30 jours. C'est le délai qu'ANNONCENT la
 * politique de confidentialité (docs/legal/privacy.md, section 6), les CGU
 * (docs/legal/terms.md, section 9) et l'écran de suppression : le changer
 * ici, ou par `CARLYS_ACCOUNT_PURGE_DAYS` (`--delai-jours`), c'est changer
 * ces textes avec lui — la liste complète est dans SECURITY.md, « Données
 * personnelles ». Il laisse le temps de traiter une contestation ou une
 * erreur de manipulation avant que plus rien n'existe.
 */
export const DEFAULT_PURGE_DELAY_DAYS = 30;

/**
 * Conservation des événements de paiement EN ÉCHEC qui ne nomment aucun
 * compte : 90 jours. Un webhook RevenueCat d'un achat anonyme
 * (`$RCAnonymousID`) ou une charge Stripe sans `metadata.userId` ne se
 * projette jamais, et sa charge utile brute (identifiants de transaction,
 * parfois une adresse) restait pour toujours : la purge d'un compte ne le
 * retrouve pas, puisqu'il n'en nomme aucun. Trois mois laissent le temps de
 * lire `processingError` et de rejouer à la main ce qui devait l'être.
 */
export const ORPHAN_PAYMENT_EVENT_RETENTION_DAYS = 90;

/**
 * Conservation d'une session CLOSE (révoquée, ou expirée faute de
 * renouvellement) et d'un jeton de renouvellement échu : 30 jours. Chaque
 * rotation écrit un jeton, et rien n'en effaçait aucun hors suppression de
 * compte : des dizaines de lignes par personne et par jour, pour toujours,
 * et autant de sessions mortes avec leur adresse IP et leur `userAgent`.
 *
 * LE COMPROMIS, assumé : un jeton ROTATED est un PIÈGE — présenté, il
 * révoque toute sa session, donc éjecte qui en aurait volé la suite. Effacé,
 * il ne rend plus qu'un 401. Le piège tient donc TTL + 30 jours après
 * l'émission du jeton (60 jours par défaut), plus « pour toujours ». Le
 * borner autrement, c'est une durée de vie ABSOLUE de session (reconnexion
 * forcée) : une décision produit, pas une purge.
 */
export const DEAD_SESSION_RETENTION_DAYS = 30;

/** Ce que la passe des sessions a effacé (ou compté, à blanc). */
export interface SessionsPurged {
  /** Sessions closes ; leurs jetons et jetons push partent par cascade. */
  readonly sessions: number;
  /** Jetons de renouvellement échus, toutes sessions confondues. */
  readonly refreshTokens: number;
}

/** L'accès aux comptes supprimés — la base, pour la purge et elle seule. */
export interface DeletedAccountsLedger {
  /** Identifiants des comptes DELETED supprimés avant `before`. */
  listDeletedBefore(before: Date): Promise<string[]>;
  /** `true` si le compte `id` est DELETED (ni inconnu, ni encore actif). */
  isDeleted(id: string): Promise<boolean>;
  /**
   * Efface le compte et TOUT ce qui s'y rattache, dans une transaction.
   * `false` : le compte n'était plus DELETED (ou n'existait plus).
   */
  eraseAccount(id: string): Promise<boolean>;
  /** Événements de paiement jamais appliqués, sans compte, reçus avant `before`. */
  countOrphanPaymentEventsBefore(before: Date): Promise<number>;
  /** Les efface ; rend combien. */
  eraseOrphanPaymentEventsBefore(before: Date): Promise<number>;
  /** Jetons échus avant `before`, sessions closes (révoquées ou expirées) avant `before`. */
  countDeadSessionsBefore(before: Date): Promise<SessionsPurged>;
  /** Les efface ; rend combien. */
  eraseDeadSessionsBefore(before: Date): Promise<SessionsPurged>;
}

export interface PurgeOptions {
  readonly now: Date;
  readonly delayDays: number;
  /** Effacement IMMÉDIAT de ce compte-là, délai ignoré (demande écrite). */
  readonly accountId?: string;
  readonly dryRun: boolean;
}

export interface PurgeReport {
  /** Comptes éligibles trouvés. */
  readonly eligible: number;
  /** Comptes effacés (0 à blanc). */
  readonly erased: number;
  /** Photos privées effacées. */
  readonly objectsDeleted: number;
  /**
   * Événements de paiement en échec et sans compte, plus vieux que
   * [ORPHAN_PAYMENT_EVENT_RETENTION_DAYS] : effacés (comptés à blanc). La
   * passe quotidienne seule s'en charge, jamais un effacement ciblé.
   */
  readonly paymentEventsErased: number;
  /**
   * Sessions closes et jetons échus depuis plus de
   * [DEAD_SESSION_RETENTION_DAYS] : effacés (comptés à blanc), par la passe
   * quotidienne seule.
   */
  readonly sessionsErased: SessionsPurged;
  /** Un message par compte qui n'a pas pu être effacé. */
  readonly failures: readonly string[];
  /** `--compte` visait un compte introuvable ou encore actif. */
  readonly refused: string | null;
}

/**
 * EFFACEMENT DÉFINITIF des comptes supprimés depuis plus de `delayDays`.
 *
 * La suppression d'un compte par la personne (`DELETE /users/me`) désactive
 * tout de suite et libère l'identité ; l'historique (séances, repas, mesures,
 * conversations du coach, encouragements…) restait ensuite rattaché à un
 * identifiant, indéfiniment, alors que la politique et l'écran de suppression
 * promettaient un effacement après un délai. Cette purge tient la promesse.
 *
 * Pour chaque compte, dans cet ordre :
 *  1. les photos privées (tout le préfixe du compte dans le bucket privé,
 *     orphelins compris) — AVANT la base : si le stockage ne répond pas, la
 *     ligne reste, et le passage suivant réessaie avec le même identifiant ;
 *  2. la base : le compte et, par cascade, tout ce qui s'y rattache, plus la
 *     trace des webhooks de paiement qui le nomment.
 *
 * La passe quotidienne efface aussi les événements de paiement en échec qui
 * ne nomment AUCUN compte, passé [ORPHAN_PAYMENT_EVENT_RETENTION_DAYS], et
 * les sessions closes et jetons échus, passé [DEAD_SESSION_RETENTION_DAYS].
 *
 * Seul un compte DELETED est effacé, jamais un compte actif ou suspendu, y
 * compris par `--compte`. Le journal d'audit n'est PAS effacé : il perd le
 * lien vers le compte (`userId` à nul) et suit sa propre durée de
 * conservation.
 */
export async function purgeDeletedAccounts(
  ledger: DeletedAccountsLedger,
  store: PrivateObjectStore,
  options: PurgeOptions,
): Promise<PurgeReport> {
  const accounts = await targets(ledger, options);
  if (accounts === null) {
    return {
      eligible: 0,
      erased: 0,
      objectsDeleted: 0,
      paymentEventsErased: 0,
      sessionsErased: AUCUNE_SESSION,
      failures: [],
      refused: `Le compte ${options.accountId ?? ''} n’est pas un compte supprimé : rien n’est effacé.`,
    };
  }
  let erased = 0;
  let objectsDeleted = 0;
  const failures: string[] = [];
  for (const id of options.dryRun ? [] : accounts) {
    try {
      objectsDeleted += await deleteEverythingUnder(store, mealPhotoPrefixOf(id));
      if (await ledger.eraseAccount(id)) {
        erased += 1;
      }
    } catch (error) {
      failures.push(`${id} : ${(error as Error).message}`);
    }
  }
  // Le ménage APRÈS les comptes, et chacun pour soi : son échec (base
  // coupée, délai dépassé sur un gros arriéré de jetons) ne doit jamais
  // retarder l'effacement que les CGU promettent à 30 jours.
  const paymentEventsErased = await dailyPass(
    options,
    0,
    ORPHAN_PAYMENT_EVENT_RETENTION_DAYS,
    (before) => ledger.countOrphanPaymentEventsBefore(before),
    (before) => ledger.eraseOrphanPaymentEventsBefore(before),
    (message) => failures.push(`paiements orphelins : ${message}`),
  );
  const sessionsErased = await dailyPass(
    options,
    AUCUNE_SESSION,
    DEAD_SESSION_RETENTION_DAYS,
    (before) => ledger.countDeadSessionsBefore(before),
    (before) => ledger.eraseDeadSessionsBefore(before),
    (message) => failures.push(`sessions closes : ${message}`),
  );
  return {
    eligible: accounts.length,
    erased,
    objectsDeleted,
    paymentEventsErased,
    sessionsErased,
    failures,
    refused: null,
  };
}

const AUCUNE_SESSION: SessionsPurged = { sessions: 0, refreshTokens: 0 };

/** La passe quotidienne seule : un effacement ciblé ne touche qu'à son compte. */
function dailyPass<T>(
  options: PurgeOptions,
  none: T,
  retentionDays: number,
  count: (before: Date) => Promise<T>,
  erase: (before: Date) => Promise<T>,
  fail: (message: string) => void,
): Promise<T> {
  if (options.accountId !== undefined) {
    return Promise.resolve(none);
  }
  const before = new Date(options.now.getTime() - retentionDays * 24 * 3_600_000);
  return (options.dryRun ? count(before) : erase(before)).catch((error: unknown) => {
    fail(error instanceof Error ? error.message : String(error));
    return none;
  });
}

/**
 * Les comptes à traiter, ou `null` quand `--compte` vise un compte non supprimé.
 *
 * Une seule lecture, d'identifiants seuls : un arriéré de dix mille comptes
 * tient en mémoire sans peine. Un compte dont l'effacement échoue reste
 * DELETED et revient au passage suivant — une boucle « lister, effacer,
 * relister » tournerait sans fin sur lui.
 */
async function targets(
  ledger: DeletedAccountsLedger,
  options: PurgeOptions,
): Promise<string[] | null> {
  if (options.accountId !== undefined) {
    return (await ledger.isDeleted(options.accountId)) ? [options.accountId] : null;
  }
  return ledger.listDeletedBefore(
    new Date(options.now.getTime() - options.delayDays * 24 * 3_600_000),
  );
}
