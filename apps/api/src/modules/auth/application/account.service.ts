import { Injectable, UnauthorizedException } from '@nestjs/common';
import { type RequestClientContext } from '../../../common/types/authenticated-request';
import { AuditService } from '../../audit/audit.service';
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
 */
@Injectable()
export class AccountService {
  constructor(
    private readonly users: UsersRepository,
    private readonly sessions: SessionsRepository,
    private readonly passwords: PasswordService,
    private readonly audit: AuditService,
  ) {}

  async deleteAccount(
    userId: string,
    password: string,
    client: RequestClientContext,
  ): Promise<void> {
    const passwordHash = await this.users.findPasswordHash(userId);
    if (passwordHash === null || !(await this.passwords.verify(passwordHash, password))) {
      this.audit.record({ action: 'account.delete_failed', userId, ...client });
      throw new UnauthorizedException('Mot de passe incorrect.');
    }

    await this.users.deleteAccount(userId, (tx) => this.sessions.deleteAllSessions(userId, tx));
    this.audit.record({ action: 'account.deleted', userId, ...client });
  }
}
