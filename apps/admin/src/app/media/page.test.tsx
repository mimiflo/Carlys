import type { AdminMediaAsset } from '@carlys/api-contracts';
import { ADMIN_PERMISSIONS } from '@carlys/api-contracts';
import { fireEvent, screen } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { adminApi, adminPermissions, adminToken } from '@/lib/admin-api';
import { renderWithQuery } from '@/testing/fixtures';
import MediaPage, { formatBytes } from './page';

vi.mock('next/navigation', () => ({
  usePathname: () => '/media',
  useRouter: () => ({ replace: vi.fn(), push: vi.fn() }),
}));

const PHOTO: AdminMediaAsset = {
  id: '11111111-2222-4333-8444-555555555555',
  kind: 'IMAGE',
  url: 'https://medias.carlys.test/developpe-couche.webp',
  mimeType: 'image/webp',
  byteSize: 9_216,
  width: 800,
  height: 600,
  originalName: 'developpe-couche.webp',
  createdAt: '2026-09-01T10:00:00.000Z',
  usedBy: [],
};

afterEach(() => {
  vi.restoreAllMocks();
  adminToken.clear();
});

function renderPage() {
  adminToken.set('jeton-admin');
  adminPermissions.set(ADMIN_PERMISSIONS);
  return renderWithQuery(<MediaPage />);
}

/**
 * « Supprimer » devient « Confirmer / Annuler » : le bouton activé était
 * démonté et le focus retombait sur <body>.
 */
describe('Bibliothèque de médias — focus clavier', () => {
  it('« Supprimer » pose le focus sur « Annuler », « Annuler » le rend à « Supprimer »', async () => {
    vi.spyOn(adminApi, 'listMedia').mockResolvedValue([PHOTO]);
    renderPage();
    fireEvent.click(await screen.findByRole('button', { name: `Ouvrir ${PHOTO.originalName}` }));
    const supprimer = screen.getByRole('button', { name: 'Supprimer' });
    supprimer.focus();

    fireEvent.click(supprimer);
    expect(screen.getByRole('button', { name: 'Annuler' })).toHaveFocus();

    fireEvent.click(screen.getByRole('button', { name: 'Annuler' }));
    expect(screen.getByRole('button', { name: 'Supprimer' })).toHaveFocus();
  });
});

/**
 * La liste montre jusqu'à 200 médias en taille d'origine : chargés d'un coup,
 * ils rapatriaient toute la bibliothèque à l'ouverture de la page.
 */
describe('Bibliothèque de médias — images différées', () => {
  it('un aperçu ne se charge qu’à l’approche de l’écran, et se décode à part', async () => {
    vi.spyOn(adminApi, 'listMedia').mockResolvedValue([PHOTO]);
    renderPage();

    const apercu = await screen.findByRole('img', { name: PHOTO.originalName });

    expect(apercu).toHaveAttribute('loading', 'lazy');
    expect(apercu).toHaveAttribute('decoding', 'async');
  });
});

/**
 * Le poids d'un média se lit d'un coup d'œil ou ne sert à rien : personne ne
 * compare « 3 145 728 » à « 524 288 » sans compter les chiffres.
 */
describe('formatBytes', () => {
  it('garde les octets tant qu’ils se lisent', () => {
    expect(formatBytes(512)).toBe('512 o');
  });

  it('passe aux kilo-octets sans décimale : elle n’apprend rien', () => {
    expect(formatBytes(2048)).toBe('2 Ko');
    expect(formatBytes(1024 * 900)).toBe('900 Ko');
  });

  it('passe aux méga-octets avec UNE décimale, virgule française', () => {
    expect(formatBytes(1024 * 1024 * 3.5)).toBe('3,5 Mo');
  });
});

describe('MediaPage — fiche et dépôt', () => {
  it('un fichier montré par un exercice ne propose pas sa suppression, et dit pourquoi', async () => {
    vi.spyOn(adminApi, 'listMedia').mockResolvedValue([
      { ...PHOTO, usedBy: [{ id: 'e1', name: 'Développé couché' }] },
    ]);
    renderPage();
    fireEvent.click(await screen.findByRole('button', { name: `Ouvrir ${PHOTO.originalName}` }));

    expect(screen.getByRole('dialog')).toHaveTextContent('Développé couché');
    expect(screen.queryByRole('button', { name: 'Supprimer' })).not.toBeInTheDocument();
    expect(screen.getByText(/Détache-le d’abord/)).toBeInTheDocument();
  });

  it('un fichier déposé part avec le genre lu dans son type', async () => {
    vi.spyOn(adminApi, 'listMedia').mockResolvedValue([]);
    const upload = vi.spyOn(adminApi, 'uploadMedia').mockResolvedValue(PHOTO);
    renderPage();
    await screen.findByText(/Aucun média de ce genre/);

    const fichier = new File(['x'], 'squat.mp4', { type: 'video/mp4' });
    fireEvent.drop(screen.getByText('Glisse tes fichiers ici'), {
      dataTransfer: { files: [fichier] },
    });

    expect(await screen.findByText('déposé')).toBeInTheDocument();
    expect(upload).toHaveBeenCalledWith(fichier, 'VIDEO', expect.any(String));
  });
});
