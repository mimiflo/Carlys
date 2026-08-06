import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { JwtModule } from '@nestjs/jwt';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { EmailModule } from '../../infrastructure/email/email.module';
import { UsersModule } from '../users/users.module';
import { AccountService } from './application/account.service';
import { AuthService } from './application/auth.service';
import { LockoutService } from './application/lockout.service';
import { PasswordService } from './application/password.service';
import { SessionsService } from './application/sessions.service';
import { TokenService } from './application/token.service';
import { SessionsRepository } from './infrastructure/sessions.repository';
import { VerificationRepository } from './infrastructure/verification.repository';
import { AccountController } from './presentation/http/account.controller';
import { AuthController } from './presentation/http/auth.controller';
import { SessionsController } from './presentation/http/sessions.controller';

@Module({
  imports: [JwtModule.register({}), UsersModule, EmailModule],
  controllers: [AuthController, SessionsController, AccountController],
  providers: [
    AuthService,
    AccountService,
    SessionsService,
    PasswordService,
    TokenService,
    LockoutService,
    SessionsRepository,
    VerificationRepository,
    // Guard global : toute route est authentifiée sauf @Public().
    { provide: APP_GUARD, useClass: JwtAuthGuard },
  ],
  exports: [SessionsService, PasswordService],
})
export class AuthModule {}
