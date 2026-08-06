import { type AuthResult, type AuthTokens } from '@carlys/api-contracts';
import { Body, Controller, HttpCode, HttpStatus, Post, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import { Public } from '../../../../common/decorators/public.decorator';
import {
  type AuthenticatedPrincipal,
  clientContextOf,
} from '../../../../common/types/authenticated-request';
import { type RequestWithId } from '../../../../common/types/request-with-id';
import { AuthService } from '../../application/auth.service';
import {
  ChangePasswordDto,
  ForgotPasswordDto,
  LoginDto,
  RefreshDto,
  RegisterDto,
  ResetPasswordDto,
  VerifyEmailDto,
} from './dto/auth.dto';

/** Limites renforcées sur les endpoints sensibles à l'abus. */
const STRICT_THROTTLE = { default: { limit: 10, ttl: 60_000 } };

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Public()
  @Throttle(STRICT_THROTTLE)
  @Post('register')
  @ApiOperation({ summary: 'Inscription par e-mail' })
  register(@Body() dto: RegisterDto, @Req() request: RequestWithId): Promise<AuthResult> {
    return this.auth.register(dto, clientContextOf(request));
  }

  @Public()
  @Throttle(STRICT_THROTTLE)
  @Post('login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Connexion (verrouillage temporaire après échecs répétés)' })
  login(@Body() dto: LoginDto, @Req() request: RequestWithId): Promise<AuthResult> {
    return this.auth.login(dto, clientContextOf(request));
  }

  @Public()
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Rotation du refresh token (détection de réutilisation)' })
  refresh(@Body() dto: RefreshDto, @Req() request: RequestWithId): Promise<AuthTokens> {
    return this.auth.refresh(dto.refreshToken, clientContextOf(request));
  }

  @Post('logout')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Déconnexion de la session courante' })
  async logout(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Req() request: RequestWithId,
  ): Promise<void> {
    await this.auth.logout(user.userId, user.sessionId, clientContextOf(request));
  }

  @Public()
  @Throttle(STRICT_THROTTLE)
  @Post('verify-email')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: "Validation de l'adresse e-mail" })
  async verifyEmail(@Body() dto: VerifyEmailDto, @Req() request: RequestWithId): Promise<void> {
    await this.auth.verifyEmail(dto.token, clientContextOf(request));
  }

  @Post('resend-verification')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiBearerAuth()
  @ApiOperation({ summary: "Renvoi de l'e-mail de vérification" })
  async resendVerification(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Req() request: RequestWithId,
  ): Promise<void> {
    await this.auth.resendEmailVerification(user.userId, clientContextOf(request));
  }

  @Public()
  @Throttle(STRICT_THROTTLE)
  @Post('forgot-password')
  @HttpCode(HttpStatus.ACCEPTED)
  @ApiOperation({ summary: 'Demande de réinitialisation (réponse toujours identique)' })
  async forgotPassword(
    @Body() dto: ForgotPasswordDto,
    @Req() request: RequestWithId,
  ): Promise<{ message: string }> {
    await this.auth.forgotPassword(dto.email, clientContextOf(request));
    return {
      message:
        'Si un compte existe avec cette adresse, un e-mail de réinitialisation a été envoyé.',
    };
  }

  @Public()
  @Throttle(STRICT_THROTTLE)
  @Post('reset-password')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Réinitialisation du mot de passe (révoque toutes les sessions)' })
  async resetPassword(@Body() dto: ResetPasswordDto, @Req() request: RequestWithId): Promise<void> {
    await this.auth.resetPassword(dto.token, dto.newPassword, clientContextOf(request));
  }

  @Post('change-password')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Changement de mot de passe (révoque les autres sessions)' })
  async changePassword(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Body() dto: ChangePasswordDto,
    @Req() request: RequestWithId,
  ): Promise<void> {
    await this.auth.changePassword(
      user.userId,
      user.sessionId,
      dto.currentPassword,
      dto.newPassword,
      clientContextOf(request),
    );
  }
}
