import { adminExerciseSummarySchema } from '@carlys/api-contracts';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { adminApi, adminToken, parsePage } from './admin-api';

const MEDIA = {
  id: '11111111-2222-4333-8444-555555555555',
  kind: 'IMAGE',
  url: 'http://storage.test/carlys-media/image/11111111-2222-4333-8444-555555555555.webp',
  mimeType: 'image/webp',
  byteSize: 1234,
  width: 800,
  height: 800,
  originalName: 'squat.webp',
  createdAt: '2026-08-09T10:00:00.000Z',
};

function respond(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

afterEach(() => {
  vi.unstubAllGlobals();
  adminToken.clear();
});

describe('dépôt de média', () => {
  it('n’impose PAS de Content-Type : le navigateur écrit la frontière multipart', async () => {
    // C'est le piège du transport multipart : poser `application/json` à la
    // main — ce que fait le transport JSON du client — prive la requête de sa
    // frontière et le serveur ne décode plus rien.
    const fetchMock = vi.fn().mockResolvedValue(respond({ data: MEDIA }));
    vi.stubGlobal('fetch', fetchMock);

    await adminApi.uploadMedia(
      new File([new Uint8Array([1, 2, 3])], 'squat.webp', { type: 'image/webp' }),
      'IMAGE',
      MEDIA.id,
    );

    const [, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    const headers = (init.headers ?? {}) as Record<string, string>;
    expect(Object.keys(headers)).not.toContain('Content-Type');
    expect(init.body).toBeInstanceOf(FormData);
  });

  it('envoie l’identifiant fourni par l’admin — c’est ce qui rend le dépôt rejouable', async () => {
    const fetchMock = vi.fn().mockResolvedValue(respond({ data: MEDIA }));
    vi.stubGlobal('fetch', fetchMock);

    await adminApi.uploadMedia(
      new File([new Uint8Array([1])], 'squat.webp', { type: 'image/webp' }),
      'IMAGE',
      MEDIA.id,
    );

    const form = (vi.mocked(fetchMock).mock.calls[0]?.[1] as RequestInit).body as FormData;
    expect(form.get('id')).toBe(MEDIA.id);
    expect(form.get('kind')).toBe('IMAGE');
    expect(form.get('file')).toBeInstanceOf(File);
  });

  it('un refus du serveur remonte son message, jamais un succès silencieux', async () => {
    vi.stubGlobal(
      'fetch',
      vi
        .fn()
        .mockResolvedValue(
          respond({ error: { message: 'Type « image/gif » refusé pour un média IMAGE.' } }, 415),
        ),
    );

    await expect(
      adminApi.uploadMedia(
        new File([new Uint8Array([1])], 'a.gif', { type: 'image/gif' }),
        'IMAGE',
        MEDIA.id,
      ),
    ).rejects.toThrow('refusé');
  });
});

describe('catalogue d’administration', () => {
  it('accepte un exercice non publié et sans photo — c’est le cas normal ici', () => {
    const page = parsePage(
      {
        data: [
          {
            id: 'ex-1',
            slug: 'squat',
            name: 'Squat',
            isPublished: false,
            isPremium: false,
            primaryMuscleGroupName: null,
            image: null,
            mesh: null,
          },
        ],
      },
      adminExerciseSummarySchema,
    );

    expect(page.items[0]?.isPublished).toBe(false);
    expect(page.items[0]?.image).toBeNull();
  });

  it('porte le média entier quand une photo est rattachée', () => {
    const page = parsePage(
      {
        data: [
          {
            id: 'ex-1',
            slug: 'squat',
            name: 'Squat',
            isPublished: true,
            isPremium: false,
            primaryMuscleGroupName: 'Quadriceps',
            image: MEDIA,
            mesh: null,
          },
        ],
      },
      adminExerciseSummarySchema,
    );

    // Le nom du fichier est ce qui permet de dire QUELLE photo est en place.
    expect(page.items[0]?.image?.originalName).toBe('squat.webp');
    expect(page.items[0]?.image?.url).toContain(MEDIA.id);
  });
});
