import { Injectable, UnauthorizedException } from '@nestjs/common';
import { type RequestClientContext } from '../../../common/types/authenticated-request';
import { AuditService } from '../../audit/audit.service';
import { UsersRepository } from '../../users/infrastructure/users.repository';
import { SessionsRepository } from '../infrastructure/sessions.repository';
import { PasswordService } from './password.service';

/**
 * Suppression de compte : action irréversible côté utilisateur.
 * Exige le mot de passe, révoque toutes les sessions puis désactive le
 * compte (suppression logique — purge/anonymisation différée documentée
 * dans SECURITY.md).
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

    await this.sessions.revokeAllSessions(userId, 'account_deleted');
    await this.users.softDelete(userId);
    this.audit.record({ action: 'account.deleted', userId, ...client });
  }
}
