import { BadGatewayException, ServiceUnavailableException } from '@nestjs/common';
import { type AppConfigService } from '../../../config/app-config.service';
import { type CheckoutRequest, StripeCheckoutClient } from './stripe-checkout.client';

const REQUEST: CheckoutRequest = {
  userId: 'utilisateur-1',
  priceId: 'price_mensuel',
  trialDays: 7,
  idempotencyKey: 'appareil-1',
};

function buildClient(config: { stripeSecretKey?: string }): StripeCheckoutClient {
  return new StripeCheckoutClient({
    publicAppUrl: 'https://app.carlys.test',
    ...config,
  } as unknown as AppConfigService);
}

/** Un `fetch` qui répond ce qu'on lui dit et se souvient de ce qu'on lui a envoyé. */
function fetchReturning(status: number, payload: unknown): jest.Mock {
  return jest
    .fn()
    .mockResolvedValue({ ok: status < 400, status, json: () => Promise.resolve(payload) });
}

function sentForm(fetchMock: jest.Mock): {
  endpoint: string;
  headers: Record<string, string>;
  fields: Record<string, string>;
} {
  const [endpoint, init] = fetchMock.mock.calls[0] as [string, RequestInit];
  return {
    endpoint,
    headers: init.headers as Record<string, string>,
    fields: Object.fromEntries(init.body as URLSearchParams),
  };
}

describe('StripeCheckoutClient', () => {
  const originalFetch = global.fetch;
  afterEach(() => {
    global.fetch = originalFetch;
  });

  it('sans clé secrète, le paiement se déclare non configuré (503) sans appel réseau', async () => {
    const fetchMock = fetchReturning(200, {});
    global.fetch = fetchMock;
    const client = buildClient({});

    expect(client.isConfigured).toBe(false);
    await expect(client.createSession(REQUEST)).rejects.toBeInstanceOf(ServiceUnavailableException);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('poste le formulaire attendu par Stripe, signé par la clé et l’identifiant de l’appareil', async () => {
    const fetchMock = fetchReturning(200, { url: 'https://checkout.stripe.com/c/pay/cs_test' });
    global.fetch = fetchMock;

    const url = await buildClient({ stripeSecretKey: 'sk_test_secret' }).createSession(REQUEST);

    expect(url).toBe('https://checkout.stripe.com/c/pay/cs_test');
    const { endpoint, headers, fields } = sentForm(fetchMock);
    expect(endpoint).toBe('https://api.stripe.com/v1/checkout/sessions');
    expect(headers['Authorization']).toBe('Bearer sk_test_secret');
    expect(headers['Idempotency-Key']).toBe('appareil-1');
    expect(fields).toMatchObject({
      mode: 'subscription',
      'line_items[0][price]': 'price_mensuel',
      'line_items[0][quantity]': '1',
      client_reference_id: 'utilisateur-1',
      'metadata[userId]': 'utilisateur-1',
      'subscription_data[metadata][userId]': 'utilisateur-1',
      'subscription_data[trial_period_days]': '7',
    });
  });

  it('les adresses de retour sont les pages RÉELLES de l’application web, jamais un schéma mobile', async () => {
    // `${PUBLIC_APP_URL}/abonnement/merci` et `${PUBLIC_APP_URL}/abonnement`
    // sont servies par apps/admin (groupe de routes `(public)`) : elles
    // invitent à revenir dans l'application et n'accordent aucun droit. Une
    // adresse qui changerait ici casserait le retour de paiement en silence.
    const fetchMock = fetchReturning(200, { url: 'https://checkout.stripe.com/c/pay/cs_test' });
    global.fetch = fetchMock;

    await buildClient({ stripeSecretKey: 'sk_test_secret' }).createSession(REQUEST);

    expect(sentForm(fetchMock).fields).toMatchObject({
      success_url: 'https://app.carlys.test/abonnement/merci',
      cancel_url: 'https://app.carlys.test/abonnement',
    });
  });

  it('un client Stripe connu est passé à la session ; sinon aucun champ `customer`', async () => {
    const fetchMock = fetchReturning(200, { url: 'https://checkout.stripe.com/c/pay/cs_test' });
    global.fetch = fetchMock;
    const client = buildClient({ stripeSecretKey: 'sk_test_secret' });

    await client.createSession(REQUEST);
    expect(sentForm(fetchMock).fields).not.toHaveProperty('customer');

    fetchMock.mockClear();
    await client.createSession({ ...REQUEST, customerId: 'cus_connu' });
    expect(sentForm(fetchMock).fields).toMatchObject({ customer: 'cus_connu' });
  });

  it('sans période d’essai, aucun champ d’essai n’est envoyé', async () => {
    const fetchMock = fetchReturning(200, { url: 'https://checkout.stripe.com/c/pay/cs_test' });
    global.fetch = fetchMock;

    await buildClient({ stripeSecretKey: 'sk_test_secret' }).createSession({
      ...REQUEST,
      trialDays: 0,
    });

    expect(sentForm(fetchMock).fields).not.toHaveProperty('subscription_data[trial_period_days]');
  });

  it('une erreur de Stripe devient un 502, sans relayer le message du fournisseur', async () => {
    global.fetch = fetchReturning(400, {
      error: { message: 'No such price: price_mensuel' },
    });

    const attempt = buildClient({ stripeSecretKey: 'sk_test_secret' }).createSession(REQUEST);
    await expect(attempt).rejects.toBeInstanceOf(BadGatewayException);
    await expect(attempt).rejects.not.toThrow('No such price');
  });

  it('une réponse sans adresse de page est un 502 aussi', async () => {
    global.fetch = fetchReturning(200, { id: 'cs_test' });

    await expect(
      buildClient({ stripeSecretKey: 'sk_test_secret' }).createSession(REQUEST),
    ).rejects.toBeInstanceOf(BadGatewayException);
  });
});
