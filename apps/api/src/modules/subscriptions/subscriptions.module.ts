import { Module } from '@nestjs/common';
import { EntitlementsService } from './application/entitlements.service';
import { SubscriptionsService } from './application/subscriptions.service';
import { StripeBillingPortalClient } from './infrastructure/stripe-billing-portal.client';
import { StripeCheckoutClient } from './infrastructure/stripe-checkout.client';
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
  ],
  exports: [EntitlementsService, SubscriptionsRepository],
})
export class SubscriptionsModule {}
