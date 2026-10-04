'use client';

import {
  PREMIUM_ENTITLEMENT_KEYS,
  type ManagedEntitlement,
  type ManagedUserDetail,
} from '@carlys/api-contracts';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { ApiError, adminApi } from '@/lib/admin-api';
import { paidSubscriptionSentence, premiumStateSentence } from '@/lib/entitlement-labels';
import { PremiumCutForm } from './premium-cut-form';
import { useAdminPermissions } from './use-admin-permissions';
import { useFocusOnSwap } from './use-focus-on-swap';

/** Les droits du plan premium : c'est eux, ensemble, que « premium » désigne. */
function premiumOf(user: ManagedUserDetail): ManagedEntitlement[] {
  return user.entitlements.filter((entitlement) =>
    PREMIUM_ENTITLEMENT_KEYS.includes(entitlement.key),
  );
}

/** L'état que le panneau annonce : chaque droit du plan, ouvert ou fermé, et par qui. */
function premiumStateKey(premium: readonly ManagedEntitlement[]): string {
  return premium
    .map((entitlement) => `${String(entitlement.isActive)}:${entitlement.source}`)
    .join();
}

const MIXED_SENTENCE =
  'Les droits du plan premium n’ont pas tous le même état : le détail est dans la liste des droits. Chaque geste ci-dessous s’applique à tous.';

const SECONDARY_BUTTON =
  'rounded-lg border border-primary px-4 py-2 text-sm font-semibold text-primary-ink hover:bg-primary hover:text-white disabled:opacity-50';

/**
 * L'accès premium d'un membre : d'où il vient, et trois gestes DISTINCTS.
 *
 * Il n'y avait qu'un bouton, libellé d'après `isPremium` seul : « Retirer le
 * premium manuel » s'affichait aussi pour un abonné Stripe. Un clic posait
 * une coupure manuelle qui survit à tout paiement et bloque les achats :
 * l'abonnement restait facturé, l'accès perdu, et aucun geste ne rendait la
 * main à l'abonnement. D'où, désormais :
 *
 * - « Offrir le premium » : un octroi manuel, qui survit à la fin de tout
 *   abonnement ;
 * - « Couper l'accès » : confirmation, raison obligatoire, et l'avertissement
 *   que la facturation continue quand un abonnement est payé ;
 * - « Rendre la main à l'abonnement » : la décision manuelle disparaît, le
 *   droit suit de nouveau les paiements.
 *
 * Chaque geste vise TOUS les droits du plan (`adminApi.setPremium`) : le
 * panneau les lit donc ensemble. Des droits en désaccord (une coupure
 * d'avant, qui ne visait que `premium_exercises`, ou un geste interrompu)
 * s'annoncent « partiel », et chaque bouton reste offert tant qu'il change
 * encore quelque chose à l'un d'eux.
 *
 * Les trois exigent `entitlement:grant`, comme la route : sans elle, la
 * fiche le dit au lieu de proposer des boutons toujours refusés.
 */
