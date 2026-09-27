/**
 * Stripe simulé à sa FRONTIÈRE RÉSEAU, et là seulement : tout `fetch` vers
 * `https://api.stripe.com/` est retenu et répondu ici, le reste part tel quel.
 *
 * Une suite qui touche à un abonnement Stripe (suppression de compte,
 * webhooks) l'installe dans son `beforeAll`, avec une clé Stripe posée en
 * tête de fichier. Sans elle, la suite dépendait de l'ABSENCE de clé : le
 * `.env` que `scripts/setup.sh` copie en porte une, et la suppression
 * appelait alors le vrai Stripe, qui la refusait (503).
 *
 * `jest.restoreAllMocks()` dans l'`afterAll` de la suite la retire.
 */
export interface StripeSimule {
  /** Statut HTTP rendu à chaque appel (200 par défaut). */
  statut: number;
  /** Ce qu'on a demandé à Stripe, dans l'ordre : « MÉTHODE url ». */
  readonly appels: string[];
  /** Entre deux tests : 200, et aucun appel retenu. */
  reinitialiser(): void;
}

export function simulerStripe(): StripeSimule {
  const stripe: StripeSimule = {
    statut: 200,
    appels: [],
    reinitialiser() {
      stripe.statut = 200;
      stripe.appels.length = 0;
    },
  };
  const fetchReel = global.fetch;
  jest.spyOn(global, 'fetch').mockImplementation((input, init) => {
    const url = input instanceof Request ? input.url : String(input);
    if (!url.startsWith('https://api.stripe.com/')) {
      return fetchReel(input, init);
    }
    stripe.appels.push(`${init?.method ?? 'GET'} ${url}`);
    return Promise.resolve(new Response('{}', { status: stripe.statut }));
  });
  return stripe;
}
