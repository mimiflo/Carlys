import { BadRequestException, Controller, HttpCode, HttpStatus, Post, Req } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { Public } from '../../../../common/decorators/public.decorator';
import { type WebhookAck, WebhooksService } from '../../application/webhooks.service';

/**
 * Webhooks de paiement — publics mais SIGNÉS (la vérification de signature
 * remplace l'authentification) et idempotents. Le corps BRUT est préservé
 * par un middleware dédié (voir configure-app.ts) pour vérifier la signature
 * sur les octets exacts reçus.
 */
@ApiTags('webhooks')
@Public()
@Controller('webhooks')
export class WebhooksController {
  constructor(private readonly webhooks: WebhooksService) {}

  @Post('stripe')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Webhook Stripe (signature Stripe-Signature, idempotent)' })
  stripe(@Req() request: Request): Promise<WebhookAck> {
    return this.webhooks.handleStripe(rawBodyOf(request), headerOf(request, 'stripe-signature'));
  }

  @Post('revenuecat')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Webhook RevenueCat (Authorization Bearer, idempotent)' })
  revenuecat(@Req() request: Request): Promise<WebhookAck> {
    return this.webhooks.handleRevenueCat(rawBodyOf(request), headerOf(request, 'authorization'));
  }
}

function rawBodyOf(request: Request): Buffer {
  if (!Buffer.isBuffer(request.body)) {
    throw new BadRequestException('Corps brut attendu.');
  }
  return request.body;
}

function headerOf(request: Request, name: string): string | undefined {
  const value = request.headers[name];
  return typeof value === 'string' ? value : undefined;
}