export function PremiumPanel({ user }: { user: ManagedUserDetail }) {
  const queryClient = useQueryClient();
  const canGrant = useAdminPermissions().includes('entitlement:grant');
  const [cutting, setCutting] = useState(false);
  const premium = premiumOf(user);
  const paid = user.paidSubscription ?? null;
  // Deux cibles de focus. Ouvrir ou annuler la coupure : le champ Raison,
  // puis « Couper l'accès ». Après un geste réussi, le bouton activé
  // disparaît avec l'état qu'il changeait : le focus va au titre, qui
  // annonce le nouvel état (« Accès premium : fermé »). Il attend que la
  // fiche affiche la réponse du serveur, que React Query livre un instant
  // après : focalisé plus tôt, le titre se lisait encore à l'ancien état.
  const { target: openerTarget, request: requestOpenerFocus } = useFocusOnSwap();
  const { target: outcomeTarget, request: requestOutcomeFocus } = useFocusOnSwap(
    premiumStateKey(premium),
  );

  const applied = (detail: ManagedUserDetail) => {
    queryClient.setQueryData(['admin', 'user', user.id], detail);
    void queryClient.invalidateQueries({ queryKey: ['admin', 'users'] });
    requestOutcomeFocus(premiumStateKey(premiumOf(detail)));
  };
  // Un geste interrompu a pu décider les premiers droits du plan : la fiche
  // relit le serveur pour montrer ce qui a VRAIMENT changé.
  const reload = () => void queryClient.invalidateQueries({ queryKey: ['admin', 'user', user.id] });
  const grant = useMutation({
    mutationFn: () => adminApi.setPremium(user.id, { isActive: true }),
    onSuccess: applied,
    onError: reload,
  });
  const cut = useMutation({
    mutationFn: (reason: string) => adminApi.setPremium(user.id, { isActive: false, reason }),
    onSuccess: (detail) => {
      applied(detail);
      setCutting(false);
    },
    onError: reload,
  });
  const release = useMutation({
    mutationFn: () => adminApi.releasePremium(user.id),
    onSuccess: applied,
    onError: reload,
  });
  // Un seul message d'échec : celui du DERNIER geste. React Query ne vide
  // l'erreur d'une mutation qu'au prochain appel de CETTE mutation : une
  // coupure ratée, puis « Rendre la main » réussi, laissait « Action
  // impossible » sous le nouvel état, sur le panneau qui touche à l'argent.
  // Chaque geste commence donc par effacer les trois.
  const clearFailures = () => {
    grant.reset();
    cut.reset();
    release.reset();
  };
  const failure = grant.error ?? cut.error ?? release.error;
  const busy = grant.isPending || cut.isPending || release.isPending;

  const [first] = premium;
  if (first === undefined) {
    return null;
  }
  const uniform = premium.every(
    (entitlement) => entitlement.isActive === first.isActive && entitlement.source === first.source,
  );
  const allOpen = premium.every((entitlement) => entitlement.isActive);
  const anyOpen = premium.some((entitlement) => entitlement.isActive);
  const state = allOpen ? 'ouvert' : anyOpen ? 'partiel' : 'fermé';
  const revoked = premium.some((entitlement) => entitlement.source === 'MANUAL_REVOCATION');
  const allRevoked = premium.every((entitlement) => entitlement.source === 'MANUAL_REVOCATION');
  const manual = revoked || premium.some((entitlement) => entitlement.source === 'MANUAL_GRANT');

  return (
    <section
      aria-labelledby="premium-title"
      className="rounded-xl bg-surface p-6 ring-1 ring-black/5"
    >
      <h2 id="premium-title" ref={outcomeTarget} tabIndex={-1} className="text-lg font-semibold">
        Accès premium : {state}
      </h2>
      <p className="mt-2 text-sm">{uniform ? premiumStateSentence(first) : MIXED_SENTENCE}</p>
      {paid !== null && <p className="mt-1 text-sm text-muted">{paidSubscriptionSentence(paid)}</p>}
      {paid !== null && revoked && (
        <p className="mt-2 text-sm font-semibold text-danger-ink">
          L’accès est coupé, mais la facturation continue : couper l’accès n’arrête pas
          l’abonnement.
        </p>
      )}

      {!canGrant && (
        <p className="mt-4 text-sm text-muted">
          Modifier l’accès premium est réservé aux administrateurs qui ont la permission
          entitlement:grant.
        </p>
      )}
      {canGrant && cutting && (
        <PremiumCutForm
          paid={paid}
          isPending={cut.isPending}
          reasonRef={openerTarget}
          onConfirm={(reason) => {
            clearFailures();
            cut.mutate(reason);
          }}
          onCancel={() => {
            clearFailures();
            requestOpenerFocus();
            setCutting(false);
          }}
        />
      )}
      {canGrant && !cutting && (
        <div className="mt-4 flex flex-wrap gap-3">
          {!allOpen && (
            <button
              type="button"
              disabled={busy}
              onClick={() => {
                clearFailures();
                grant.mutate();
              }}
              className={SECONDARY_BUTTON}
            >
              Offrir le premium
            </button>
          )}
          {!allRevoked && (
            <button
              ref={openerTarget}
              type="button"
              disabled={busy}
              onClick={() => {
                clearFailures();
                requestOpenerFocus();
                setCutting(true);
              }}
              className="rounded-lg px-4 py-2 text-sm font-semibold text-danger-ink ring-1 ring-danger-strong/40 hover:bg-black/5 disabled:opacity-50"
            >
              Couper l’accès (bloque aussi les achats)
            </button>
          )}
          {manual && (
            <button
              type="button"
              disabled={busy}
              onClick={() => {
                clearFailures();
                release.mutate();
              }}
              className={SECONDARY_BUTTON}
            >
              Rendre la main à l’abonnement
            </button>
          )}
        </div>
      )}
      {canGrant && manual && !cutting && (
        <p className="mt-2 text-xs text-muted">
          Rendre la main retire la décision de l’administration :{' '}
          {paid === null
            ? 'sans abonnement payé, l’accès se refermera.'
            : 'l’abonnement payé rouvrira l’accès aussitôt.'}
        </p>
      )}
      {failure !== null && (
        <p className="mt-3 text-sm text-danger-ink" role="alert">
          {failure instanceof ApiError && failure.status === 403
            ? 'Permission manquante pour cette action.'
            : 'Action impossible, réessaie.'}
        </p>
      )}
    </section>
  );
}
