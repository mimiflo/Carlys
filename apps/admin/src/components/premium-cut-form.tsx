'use client';

import type { ManagedPaidSubscription } from '@carlys/api-contracts';
import { useId, useState, type FormEvent, type Ref } from 'react';
import { PROVIDER_LABELS } from '@/lib/entitlement-labels';

/** Borne du DTO de l'API (`SetEntitlementDto.reason`). */
const REASON_MAX_LENGTH = 500;

/**
 * Couper l'accès premium : le geste le plus lourd de la fiche, donc une
 * confirmation et une raison OBLIGATOIRE, journalisée dans l'audit.
 *
 * Une coupure survit à tout paiement et bloque les achats. Quand un
 * abonnement payant court, elle n'arrête PAS la facturation : le dire ici,
 * avant le clic, c'est éviter d'encaisser sans rien rendre.
 */
export function PremiumCutForm({
  paid,
  isPending,
  reasonRef,
  onConfirm,
  onCancel,
}: {
  paid: ManagedPaidSubscription | null;
  isPending: boolean;
  /** Reçoit le focus à l'ouverture (voir `useFocusOnSwap`). */
  reasonRef: Ref<HTMLTextAreaElement>;
  onConfirm: (reason: string) => void;
  onCancel: () => void;
}) {
  const [reason, setReason] = useState('');
  const reasonId = useId();
  const trimmed = reason.trim();

  const onSubmit = (event: FormEvent) => {
    event.preventDefault();
    if (trimmed !== '') {
      onConfirm(trimmed);
    }
  };

  return (
    <form
      onSubmit={onSubmit}
      aria-label="Couper l’accès premium"
      className="mt-4 flex flex-col gap-3 rounded-lg p-4 ring-1 ring-danger-strong/40"
    >
      {paid !== null && (
        <p className="text-sm font-semibold text-danger-ink">
          Un abonnement {PROVIDER_LABELS[paid.provider]} est payé en ce moment : couper l’accès
          n’arrête PAS la facturation. Pour l’arrêter ou rembourser, passe par{' '}
          {PROVIDER_LABELS[paid.provider]}.
        </p>
      )}
      <p className="text-sm text-muted">
        Le membre perd tout de suite chaque droit du plan premium, coach IA et programmes illimités
        compris, et en reste privé même s’il paie. Il ne peut plus rien acheter tant que la décision
        n’est pas levée par « Rendre la main à l’abonnement ».
      </p>
      <label htmlFor={reasonId} className="text-sm font-medium">
        Raison (obligatoire, journalisée dans l’audit)
      </label>
      <textarea
        id={reasonId}
        ref={reasonRef}
        value={reason}
        onChange={(event) => setReason(event.target.value)}
        maxLength={REASON_MAX_LENGTH}
        rows={3}
        required
        className="rounded-lg border border-black/10 px-3 py-2 text-sm"
      />
      <div className="flex flex-wrap gap-3">
        <button
          type="submit"
          disabled={trimmed === '' || isPending}
          className="rounded-lg bg-danger-strong px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
        >
          {isPending ? 'Coupure…' : 'Confirmer la coupure'}
        </button>
        <button
          type="button"
          onClick={onCancel}
          className="rounded-lg px-4 py-2 text-sm text-muted hover:bg-black/5"
        >
          Annuler
        </button>
      </div>
    </form>
  );
}
