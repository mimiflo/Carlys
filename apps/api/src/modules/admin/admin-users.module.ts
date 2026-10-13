import { Module } from '@nestjs/common';
import { AuditModule } from '../audit/audit.module';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module';
import { AdminUsersService } from './application/admin-users.service';
import { AdminUsersRepository } from './infrastructure/admin-users.repository';

/**
 * Gestion des comptes mobiles depuis le back-office (lecture, suspension,
 * droits manuels), à part d'`AdminModule` pour être réutilisable sans lui :
 * la modération de la communauté suspend par le MÊME chemin (sessions
 * révoquées, audit), alors qu'importer `AdminModule` refermerait la boucle
 * Communauté → Admin → Auth → Communauté.
 */
@Module({
  imports: [AuditModule, SubscriptionsModule],
  providers: [AdminUsersService, AdminUsersRepository],
  exports: [AdminUsersService],
})
export class AdminUsersModule {}
