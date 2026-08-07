import { type EntitlementsResponse, type SubscriptionMe } from '@carlys/api-contracts';
import { Controller, Get } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import { type AuthenticatedPrincipal } from '../../../../common/types/authenticated-request';
import { EntitlementsService } from '../../application/entitlements.service';
import { SubscriptionsService } from '../../application/subscriptions.service';

@ApiTags('subscriptions')
@ApiBearerAuth()
@Controller()
export class SubscriptionsController {
  constructor(
    private readonly subscriptions: SubscriptionsService,
    private readonly entitlements: EntitlementsService,
  ) {}

  @Get('subscriptions/me')
  @ApiOperation({ summary: "Abonnement courant et plan effectif de l'utilisateur" })
  me(@CurrentUser() user: AuthenticatedPrincipal): Promise<SubscriptionMe> {
    return this.subscriptions.me(user.userId);
  }

  @Get('entitlements')
  @ApiOperation({ summary: 'Droits effectifs — évalués côté serveur uniquement' })
  list(@CurrentUser() user: AuthenticatedPrincipal): Promise<EntitlementsResponse> {
    return this.entitlements.entitlementsFor(user.userId);
  }
}
