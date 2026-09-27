import { fireEvent, screen, waitFor } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { MediaAsset } from '@carlys/api-contracts';
import { AdminApiError, adminApi } from '@/lib/admin-api';
import { DEVELOPPE_COUCHE, exercise, inRow, renderWithQuery } from '@/testing/fixtures';
import { ExercisePhotoCell } from './exercise-photo-cell';

/**
 * Photo d'un exercice : dépôt PUIS rattachement, retrait, et un champ fichier
 * qui ne fait pas d'arrêt de tabulation invisible.
 */

const PHOTO: MediaAsset = {
  id: '99999999-2222-4333-8444-555555555555',
  kind: 'IMAGE',
  url: 'https://medias.carlys.test/developpe-couche.webp',
  mimeType: 'image/webp',
  byteSize: 9_216,
  width: 800,
  height: 600,
  originalName: 'developpe-couche.webp',
  createdAt: '2026-09-01T10:00:00.000Z',
};

afterEach(() => {
  vi.restoreAllMocks();
});

function fileInput(container: HTMLElement): HTMLInputElement {
  const input = container.querySelector('input[type="file"]');
  if (!(input instanceof HTMLInputElement)) {
    throw new Error('champ fichier introuvable');
  }
  return input;
}

describe('ExercisePhotoCell', () => {
  // Le champ est `sr-only` et c'est le bouton visible qui l'ouvre : resté
  // focalisable, il faisait un arrêt de tabulation invisible par ligne.
  it('le champ fichier caché sort de l’ordre de tabulation', () => {
    const { container } = renderWithQuery(inRow(<ExercisePhotoCell exercise={DEVELOPPE_COUCHE} />));

    expect(fileInput(container)).toHaveAttribute('tabindex', '-1');
    expect(screen.getByRole('button', { name: 'Ajouter une photo' })).toBeVisible();
  });

  it('dépose le fichier PUIS le rattache à l’exercice', async () => {
    const upload = vi.spyOn(adminApi, 'uploadMedia').mockResolvedValue(PHOTO);
    const attach = vi.spyOn(adminApi, 'setExerciseImage').mockResolvedValue(undefined);
    const { container } = renderWithQuery(inRow(<ExercisePhotoCell exercise={DEVELOPPE_COUCHE} />));
    const file = new File(['png'], 'photo.webp', { type: 'image/webp' });

    fireEvent.change(fileInput(container), { target: { files: [file] } });

    await waitFor(() => expect(attach).toHaveBeenCalledWith(DEVELOPPE_COUCHE.id, PHOTO.id));
    expect(upload).toHaveBeenCalledWith(file, 'IMAGE', expect.any(String));
  });

  it('montre le refus du serveur tel quel', async () => {
    vi.spyOn(adminApi, 'uploadMedia').mockRejectedValue(
      new AdminApiError('Format non accepté.', 415),
    );
    const { container } = renderWithQuery(inRow(<ExercisePhotoCell exercise={DEVELOPPE_COUCHE} />));

    fireEvent.change(fileInput(container), {
      target: { files: [new File(['x'], 'photo.gif', { type: 'image/gif' })] },
    });

    expect(await screen.findByRole('alert')).toHaveTextContent('Format non accepté.');
  });

  it('« Retirer » détache la photo sans la supprimer de la bibliothèque', async () => {
    const attach = vi.spyOn(adminApi, 'setExerciseImage').mockResolvedValue(undefined);
    const remove = vi.spyOn(adminApi, 'deleteMedia');
    renderWithQuery(inRow(<ExercisePhotoCell exercise={exercise({ image: PHOTO })} />));

    fireEvent.click(screen.getByRole('button', { name: 'Retirer' }));

    await waitFor(() => expect(attach).toHaveBeenCalledWith(DEVELOPPE_COUCHE.id, null));
    expect(remove).not.toHaveBeenCalled();
  });

  // Cinquante lignes par page, chacune avec l'original derrière sa vignette.
  it('la vignette ne se charge qu’à l’approche de l’écran, et se décode à part', () => {
    renderWithQuery(inRow(<ExercisePhotoCell exercise={exercise({ image: PHOTO })} />));

    const vignette = screen.getByRole('img', { name: `Photo de ${DEVELOPPE_COUCHE.name}` });

    expect(vignette).toHaveAttribute('loading', 'lazy');
    expect(vignette).toHaveAttribute('decoding', 'async');
  });
});
