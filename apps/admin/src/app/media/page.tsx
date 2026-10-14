'use client';

import type { AdminMediaAsset, MediaKind } from '@carlys/api-contracts';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { AdminShell } from '@/components/admin-shell';
import { MediaSheet } from '@/components/media-sheet';
import { MediaUploader } from '@/components/media-uploader';
import { Badge } from '@/components/ui/badge';
import { ImageIcon } from '@/components/ui/icons';
import { Segmented } from '@/components/ui/segmented';
import { EmptyState, ErrorState, SkeletonRows } from '@/components/ui/states';
import { useAdminPermissions } from '@/components/use-admin-permissions';
import { adminApi } from '@/lib/admin-api';
import { formatBytes } from '@/lib/format-bytes';
import { unavailableMessage } from '@/lib/load-error';

const KINDS: readonly { value: MediaKind | 'ALL'; label: string }[] = [
  { value: 'ALL', label: 'Tous' },
  { value: 'IMAGE', label: 'Images' },
  { value: 'MESH_3D', label: '3D' },
  { value: 'VIDEO', label: 'Vidéos' },
];

function MediaCard({ asset, onOpen }: { asset: AdminMediaAsset; onOpen: () => void }) {
  const used = asset.usedBy.length;
  return (
    <li className="animate-enter">
      <button
        type="button"
        onClick={onOpen}
        aria-label={`Ouvrir ${asset.originalName}`}
        className="group block w-full overflow-hidden rounded-xl border border-border bg-surface text-left transition duration-250 hover:border-primary/30 hover:shadow-md focus-visible:outline-2 focus-visible:outline-primary"
      >
        <div className="flex aspect-video items-center justify-center overflow-hidden bg-surface-alt">
          {asset.kind === 'IMAGE' ? (
            // Aperçu sans composant d'image optimisée : les médias viennent du
            // stockage objet, dont le domaine varie par environnement. Chargé
            // à l'approche de l'écran : la liste en montre jusqu'à 200, en
            // taille d'origine.
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={asset.url}
              alt={asset.originalName}
              loading="lazy"
              decoding="async"
              className="h-full w-full object-cover transition-transform duration-400 ease-out group-hover:scale-[1.03]"
            />
          ) : (
            <span className="flex flex-col items-center gap-2 text-xs font-medium text-muted">
              <span className="flex h-10 w-10 items-center justify-center rounded-full bg-primary/10 text-primary-ink">
                <ImageIcon />
              </span>
              {asset.kind === 'MESH_3D' ? 'Maillage 3D' : 'Vidéo'}
            </span>
          )}
        </div>
        <div className="flex items-start justify-between gap-2 p-3">
          <span className="min-w-0">
            <span className="block truncate text-sm font-medium">{asset.originalName}</span>
            <span className="tabular-nums block text-xs text-muted">
              {formatBytes(asset.byteSize)}
              {asset.width !== null && asset.height !== null && ` · ${asset.width}×${asset.height}`}
            </span>
          </span>
          <Badge
            status={
              used > 0
                ? { label: `${used} exercice${used > 1 ? 's' : ''}`, tone: 'primary' }
                : { label: 'Libre', tone: 'neutral' }
            }
          />
        </div>
      </button>
    </li>
  );
}

/**
 * Bibliothèque de médias : on dépose, on parcourt, on ouvre une fiche pour
 * voir où sert un fichier et le supprimer s'il ne sert plus.
 */
export default function MediaPage() {
  const queryClient = useQueryClient();
  const canWrite = useAdminPermissions().includes('media:write');
  const [kind, setKind] = useState<MediaKind | 'ALL'>('ALL');
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const { data, isPending, error, refetch } = useQuery({
    queryKey: ['admin', 'media', kind],
    queryFn: () => adminApi.listMedia(kind === 'ALL' ? undefined : kind),
  });

  const remove = useMutation({
    mutationFn: (id: string) => adminApi.deleteMedia(id),
    onSuccess: async () => {
      setSelectedId(null);
      await queryClient.invalidateQueries({ queryKey: ['admin', 'media'] });
    },
  });

  const selected = data?.find((asset) => asset.id === selectedId);
  const free = data?.filter((asset) => asset.usedBy.length === 0).length ?? 0;

  return (
    <AdminShell
      title="Bibliothèque de médias"
      description={
        data === undefined
          ? 'Les fichiers servis aux applications.'
          : `${data.length} fichier${data.length > 1 ? 's' : ''}, dont ${free} libre${free > 1 ? 's' : ''} (montré${free > 1 ? 's' : ''} par aucun exercice).`
      }
    >
      {canWrite && (
        <div className="mb-6">
          <MediaUploader />
        </div>
      )}

      <div className="max-w-md">
        <Segmented legend="Genre" name="kind" options={KINDS} value={kind} onChange={setKind} />
      </div>

      <div className="mt-6 flex flex-col gap-4">
        {error !== null && (
          <ErrorState onRetry={() => void refetch()}>
            {unavailableMessage(error, 'Bibliothèque indisponible', 'media:read')}
          </ErrorState>
        )}
        {isPending && <SkeletonRows rows={3} />}
        {data?.length === 0 && (
          <EmptyState icon={<ImageIcon />}>
            Aucun média de ce genre. Dépose un fichier ci-dessus, ou depuis la fiche d’un exercice.
          </EmptyState>
        )}
      </div>

      <ul className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
        {data?.map((asset) => (
          <MediaCard key={asset.id} asset={asset} onOpen={() => setSelectedId(asset.id)} />
        ))}
      </ul>

      {selected !== undefined && (
        <MediaSheet
          asset={selected}
          canWrite={canWrite}
          isDeleting={remove.isPending}
          deleteFailed={remove.error}
          onDelete={() => remove.mutate(selected.id)}
          onClose={() => {
            remove.reset();
            setSelectedId(null);
          }}
        />
      )}
    </AdminShell>
  );
}
