import { Module } from '@nestjs/common';
import { AuditModule } from '../audit/audit.module';
import { AuthModule } from '../auth/auth.module';
import { ExercisesModule } from '../exercises/exercises.module';
import { AdminAccessModule } from './admin-access.module';
import { AdminAuthService } from './application/admin-auth.service';
import { AdminCatalogService } from './application/admin-catalog.service';
import { AdminCategoriesService } from './application/admin-categories.service';
import { AdminPlatformService } from './application/admin-platform.service';
import { AdminUsersService } from './application/admin-users.service';
import { AdminAuthController } from './presentation/http/admin-auth.controller';
import {
  AdminCatalogController,
  AdminCategoriesController,
} from './presentation/http/admin-catalog.controller';
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
  controllers: [
    AdminAuthController,
    AdminUsersController,
    AdminPlatformController,
    AdminCatalogController,
    AdminCategoriesController,
  ],
  providers: [
    AdminAuthService,
    AdminUsersService,
    AdminPlatformService,
    AdminCatalogService,
    AdminCategoriesService,
  ],
})
export class AdminModule {}
