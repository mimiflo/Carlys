import { type AppConfigService } from '../../../config/app-config.service';
import { StripeSubscriptionClient } from './stripe-subscription.client';

function buildClient(stripeSecretKey?: string): StripeSubscriptionClient {
  return new StripeSubscriptionClient({ stripeSecretKey } as unknown as AppConfigService);
}

function fetchReturning(status: number): jest.Mock {
  return jest.fn().mockResolvedValue({ ok: status < 400, status, json: () => Promise.resolve({}) });
}

describe('StripeSubscriptionClient', () => {
  const originalFetch = global.fetch;
  afterEach(() => {
    global.fetch = originalFetch;
  });

  it('résilie TOUT DE SUITE : DELETE signé, sous une clé d’idempotence propre à la tentative', async () => {
    const fetchMock = fetchReturning(200);
    global.fetch = fetchMock;

    await buildClient('sk_test_secret').cancelNow('sub_123', 'req-1');

    const [endpoint, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    const headers = init.headers as Record<string, string>;
    expect(endpoint).toBe('https://api.stripe.com/v1/subscriptions/sub_123');
    expect(init.method).toBe('DELETE');
    expect(headers['Authorization']).toBe('Bearer sk_test_secret');
    expect(headers['Idempotency-Key']).toBe('carlys-resiliation-req-1-sub_123');
    // Un Stripe qui ne répond pas ne doit pas suspendre la suppression.
    expect(init.signal).toBeInstanceOf(AbortSignal);
  });

  it('404 : Stripe ne connaît plus l’abonnement, déjà résilié — c’est un succès', async () => {
    global.fetch = fetchReturning(404);

    await expect(
      buildClient('sk_test_secret').cancelNow('sub_parti', 'req-1'),
    ).resolves.toBeUndefined();
  });

  it.each([500, 503, 401, 400])(
    'HTTP %i : la résiliation n’a pas eu lieu, et le dit',
    async (status) => {
      global.fetch = fetchReturning(status);

      await expect(buildClient('sk_test_secret').cancelNow('sub_123', 'req-1')).rejects.toThrow(
        `HTTP ${status}`,
      );
    },
  );

  it('réseau coupé : l’échec remonte, rien n’est présumé résilié', async () => {
    global.fetch = jest.fn().mockRejectedValue(new TypeError('fetch failed'));

    await expect(buildClient('sk_test_secret').cancelNow('sub_123', 'req-1')).rejects.toThrow(
      'fetch failed',
    );
  });

  it('sans clé : non configuré, aucun appel', async () => {
    const fetchMock = fetchReturning(200);
    global.fetch = fetchMock;
    const client = buildClient(undefined);

    expect(client.isConfigured).toBe(false);
    await expect(client.cancelNow('sub_123', 'req-1')).rejects.toThrow('non configuré');
    expect(fetchMock).not.toHaveBeenCalled();
  });
});
