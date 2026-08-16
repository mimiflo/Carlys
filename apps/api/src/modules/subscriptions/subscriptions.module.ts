import { Module } from '@nestjs/common';
import { EntitlementsService } from './application/entitlements.service';
import { SubscriptionsService } from './application/subscriptions.service';
import { SubscriptionsRepository } from './infrastructure/subscriptions.repository';
import { StripeCheckoutClient } from './infrastructure/stripe-checkout.client';
import { SubscriptionsController } from './presentation/http/subscriptions.controller';

@Module({
  controllers: [SubscriptionsController],
  providers: [
    SubscriptionsService,
    EntitlementsService,
    SubscriptionsRepository,
    StripeCheckoutClient,
  ],
  exports: [EntitlementsService, SubscriptionsRepository],
})
export class SubscriptionsModule {}
