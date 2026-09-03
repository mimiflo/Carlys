import { fireEvent, render, screen } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { Providers } from '@/app/providers';
import ResetPasswordPage from './page';

let search = new URLSearchParams();

// La page lit `?token` dans l'URL : hors de Next, on la lui fournit.
vi.mock('next/navigation', () => ({
  useSearchParams: () => search,
}));

function respond(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function renderPage() {
  return render(
    <Providers>
      <ResetPasswordPage />
    </Providers>,
  );
}

function fillAndSubmit(password: string, confirmation = password) {
  fireEvent.change(screen.getByLabelText(/^nouveau mot de passe/i), {
    target: { value: password },
  });
  fireEvent.change(screen.getByLabelText(/confirme le mot de passe/i), {
    target: { value: confirmation },
  });
  fireEvent.click(screen.getByRole('button', { name: /changer mon mot de passe/i }));
}

beforeEach(() => {
  search = new URLSearchParams('token=jeton-123');
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('Page « Nouveau mot de passe »', () => {
  it('envoie le jeton de l’URL et le nouveau mot de passe, puis confirme', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response(null, { status: 204 }));
    vi.stubGlobal('fetch', fetchMock);

    renderPage();
    fillAndSubmit('motdepasse-solide');

    expect(await screen.findByRole('status')).toHaveTextContent(
      'Ton mot de passe est changé, tu peux te connecter dans l’application.',
    );
    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toBe('http://localhost:3000/api/v1/auth/reset-password');
    expect(init.method).toBe('POST');
    expect(JSON.parse(init.body as string)).toEqual({
      token: 'jeton-123',
      newPassword: 'motdepasse-solide',
    });
    expect(Object.keys(init.headers as Record<string, string>)).not.toContain('Authorization');
    expect(screen.queryByRole('button', { name: /changer mon mot de passe/i })).toBeNull();
  });

  it('refuse deux mots de passe différents sans appeler le serveur', () => {
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);

    renderPage();
    fillAndSubmit('motdepasse-solide', 'motdepasse-autre');

    expect(screen.getByRole('alert')).toHaveTextContent(
      'Les deux mots de passe ne sont pas identiques.',
    );
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('refuse un mot de passe trop court sans appeler le serveur', () => {
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);

    renderPage();
    fillAndSubmit('court');

    expect(screen.getByRole('alert')).toHaveTextContent('au moins 10 caractères');
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('dit que le lien est expiré ou invalide sur un 401', async () => {
    vi.stubGlobal(
      'fetch',
      vi
        .fn()
        .mockResolvedValue(
          respond({ error: { message: 'Lien de réinitialisation invalide ou expiré.' } }, 401),
        ),
    );

    renderPage();
    fillAndSubmit('motdepasse-solide');

    expect(await screen.findByRole('alert')).toHaveTextContent(
      /lien est expiré ou n’est plus valable/i,
    );
  });

  it('parle de connexion quand le serveur est injoignable', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('Failed to fetch')));

    renderPage();
    fillAndSubmit('motdepasse-solide');

    expect(await screen.findByRole('alert')).toHaveTextContent(/impossible de joindre le serveur/i);
  });

  it('sans jeton dans l’URL, explique et ne montre pas de formulaire', () => {
    search = new URLSearchParams();
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);

    renderPage();

    expect(screen.getByRole('alert')).toHaveTextContent(/ce lien est incomplet/i);
    expect(screen.queryByRole('button', { name: /changer mon mot de passe/i })).toBeNull();
    expect(fetchMock).not.toHaveBeenCalled();
  });
});
