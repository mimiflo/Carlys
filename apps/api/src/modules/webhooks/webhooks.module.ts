import { Module } from '@nestjs/common';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module';
import { UsersModule } from '../users/users.module';
import { WebhooksService } from './application/webhooks.service';
import { WebhooksController } from './presentation/http/webhooks.controller';

@Module({
  imports: [SubscriptionsModule, UsersModule],
  controllers: [WebhooksController],
  providers: [WebhooksService],
})
export class WebhooksModule {}
