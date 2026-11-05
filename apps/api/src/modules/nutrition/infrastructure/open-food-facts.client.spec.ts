import {
  OpenFoodFactsClient,
  OpenFoodFactsUnavailable,
  OpenFoodFactsUnreadable,
} from './open-food-facts.client';

describe('OpenFoodFactsClient', () => {
  const code = '3017620422003';
  const client = new OpenFoodFactsClient();
  let reply: () => Response;
  let init: RequestInit | undefined;

  beforeEach(() => {
    jest.spyOn(globalThis, 'fetch').mockImplementation((_input, options) => {
      init = options;
      return Promise.resolve(reply());
    });
  });
  afterEach(() => jest.restoreAllMocks());

  /** Un corps qui ne finit jamais, et qui note s'il a été annulé. */
  function endless(): { stream: ReadableStream<Uint8Array>; cancelled: () => boolean } {
    let cancelled = false;
    const stream = new ReadableStream<Uint8Array>({
      pull: (controller) => controller.enqueue(new Uint8Array(64 * 1024)),
      cancel: () => {
        cancelled = true;
      },
    });
    return { stream, cancelled: () => cancelled };
  }

  it('trouvé : la fiche ; l’application se nomme, sans redirection, avec un délai', async () => {
    reply = () => Response.json({ status: 1, product: { product_name: 'Pâte' } });
    await expect(client.product(code)).resolves.toEqual({ product_name: 'Pâte' });
    expect(new Headers(init?.headers).get('User-Agent')).toMatch(/^Carlys\/\d/);
    expect(init?.redirect).toBe('error');
    expect(init?.signal).toBeInstanceOf(AbortSignal);
  });

  it('inconnu : 404, ou 200 sans fiche (`status` différent de 1)', async () => {
    reply = () => Response.json({ status: 0 }, { status: 404 });
    await expect(client.product(code)).resolves.toBeNull();
    reply = () => Response.json({ status: 0, status_verbose: 'product not found' });
    await expect(client.product(code)).resolves.toBeNull();
  });

  it('429 et 503 : la base est saturée (de quoi faire une pause)', async () => {
    for (const status of [429, 503]) {
      reply = () => new Response('', { status });
      await expect(client.product(code)).rejects.toMatchObject({ saturated: true });
    }
  });

  it('une autre panne (500, 502) : indisponible, sans dire saturé', async () => {
    for (const status of [500, 502]) {
      reply = () => new Response('', { status });
      const failure = client.product(code);
      await expect(failure).rejects.toBeInstanceOf(OpenFoodFactsUnavailable);
      await expect(failure).rejects.toMatchObject({ saturated: false });
    }
  });

  it('trop lourde d’après son en-tête : refusée sans lire le corps', async () => {
    const body = endless();
    reply = () => new Response(body.stream, { headers: { 'content-length': '10000000' } });
    await expect(client.product(code)).rejects.toBeInstanceOf(OpenFoodFactsUnreadable);
    expect(body.cancelled()).toBe(true);
  });

  it('trop lourde en lisant : les OCTETS se comptent, la lecture s’annule', async () => {
    const body = endless();
    reply = () => new Response(body.stream);
    await expect(client.product(code)).rejects.toBeInstanceOf(OpenFoodFactsUnreadable);
    expect(body.cancelled()).toBe(true);
  });

  it('un corps qui n’est pas du JSON objet : inexploitable', async () => {
    for (const text of ['{tronqué', '[1, 2]', 'null']) {
      reply = () => new Response(text);
      await expect(client.product(code)).rejects.toBeInstanceOf(OpenFoodFactsUnreadable);
    }
  });
});
