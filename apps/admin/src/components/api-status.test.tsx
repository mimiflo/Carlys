import { render, screen } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { testQueryClient } from '@/testing/fixtures';
import { QueryClientProvider } from '@tanstack/react-query';
import { ApiStatus, uptimeLabel } from './api-status';

/**
 * La page d'accueil est PUBLIQUE. Elle affichait le message brut d'une sonde
 * en panne (« Can't reach database server at `10.20.30.40:5432` ») et, en
 * production, une consigne de développement.
 */

function renderStatus() {
  return render(
    <QueryClientProvider client={testQueryClient()}>
      <ApiStatus />
    </QueryClientProvider>,
  );
}

function sante(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('ApiStatus', () => {
  it('dit « indisponible », jamais le détail interne qu’un serveur enverrait encore', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        sante(
          {
            status: 'error',
            timestamp: '2026-09-25T10:00:00.000Z',
            uptimeSeconds: 12,
            components: {
              database: {
                status: 'down',
                error: "Can't reach database server at `10.20.30.40:5432`",
              },
              redis: { status: 'up', latencyMs: 2 },
            },
          },
          503,
        ),
      ),
    );

    renderStatus();

    // Chaque ligne : le nom du composant ET son statut en toutes lettres.
    const ligne = (nom: string) => screen.getByText(nom).closest('li');
    expect(await screen.findByText('Base de données')).toBeInTheDocument();
    expect(ligne('Base de données')).toHaveTextContent('Indisponible');
    expect(ligne('Cache (Redis)')).toHaveTextContent('En service');
    expect(ligne('API')).toHaveTextContent('Dégradée');
    expect(screen.getByText('Service dégradé')).toBeInTheDocument();
    expect(screen.queryByText(/10\.20\.30\.40/)).not.toBeInTheDocument();
  });

  it('API injoignable : un état lisible, sans consigne de développement', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('Failed to fetch')));

    renderStatus();

    const etat = await screen.findByRole('status');
    expect(etat).toHaveTextContent('API injoignable pour le moment');
    expect(etat).not.toHaveTextContent(/pnpm|docker/);
  });
});

describe('uptimeLabel', () => {
  it('rend une durée lisible', () => {
    expect(uptimeLabel(40 * 60)).toBe('40 min');
    expect(uptimeLabel(5 * 3600 + 12 * 60)).toBe('5 h 12 min');
    expect(uptimeLabel(3 * 86400 + 4 * 3600)).toBe('3 j 4 h');
  });
});
