import { Module } from '@nestjs/common';
import { AuditModule } from '../audit/audit.module';
import { AuthModule } from '../auth/auth.module';
import { ExercisesModule } from '../exercises/exercises.module';
import { AdminAccessModule } from './admin-access.module';
import { AdminAuthService } from './application/admin-auth.service';
import { AdminPlatformService } from './application/admin-platform.service';
import { AdminUsersService } from './application/admin-users.service';
import { AdminAuthController } from './presentation/http/admin-auth.controller';
import { AdminPlatformController } from './presentation/http/admin-platform.controller';
import { AdminUsersController } from './presentation/http/admin-users.controller';

/**
 * Back-office : comptes SÉPARÉS des comptes mobiles, RBAC par permissions,
 * toutes les actions sensibles auditées. Les jetons, le dépôt de données et
 * les gardes viennent d'`AdminAccessModule`, partagé avec les autres modules
 * qui exposent des routes d'administration.
 */
@Module({
  imports: [AdminAccessModule, AuthModule, AuditModule, ExercisesModule],
  controllers: [AdminAuthController, AdminUsersController, AdminPlatformController],
  providers: [AdminAuthService, AdminUsersService, AdminPlatformService],
})
export class AdminModule {}
