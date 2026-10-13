'use client';

import { type AdminMediaAsset } from '@carlys/api-contracts';
import { useState } from 'react';
import { ApiError } from '@/lib/admin-api';
import { formatBytes } from '@/lib/format-bytes';
import { Badge } from './ui/badge';
import { button } from './ui/button';
import { PanelSection, SidePanel } from './ui/side-panel';
import { useFocusOnSwap } from './use-focus-on-swap';

const KIND_LABELS: Record<AdminMediaAsset['kind'], string> = {
  IMAGE: 'Image',
  MESH_3D: 'Maillage 3D',
  VIDEO: 'Vidéo',
};

function Preview({ asset }: { asset: AdminMediaAsset }) {
  if (asset.kind === 'IMAGE') {
    return (
      // eslint-disable-next-line @next/next/no-img-element -- source externe (stockage objet)
      <img
        src={asset.url}
        alt={asset.originalName}
        className="max-h-80 w-full rounded-lg bg-surface-alt object-contain ring-1 ring-border"
      />
    );
  }
  if (asset.kind === 'VIDEO') {
    return (
      <video
        src={asset.url}
        controls
        preload="metadata"
        className="max-h-80 w-full rounded-lg bg-surface-alt ring-1 ring-border"
      />
    );
  }
  return (
    <p className="rounded-lg bg-surface-alt px-4 py-10 text-center text-sm text-muted ring-1 ring-border">
      Maillage 3D : l’aperçu se voit dans l’application.
    </p>
  );
}

function Fact({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex justify-between gap-4 py-2 text-sm">
      <dt className="text-muted">{label}</dt>
      <dd className="tabular text-right font-medium">{children}</dd>
    </div>
  );
}

/**
 * La fiche d'un média : l'aperçu, ce qu'il est, où il sert, et sa
 * suppression — refusée tant qu'un exercice le montre (le serveur le refuse
 * aussi : une photo ne disparaît pas des applications sans décision).
 */
export function MediaSheet({
  asset,
  canWrite,
  isDeleting,
  deleteFailed,
  onDelete,
  onClose,
}: {
  asset: AdminMediaAsset;
  canWrite: boolean;
  isDeleting: boolean;
  deleteFailed: unknown;
  onDelete: () => void;
  onClose: () => void;
}) {
  const [confirming, setConfirming] = useState(false);
  const [copied, setCopied] = useState(false);
  // « Supprimer » devient « Confirmer / Annuler » : le focus va à
  // « Annuler » (jamais au geste destructeur), puis revient à « Supprimer ».
  const { target: focusTarget, request: requestFocus } = useFocusOnSwap();
  const used = asset.usedBy.length > 0;

  return (
    <SidePanel
      title={asset.originalName}
      subtitle={
        <span className="flex items-center gap-2">
          {KIND_LABELS[asset.kind]}
          <Badge
            status={
              used
                ? { label: `Utilisé (${asset.usedBy.length})`, tone: 'primary' }
                : { label: 'Libre', tone: 'neutral' }
            }
          />
        </span>
      }
      onClose={onClose}
    >
      <Preview asset={asset} />

      <PanelSection title="Détails">
        <dl className="divide-y divide-border">
          <Fact label="Poids">{formatBytes(asset.byteSize)}</Fact>
          {asset.width !== null && asset.height !== null && (
            <Fact label="Dimensions">
              {asset.width}×{asset.height}
            </Fact>
          )}
          <Fact label="Type">{asset.mimeType}</Fact>
          <Fact label="Déposé le">{new Date(asset.createdAt).toLocaleString('fr-FR')}</Fact>
        </dl>
        <div className="mt-3 flex items-center gap-2">
          <code className="min-w-0 flex-1 truncate rounded-md bg-surface-alt px-2 py-1.5 text-xs">
            {asset.url}
          </code>
          <button
            type="button"
            onClick={() => {
              void navigator.clipboard?.writeText(asset.url).then(() => {
                setCopied(true);
                window.setTimeout(() => setCopied(false), 2000);
              });
            }}
            className={button('secondary', 'sm')}
          >
            {copied ? 'Copiée' : 'Copier l’URL'}
          </button>
        </div>
      </PanelSection>

      <PanelSection title="Utilisé par">
        {used ? (
          <ul className="flex flex-col gap-1.5 text-sm">
            {asset.usedBy.map((usage) => (
              <li key={usage.id} className="rounded-md bg-surface-alt px-3 py-2">
                {usage.name}
              </li>
            ))}
          </ul>
        ) : (
          <p className="text-sm text-muted">Aucun exercice ne montre ce fichier.</p>
        )}
      </PanelSection>

      {canWrite && (
        <PanelSection title="Suppression">
          {used ? (
            <p className="text-sm text-muted">
              Détache-le d’abord de ses exercices (page Exercices) : un fichier montré par
              l’application ne se supprime pas.
            </p>
          ) : confirming ? (
            <div className="flex flex-wrap items-center gap-2">
              <button
                type="button"
                onClick={onDelete}
                disabled={isDeleting}
                className={button('danger', 'sm')}
              >
                {isDeleting ? 'Suppression…' : 'Confirmer'}
              </button>
              <button
                ref={focusTarget}
                type="button"
                onClick={() => {
                  requestFocus();
                  setConfirming(false);
                }}
                className={button('ghost', 'sm')}
              >
                Annuler
              </button>
            </div>
          ) : (
            <button
              ref={focusTarget}
              type="button"
              onClick={() => {
                requestFocus();
                setConfirming(true);
              }}
              className={button('danger-outline', 'sm')}
            >
              Supprimer
            </button>
          )}
          {deleteFailed !== null && (
            <p className="mt-2 text-sm text-danger-ink" role="alert">
              {deleteFailed instanceof ApiError && deleteFailed.status === 403
                ? 'Permission manquante pour supprimer un média.'
                : deleteFailed instanceof ApiError && deleteFailed.status === 400
                  ? 'Suppression refusée : un média rattaché à un exercice doit d’abord en être détaché.'
                  : 'Suppression impossible pour le moment, réessaie.'}
            </p>
          )}
        </PanelSection>
      )}
    </SidePanel>
  );
}
