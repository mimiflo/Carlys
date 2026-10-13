'use client';

import { useQueryClient } from '@tanstack/react-query';
import { useRef, useState, type DragEvent } from 'react';
import { ApiError, adminApi } from '@/lib/admin-api';
import { MEDIA_ACCEPT, mediaKindOf, withServerType } from '@/lib/media-kind';
import { button } from './ui/button';
import { UploadIcon } from './ui/icons';

type Line = { name: string; state: 'waiting' | 'done' | 'failed'; message?: string };

/**
 * Le dépôt de fichiers de la bibliothèque : glisser-déposer ou parcourir,
 * plusieurs fichiers d'un coup, déposés UN PAR UN (le serveur lit chaque
 * fichier en mémoire : vingt vidéos en parallèle l'étoufferaient). Chaque
 * fichier dit où il en est ; un refus se lit sur sa ligne, il n'arrête pas
 * les suivants.
 */
export function MediaUploader() {
  const queryClient = useQueryClient();
  const input = useRef<HTMLInputElement>(null);
  const [over, setOver] = useState(false);
  const [lines, setLines] = useState<Line[]>([]);
  // Un seul lot à la fois : un second dépôt pendant l'envoi est refusé
  // (sinon deux boucles écriraient leurs états dans la même liste).
  const [busy, setBusy] = useState(false);

  const send = async (files: File[]) => {
    if (busy) return;
    setBusy(true);
    setLines(files.map((file) => ({ name: file.name, state: 'waiting' })));
    for (const [index, file] of files.entries()) {
      const kind = mediaKindOf(file);
      let line: Line;
      if (kind === null) {
        line = { name: file.name, state: 'failed', message: 'type de fichier refusé' };
      } else {
        try {
          await adminApi.uploadMedia(withServerType(file), kind, crypto.randomUUID());
          line = { name: file.name, state: 'done' };
        } catch (cause) {
          line = {
            name: file.name,
            state: 'failed',
            message: cause instanceof ApiError ? cause.message : 'dépôt impossible',
          };
        }
      }
      setLines((current) => current.map((item, i) => (i === index ? line : item)));
    }
    setBusy(false);
    await queryClient.invalidateQueries({ queryKey: ['admin', 'media'] });
  };

  const onDrop = (event: DragEvent) => {
    event.preventDefault();
    setOver(false);
    void send([...event.dataTransfer.files]);
  };

  return (
    <div>
      <div
        onDragOver={(event) => {
          event.preventDefault();
          setOver(true);
        }}
        onDragLeave={(event) => {
          // Quitter un ENFANT de la zone n'est pas la quitter.
          if (!event.currentTarget.contains(event.relatedTarget as Node | null)) setOver(false);
        }}
        onDrop={onDrop}
        className={`flex flex-col items-center gap-3 rounded-xl border-2 border-dashed px-6 py-8 text-center transition-colors duration-150 ${
          over ? 'border-primary bg-primary/5' : 'border-border bg-surface'
        }`}
      >
        <span className="flex h-11 w-11 items-center justify-center rounded-full bg-primary/10 text-primary-ink">
          <UploadIcon />
        </span>
        <p className="text-sm">
          <span className="font-medium">Glisse tes fichiers ici</span>
          <span className="text-muted"> — images, vidéos ou maillages 3D (.glb)</span>
        </p>
        <input
          ref={input}
          type="file"
          multiple
          accept={MEDIA_ACCEPT}
          className="sr-only"
          tabIndex={-1}
          aria-hidden
          onChange={(event) => {
            const files = [...(event.target.files ?? [])];
            event.target.value = '';
            if (files.length > 0) void send(files);
          }}
        />
        <button
          type="button"
          onClick={() => input.current?.click()}
          disabled={busy}
          className={button('secondary', 'sm')}
        >
          {busy ? 'Dépôt en cours…' : 'Parcourir…'}
        </button>
      </div>
      {lines.length > 0 && (
        <ul className="mt-3 flex flex-col gap-1 text-sm" aria-live="polite">
          {lines.map((line, index) => (
            <li key={`${line.name}-${index}`} className="flex items-center justify-between gap-3">
              <span className="truncate">{line.name}</span>
              <span
                className={
                  line.state === 'failed' ? 'shrink-0 text-danger-ink' : 'shrink-0 text-muted'
                }
              >
                {line.state === 'waiting' && 'en cours…'}
                {line.state === 'done' && 'déposé'}
                {line.state === 'failed' && `refusé : ${line.message ?? ''}`}
              </span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
