import { Body, Controller, Delete, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiProperty, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { IsNotEmpty, IsString, MaxLength } from 'class-validator';
import { type AccountDeletionResult, PASSWORD_MAX_LENGTH } from '@carlys/api-contracts';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import {
  type AuthenticatedPrincipal,
  clientContextOf,
} from '../../../../common/types/authenticated-request';
import { type RequestWithId } from '../../../../common/types/request-with-id';
import { AccountService } from '../../application/account.service';
import { STRICT_THROTTLE } from './throttles';

export class DeleteAccountDto {
  @ApiProperty({ description: 'Mot de passe actuel, exigé pour confirmer.' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(PASSWORD_MAX_LENGTH)
  password!: string;
}

@ApiTags('users')
@ApiBearerAuth()
@Controller('users')
export class AccountController {
  constructor(private readonly account: AccountService) {}

  @Throttle(STRICT_THROTTLE)
  @Delete('me')
  @ApiOperation({
    summary: 'Suppression du compte (mot de passe requis, abonnement Stripe résilié d’abord)',
    description:
      'D’abord, l’abonnement Stripe qui prélève encore (actif, en essai ou en ' +
      'retard de paiement) est résilié tout de suite chez Stripe ; si Stripe ne ' +
      'l’a pas fait, 503 SERVICE_UNAVAILABLE, message écrit pour la personne, et ' +
      'RIEN n’est supprimé. Un abonnement de magasin d’applications ne se ' +
      'résilie que dans le magasin : la réponse 200 porte alors ' +
      '`storeSubscriptionStillActive: true`, pour que l’appli dise de le faire. ' +
      'Puis, en une transaction : sessions révoquées et supprimées avec leurs ' +
      'refresh tokens, compte passé DELETED, adresse et code ami réécrits en ' +
      'valeurs tombales, profil personnel effacé (nom, naissance, sexe, ' +
      'taille), jetons d’appareil supprimés, photos de repas effacées (lignes ' +
      'dans la transaction, objets du bucket privé juste après). L’adresse ' +
      'redevient disponible pour une nouvelle inscription. La personne quitte ' +
      'aussitôt la ligue (sa ligne reste pour le règlement, sans nom), les ' +
      'défis entre amis (ceux qu’elle a lancés disparaissent, un défi en cours ' +
      'resté sans adversaire est annulé) et le fil d’encouragements des ' +
      'autres. L’historique ' +
      'd’activité reste, sans photo, le temps du délai de conservation (30 jours ' +
      'par défaut), puis la purge quotidienne l’efface (détail dans SECURITY.md). ' +
      '429 après AUTH_MAX_LOGIN_ATTEMPTS mots de passe erronés (compteur propre ' +
      'au compte, distinct de la connexion).',
  })
  async deleteAccount(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Body() dto: DeleteAccountDto,
    @Req() request: RequestWithId,
  ): Promise<AccountDeletionResult> {
    return this.account.deleteAccount(user.userId, dto.password, clientContextOf(request));
  }
}
