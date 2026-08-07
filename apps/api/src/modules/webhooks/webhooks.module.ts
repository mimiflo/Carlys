import { Module } from '@nestjs/common';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module';
import { WebhooksService } from './application/webhooks.service';
import { WebhooksController } from './presentation/http/webhooks.controller';

@Module({
  imports: [SubscriptionsModule],
  controllers: [WebhooksController],
  providers: [WebhooksService],
})
export class WebhooksModule {}
