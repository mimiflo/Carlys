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
import { EmailVerificationService } from '../../application/email-verification.service';
import { SocialAuthService } from '../../application/social-auth.service';
import {
  ChangePasswordDto,
  ForgotPasswordDto,
  LoginDto,
  RefreshDto,
  RegisterDto,
  ResetPasswordDto,
  SocialLoginDto,
  VerifyEmailDto,
} from './dto/auth.dto';
import { RESEND_VERIFICATION_THROTTLE, STRICT_THROTTLE } from './throttles';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly social: SocialAuthService,
    private readonly emailVerification: EmailVerificationService,
  ) {}

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
  @Throttle(STRICT_THROTTLE)
  @Post('social')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      "Connexion via Apple ou Google — jeton d'identité vérifié côté serveur " +
      '(503 tant que le fournisseur n’est pas configuré)',
  })
  socialLogin(@Body() dto: SocialLoginDto, @Req() request: RequestWithId): Promise<AuthResult> {
    return this.social.login(dto, clientContextOf(request));
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
    await this.emailVerification.verify(dto.token, clientContextOf(request));
  }

  @Throttle(RESEND_VERIFICATION_THROTTLE)
  @Post('resend-verification')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiBearerAuth()
  @ApiOperation({
    summary: "Renvoi de l'e-mail de vérification",
    description:
      'Toujours 204. Rien ne part si un lien a été envoyé il y a moins de 60 s, ' +
      'ou si 5 liens sont déjà partis en 24 h ; chaque envoi invalide les liens précédents.',
  })
  async resendVerification(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Req() request: RequestWithId,
  ): Promise<void> {
    await this.emailVerification.resend(user.userId, clientContextOf(request));
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

  @Throttle(STRICT_THROTTLE)
  @Post('change-password')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Changement de mot de passe (révoque les autres sessions)',
    description:
      '429 après AUTH_MAX_LOGIN_ATTEMPTS mots de passe actuels erronés, pendant ' +
      'AUTH_LOCKOUT_MINUTES : compteur propre au compte, distinct de la connexion.',
  })
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
