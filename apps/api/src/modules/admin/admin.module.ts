import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AuditModule } from '../audit/audit.module';
import { AuthModule } from '../auth/auth.module';
import { ExercisesModule } from '../exercises/exercises.module';
import { AdminAuthService } from './application/admin-auth.service';
import { AdminPlatformService } from './application/admin-platform.service';
import { AdminUsersService } from './application/admin-users.service';
import { AdminRepository } from './infrastructure/admin.repository';
import { AdminAuthController } from './presentation/http/admin-auth.controller';
import { AdminPlatformController } from './presentation/http/admin-platform.controller';
import { AdminUsersController } from './presentation/http/admin-users.controller';
import { AdminAuthGuard } from './presentation/guards/admin-auth.guard';
import { AdminPermissionsGuard } from './presentation/guards/admin-permissions.guard';

/**
 * Back-office : comptes SÉPARÉS des comptes mobiles, RBAC par permissions,
 * toutes les actions sensibles auditées.
 */
@Module({
  imports: [JwtModule.register({}), AuthModule, AuditModule, ExercisesModule],
  controllers: [AdminAuthController, AdminUsersController, AdminPlatformController],
  providers: [
    AdminAuthService,
    AdminUsersService,
    AdminPlatformService,
    AdminRepository,
    AdminAuthGuard,
    AdminPermissionsGuard,
  ],
})
export class AdminModule {}
