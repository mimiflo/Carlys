import {
  type BillingPortalSession,
  type CheckoutSession,
  type EntitlementsResponse,
  type SubscriptionMe,
  type SubscriptionOffersResponse,
} from '@carlys/api-contracts';
import { Body, Controller, Get, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CreateCheckoutDto } from './create-checkout.dto';
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

  @Get('subscriptions/offers')
  @ApiOperation({
    summary: 'Catalogue d’offres — les prix viennent du serveur, jamais de l’application',
  })
  offers(): SubscriptionOffersResponse {
    return this.subscriptions.offers();
  }

  @Post('subscriptions/checkout')
  @ApiOperation({
    summary: 'Ouvre une page de paiement',
    description:
      'N’accorde AUCUN droit : c’est le webhook signé qui l’accorde, une fois le ' +
      'paiement encaissé. 503 tant que le paiement n’est pas configuré.',
  })
  checkout(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Body() body: CreateCheckoutDto,
  ): Promise<CheckoutSession> {
    return this.subscriptions.createCheckout(user.userId, body.offerId, body.id);
  }

  @Post('subscriptions/portal')
  @ApiOperation({
    summary: 'Ouvre le portail de gestion de l’abonnement (Stripe Billing Portal)',
    description:
      'Résiliation, moyen de paiement, factures. Réponse { url } à ouvrir dans ' +
      'le navigateur, retour vers ${PUBLIC_APP_URL}/abonnement. 409 si aucun ' +
      'client Stripe n’est connu pour le compte (plan gratuit, ou abonnement ' +
      'passé par un magasin d’applications) ; 503 tant que le paiement n’est ' +
      'pas configuré.',
  })
  portal(@CurrentUser() user: AuthenticatedPrincipal): Promise<BillingPortalSession> {
    return this.subscriptions.createPortal(user.userId);
  }

  @Get('entitlements')
  @ApiOperation({ summary: 'Droits effectifs — évalués côté serveur uniquement' })
  list(@CurrentUser() user: AuthenticatedPrincipal): Promise<EntitlementsResponse> {
    return this.entitlements.entitlementsFor(user.userId);
  }
}
