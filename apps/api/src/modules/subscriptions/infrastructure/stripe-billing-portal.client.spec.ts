import { BadGatewayException, ServiceUnavailableException } from '@nestjs/common';
import { type AppConfigService } from '../../../config/app-config.service';
import { StripeBillingPortalClient } from './stripe-billing-portal.client';

function buildClient(config: { stripeSecretKey?: string }): StripeBillingPortalClient {
  return new StripeBillingPortalClient({
    publicAppUrl: 'https://app.carlys.test',
    ...config,
  } as unknown as AppConfigService);
}

function fetchReturning(status: number, payload: unknown): jest.Mock {
  return jest
    .fn()
    .mockResolvedValue({ ok: status < 400, status, json: () => Promise.resolve(payload) });
}

describe('StripeBillingPortalClient', () => {
  const originalFetch = global.fetch;
  afterEach(() => {
    global.fetch = originalFetch;
  });

  it('sans clé secrète : 503, sans appel réseau', async () => {
    const fetchMock = fetchReturning(200, {});
    global.fetch = fetchMock;
    const client = buildClient({});

    expect(client.isConfigured).toBe(false);
    await expect(client.createSession({ customerId: 'cus_1' })).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('ouvre le portail du client, avec retour vers la page Abonnement de l’application web', async () => {
    const fetchMock = fetchReturning(200, {
      url: 'https://billing.stripe.com/p/session/test_123',
    });
    global.fetch = fetchMock;

    const url = await buildClient({ stripeSecretKey: 'sk_test_secret' }).createSession({
      customerId: 'cus_1',
    });

    expect(url).toBe('https://billing.stripe.com/p/session/test_123');
    const [endpoint, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(endpoint).toBe('https://api.stripe.com/v1/billing_portal/sessions');
    const headers = init.headers as Record<string, string>;
    expect(headers['Authorization']).toBe('Bearer sk_test_secret');
    // Pas de clé d'idempotence : chaque ouverture du portail est une session neuve.
    expect(headers).not.toHaveProperty('Idempotency-Key');
    expect(Object.fromEntries(init.body as URLSearchParams)).toEqual({
      customer: 'cus_1',
      return_url: 'https://app.carlys.test/abonnement',
    });
  });

  it('une erreur de Stripe devient un 502 au message neutre', async () => {
    global.fetch = fetchReturning(400, { error: { message: 'No such customer: cus_1' } });

    const attempt = buildClient({ stripeSecretKey: 'sk_test_secret' }).createSession({
      customerId: 'cus_1',
    });
    await expect(attempt).rejects.toBeInstanceOf(BadGatewayException);
    await expect(attempt).rejects.not.toThrow('No such customer');
  });
});
