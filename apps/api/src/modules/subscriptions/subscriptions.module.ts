import { Module } from '@nestjs/common';
import { EntitlementsService } from './application/entitlements.service';
import { SubscriptionsService } from './application/subscriptions.service';
import { SubscriptionsRepository } from './infrastructure/subscriptions.repository';
import { SubscriptionsController } from './presentation/http/subscriptions.controller';

@Module({
  controllers: [SubscriptionsController],
  providers: [SubscriptionsService, EntitlementsService, SubscriptionsRepository],
  exports: [EntitlementsService, SubscriptionsRepository],
})
export class SubscriptionsModule {}
