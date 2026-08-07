import { type AdminLoginResult, type AdminMe } from '@carlys/api-contracts';
import { Body, Controller, Get, HttpCode, HttpStatus, Post, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../../../../common/decorators/public.decorator';
import { clientContextOf } from '../../../../common/types/authenticated-request';
import { type RequestWithId } from '../../../../common/types/request-with-id';
import { AdminAuthService } from '../../application/admin-auth.service';
import { CurrentAdmin } from '../decorators/current-admin.decorator';
import { AdminAuthGuard, type AdminPrincipal } from '../guards/admin-auth.guard';
import { AdminLoginDto } from './dto/admin.dto';

/** Limites renforcées : la connexion admin est une cible d'abus évidente. */
const STRICT_THROTTLE = { default: { limit: 10, ttl: 60_000 } };

/**
 * Authentification du back-office. Routes marquées @Public() pour le guard
 * global des comptes MOBILES : l'accès est contrôlé par AdminAuthGuard
 * (audience JWT dédiée, compte revérifié en base à chaque requête).
 */
@ApiTags('admin')
@Public()
@Controller('admin/auth')
export class AdminAuthController {
  constructor(private readonly adminAuth: AdminAuthService) {}

  @Post('login')
  @Throttle(STRICT_THROTTLE)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Connexion administrateur (comptes séparés du mobile)' })
  login(@Body() dto: AdminLoginDto, @Req() request: RequestWithId): Promise<AdminLoginResult> {
    return this.adminAuth.login(dto, clientContextOf(request));
  }

  @Get('me')
  @UseGuards(AdminAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Profil, rôles et permissions de l’administrateur courant' })
  me(@CurrentAdmin() admin: AdminPrincipal): Promise<AdminMe> {
    return this.adminAuth.me(admin.adminUserId);
  }
}
