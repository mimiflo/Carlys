import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { Providers } from '@/app/providers';
import VerifyEmailPage from './page';

let search = new URLSearchParams();

vi.mock('next/navigation', () => ({
  useSearchParams: () => search,
}));

function renderPage() {
  return render(
    <Providers>
      <VerifyEmailPage />
    </Providers>,
  );
}

beforeEach(() => {
  search = new URLSearchParams('token=jeton-123');
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('Page « Vérification de ton adresse e-mail »', () => {
  it('poste le jeton dès l’ouverture et confirme la vérification', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response(null, { status: 204 }));
    vi.stubGlobal('fetch', fetchMock);

    renderPage();

    expect(await screen.findByText(/ton adresse e-mail est vérifiée/i)).toBeInTheDocument();
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toBe('http://localhost:3000/api/v1/auth/verify-email');
    expect(init.method).toBe('POST');
    expect(JSON.parse(init.body as string)).toEqual({ token: 'jeton-123' });
    expect(Object.keys(init.headers as Record<string, string>)).not.toContain('Authorization');
  });

  it('dit que le lien n’est plus valable sur un 401, sans réessayer', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({ error: { message: 'Lien de vérification invalide ou expiré.' } }),
        {
          status: 401,
          headers: { 'Content-Type': 'application/json' },
        },
      ),
    );
    vi.stubGlobal('fetch', fetchMock);

    renderPage();

    const alert = await screen.findByRole('alert');
    expect(alert).toHaveTextContent(/ce lien n’est plus valable/i);
    expect(alert).toHaveTextContent(/ton adresse est déjà vérifiée/i);
    // Rien ne permet de redemander un e-mail de vérification : la page ne doit pas le promettre.
    expect(alert).not.toHaveTextContent(/nouvel e-mail/i);
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(screen.queryByRole('button', { name: /réessayer/i })).toBeNull();
  });

  it('propose de réessayer quand le serveur est injoignable', async () => {
    const fetchMock = vi
      .fn()
      .mockRejectedValueOnce(new TypeError('Failed to fetch'))
      .mockResolvedValueOnce(new Response(null, { status: 204 }));
    vi.stubGlobal('fetch', fetchMock);

    renderPage();

    expect(await screen.findByRole('alert')).toHaveTextContent(/impossible de joindre le serveur/i);
    fireEvent.click(screen.getByRole('button', { name: /réessayer/i }));

    await waitFor(() => {
      expect(screen.getByText(/ton adresse e-mail est vérifiée/i)).toBeInTheDocument();
    });
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('sans jeton dans l’URL, explique et n’appelle pas le serveur', () => {
    search = new URLSearchParams();
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);

    renderPage();

    const alert = screen.getByRole('alert');
    expect(alert).toHaveTextContent(/ce lien est incomplet/i);
    expect(alert).toHaveTextContent(/clique de nouveau sur son lien/i);
    expect(alert).not.toHaveTextContent(/nouvel e-mail/i);
    expect(fetchMock).not.toHaveBeenCalled();
  });
});
