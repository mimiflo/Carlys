import { Module } from '@nestjs/common';
import { AccountBillingService } from './application/account-billing.service';
import { EntitlementsService } from './application/entitlements.service';
import { SubscriptionsService } from './application/subscriptions.service';
import { StripeBillingPortalClient } from './infrastructure/stripe-billing-portal.client';
import { StripeCheckoutClient } from './infrastructure/stripe-checkout.client';
import { StripeSubscriptionClient } from './infrastructure/stripe-subscription.client';
import { SubscriptionsRepository } from './infrastructure/subscriptions.repository';
import { SubscriptionsController } from './presentation/http/subscriptions.controller';

@Module({
  controllers: [SubscriptionsController],
  providers: [
    SubscriptionsService,
    EntitlementsService,
    SubscriptionsRepository,
    StripeCheckoutClient,
    StripeBillingPortalClient,
    StripeSubscriptionClient,
    AccountBillingService,
  ],
  // AccountBillingService : la suppression du compte résilie d'abord.
  exports: [EntitlementsService, SubscriptionsRepository, AccountBillingService],
})
export class SubscriptionsModule {}
