import { ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { type RequestClientContext } from '../../../common/types/authenticated-request';
import { AuditService } from '../../audit/audit.service';
import { MealPhotosService } from '../../nutrition/application/meal-photos.service';
import { UsersRepository } from '../../users/infrastructure/users.repository';
import { SessionsRepository } from '../infrastructure/sessions.repository';
import { PasswordService } from './password.service';

/**
 * Suppression de compte : action irréversible côté utilisateur.
 *
 * Exige le mot de passe, puis, dans UNE transaction : supprime les sessions
 * et leurs refresh tokens (leurs ipAddress, userAgent et noms d'appareil
 * sont des données personnelles qui ne doivent pas survivre au compte —
 * l'audit garde sa propre ipAddress), passe le compte DELETED, libère
 * l'identité (adresse et code ami tombaux, nom et profil personnel effacés)
 * et supprime les jetons d'appareil. L'adresse redevient disponible pour
 * une nouvelle inscription.
 *
 * La ligne User et l'historique d'activité (séances, records, journal
 * alimentaire, conversations coach) restent, sans plus rien qui identifie la
 * personne ; ce qui est conservé et pourquoi est écrit dans SECURITY.md.
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
    private readonly passwords: PasswordService,
    private readonly audit: AuditService,
    private readonly mealPhotos: MealPhotosService,
  ) {}

  async deleteAccount(
    userId: string,
    password: string,
    client: RequestClientContext,
  ): Promise<void> {
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
    if (!(await this.passwords.verify(passwordHash, password))) {
      this.audit.record({ action: 'account.delete_failed', userId, ...client });
      throw new UnauthorizedException('Mot de passe incorrect.');
    }

    await this.users.deleteAccount(userId, async (tx) => {
      await this.sessions.deleteAllSessions(userId, tx);
      await this.mealPhotos.forgetAllOf(userId, tx);
    });
    this.audit.record({ action: 'account.deleted', userId, ...client });
    await this.mealPhotos.eraseAllOf(userId, client.requestId);
  }
}
