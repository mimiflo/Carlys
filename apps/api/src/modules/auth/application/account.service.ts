import { type AccountDeletionResult } from '@carlys/api-contracts';
import { ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { type RequestClientContext } from '../../../common/types/authenticated-request';
import { AuditService } from '../../audit/audit.service';
import { CommunityWithdrawalService } from '../../community/application/community-withdrawal.service';
import { MealPhotosService } from '../../nutrition/application/meal-photos.service';
import { AccountBillingService } from '../../subscriptions/application/account-billing.service';
import { UsersRepository } from '../../users/infrastructure/users.repository';
import { SessionsRepository } from '../infrastructure/sessions.repository';
import { normalizeEmail } from './auth.service';
import { ReauthenticationService } from './reauthentication.service';

/** Ce qu'une demande ÉCRITE d'effacement a donné (`deleted-accounts-purge --compte-actif`). */
export type WrittenRequestOutcome =
  | { readonly status: 'refused'; readonly reason: string }
  | {
      /** `planned` : à blanc, rien n'est touché. */
      readonly status: 'planned' | 'deleted';
      /** Abonnements Stripe résiliés (à blanc : à résilier). */
      readonly stripeSubscriptions: number;
      readonly storeSubscriptionStillActive: boolean;
    };

/**
 * Suppression de compte : action irréversible côté utilisateur.
 *
 * Exige le mot de passe. Résilie ENSUITE l'abonnement Stripe qui prélève
 * encore, AVANT de rien supprimer : si Stripe ne l'a pas fait, la
 * suppression est refusée (503 écrit pour la personne) — un compte supprimé
 * ne doit plus être prélevé. Un abonnement de magasin d'applications ne se
 * résilie que dans le magasin : la réponse le signale
 * (`storeSubscriptionStillActive`). Voir `AccountBillingService`.
 *
 * Puis, dans UNE transaction : supprime les sessions
 * et leurs refresh tokens (leurs ipAddress, userAgent et noms d'appareil
 * sont des données personnelles qui ne doivent pas survivre au compte —
 * l'audit garde sa propre ipAddress), passe le compte DELETED, libère
 * l'identité (adresse et code ami tombaux, nom et profil personnel effacés)
 * et supprime les jetons d'appareil ; les abonnements résiliés passent
 * CANCELED ; la personne quitte la ligue, les défis entre amis et le fil
 * d'encouragements des autres (`CommunityWithdrawalService`). L'adresse
 * redevient disponible pour une nouvelle inscription.
 *
 * La ligne User et l'historique d'activité (séances, records, journal
 * alimentaire, conversations coach) restent, sans plus rien qui identifie la
 * personne, le temps du délai de conservation : `deleted-accounts-purge`
 * (src/cli), lancé chaque jour par la supervision, les efface ensuite pour de
 * bon. Ce qui est conservé, combien de temps et pourquoi est écrit dans
 * SECURITY.md.
 *
 * Les PHOTOS de repas, elles, ne restent pas : une photo n'a rien d'un
 * chiffre anonyme. Leurs lignes partent dans la transaction ; leurs objets
 * (tout le préfixe de la personne dans le bucket privé, orphelins compris)
 * juste après, hors transaction puisque S3 n'en connaît pas. Un échec de ce
 * second temps est journalisé avec le `requestId` et ne rend pas la
 * suppression, déjà faite, faussement échouée : les objets, que plus aucune
 * ligne ne cite, sont repris par `meal-photos-sweep`.
 */
@Injectable()
export class AccountService {
  constructor(
    private readonly users: UsersRepository,
    private readonly sessions: SessionsRepository,
    private readonly reauth: ReauthenticationService,
    private readonly audit: AuditService,
    private readonly mealPhotos: MealPhotosService,
    private readonly billing: AccountBillingService,
    private readonly community: CommunityWithdrawalService,
  ) {}

  async deleteAccount(
    userId: string,
    password: string,
    client: RequestClientContext,
  ): Promise<AccountDeletionResult> {
    const passwordHash = await this.users.findPasswordHash(userId);
    if (passwordHash === null) {
      // Compte créé par connexion Apple/Google : il n'a JAMAIS eu de mot de
      // passe, et « incorrect » serait faux — la personne chercherait
      // indéfiniment un mot de passe qui n'existe pas, sans pouvoir exercer
      // son droit à l'effacement. On la renvoie au seul chemin qui marche.
      this.audit.record({ action: 'account.delete_without_password', userId, ...client });
      throw new ConflictException(
        'Ce compte n’a pas de mot de passe : il a été créé par une connexion ' +
          'Apple ou Google. Définis-en un avec « Mot de passe oublié », puis ' +
          'reviens supprimer ton compte.',
      );
    }
    // Verrouillage des re-authentifications (voir ReauthenticationService) :
    // sans lui, cette route était un oracle de mot de passe sans plafond.
    if (!(await this.reauth.verify(userId, passwordHash, password))) {
      this.audit.record({ action: 'account.delete_failed', userId, ...client });
      throw new UnauthorizedException('Mot de passe incorrect.');
    }

    const { storeSubscriptionStillActive } = await this.deleteVerified(userId, client, 'user');
    return { storeSubscriptionStillActive };
  }

  /**
   * Effacement d'un compte ENCORE ACTIF sur demande ÉCRITE de la personne,
   * par l'exploitation. L'identité, ici, c'est l'exploitant qui l'a vérifiée
   * : il recopie l'adresse du compte (`--confirmer`), qui doit être la bonne
   * — un identifiant mal collé ne supprime pas quelqu'un d'autre. Même
   * chemin que la route ensuite ([deleteVerified]), audité
   * `account.deleted_by_operator`. Un compte déjà supprimé est refusé : il
   * relève de `--compte`, qui l'efface sans le re-supprimer.
   */
  async deleteOnWrittenRequest(
    userId: string,
    confirmEmail: string,
    dryRun: boolean,
    requestId: string,
  ): Promise<WrittenRequestOutcome> {
    const user = await this.users.findActiveById(userId);
    if (user === null) {
      return {
        status: 'refused',
        reason: `Aucun compte actif ${userId} : rien n’est supprimé. Déjà supprimé ? --compte l’efface.`,
      };
    }
    if (normalizeEmail(confirmEmail) !== user.email) {
      return {
        status: 'refused',
        reason: 'La confirmation ne correspond pas à l’adresse du compte : rien n’est supprimé.',
      };
    }
    if (dryRun) {
      const plan = await this.billing.plan(userId);
      return {
        status: 'planned',
        stripeSubscriptions: plan.stripe.length,
        storeSubscriptionStillActive: plan.storeSubscriptionStillActive,
      };
    }
    const fait = await this.deleteVerified(userId, { requestId }, 'operator');
    return {
      status: 'deleted',
      stripeSubscriptions: fait.stripeSubscriptionsCanceled,
      storeSubscriptionStillActive: fait.storeSubscriptionStillActive,
    };
  }

  /**
   * La suppression elle-même, identité déjà prouvée : par le mot de passe
   * (`deleteAccount`), ou par la demande ÉCRITE qu'un exploitant a vérifiée
   * (`deleted-accounts-purge --compte-actif`). Un seul chemin pour les deux,
   * pour que l'effacement demandé par écrit résilie et retire exactement
   * comme celui que la personne fait elle-même.
   */
  async deleteVerified(
    userId: string,
    client: RequestClientContext,
    by: 'user' | 'operator',
  ): Promise<AccountDeletionResult & { stripeSubscriptionsCanceled: number }> {
    const plan = await this.billing.plan(userId);
    const stopped = await this.billing.stop(plan, client.requestId);
    await this.users.deleteAccount(userId, async (tx) => {
      await this.sessions.deleteAllSessions(userId, tx);
      await this.mealPhotos.forgetAllOf(userId, tx);
      await this.billing.markStopped(stopped, tx);
      await this.community.withdraw(userId, tx);
    });
    await this.sessions.forgetCachedSessions(userId);
    this.audit.record({
      ...(by === 'operator'
        ? { action: 'account.deleted_by_operator', actorType: 'SYSTEM' as const }
        : { action: 'account.deleted' }),
      userId,
      ...client,
      metadata: {
        stripeSubscriptionsCanceled: stopped.length,
        storeSubscriptionStillActive: plan.storeSubscriptionStillActive,
      },
    });
    await this.mealPhotos.eraseAllOf(userId, client.requestId);
    return {
      storeSubscriptionStillActive: plan.storeSubscriptionStillActive,
      stripeSubscriptionsCanceled: stopped.length,
    };
  }
}
