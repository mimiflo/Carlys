import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AdminRepository } from './infrastructure/admin.repository';
import { AdminAuthGuard } from './presentation/guards/admin-auth.guard';
import { AdminPermissionsGuard } from './presentation/guards/admin-permissions.guard';

/**
 * Accès au back-office : vérification du jeton admin et RBAC.
 *
 * Module à part parce que **d'autres modules protègent des routes
 * d'administration** (les médias aujourd'hui). Un garde référencé par
 * `@UseGuards(Classe)` est instancié dans le module qui porte le contrôleur,
 * pas dans celui qui l'exporte : il faut donc que ses propres dépendances
 * (`JwtService`, `AdminRepository`) soient résolvables là-bas. Ce module les
 * fournit ensemble, plutôt que de faire fuiter le dépôt de données de
 * l'administration à travers tout le projet.
 */
@Module({
  imports: [JwtModule.register({})],
  providers: [AdminRepository, AdminAuthGuard, AdminPermissionsGuard],
  exports: [JwtModule, AdminRepository, AdminAuthGuard, AdminPermissionsGuard],
})
export class AdminAccessModule {}
