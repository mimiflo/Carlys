'use client';

import { useEffect, useId, useRef, type ReactNode } from 'react';
import { CloseIcon } from './icons';

/**
 * Un panneau posé à droite, par-dessus la page : la fiche d'un exercice,
 * d'un média, d'un signalement.
 *
 * C'est un `<dialog>` NATIF ouvert en modal : le navigateur piège le focus,
 * rend le reste de la page inerte, ferme sur Échap et rend le focus à
 * l'élément qui l'a ouvert. Rien de tout cela n'est réécrit ici.
 */
export function SidePanel({
  title,
  subtitle,
  onClose,
  children,
}: {
  title: ReactNode;
  subtitle?: ReactNode;
  onClose: () => void;
  children: ReactNode;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const titleId = useId();

  // Ouvert au montage. Pas de `close()` au démontage : retiré du DOM, le
  // `<dialog>` quitte de lui-même la couche modale — et un `close()` ici
  // émettrait `close`, donc `onClose`, au double montage de React en
  // développement, refermant le panneau à peine ouvert.
  useEffect(() => {
    const element = dialog.current;
    // Le focus d'avant, rendu au démontage quand le panneau disparaît sans
    // `close()` (élément sorti de la liste) : sinon il tomberait sur <body>.
    const opener = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    if (element !== null && !element.open) {
      element.showModal();
    }
    return () => {
      if (!document.contains(document.activeElement) || document.activeElement === document.body) {
        opener?.focus();
      }
    };
  }, []);

  return (
    <dialog
      ref={dialog}
      aria-labelledby={titleId}
      onClose={onClose}
      // Un clic sur le VOILE ferme, comme Échap. Le voile appartient au
      // <dialog> : on le reconnaît à la position, hors du panneau — un clic
      // dans un blanc du panneau vise aussi le <dialog> et ne doit rien fermer.
      onClick={(event) => {
        const box = dialog.current?.getBoundingClientRect();
        if (
          event.target === dialog.current &&
          box !== undefined &&
          (event.clientX < box.left || event.clientY < box.top || event.clientY > box.bottom)
        ) {
          dialog.current?.close();
        }
      }}
      className="animate-panel fixed inset-y-0 right-0 left-auto m-0 h-full max-h-none w-full max-w-lg overflow-y-auto border-l border-border bg-surface p-0 text-foreground shadow-2xl backdrop:bg-black/40"
    >
      <div className="sticky top-0 z-10 flex items-start justify-between gap-4 border-b border-border bg-surface/95 px-6 py-5 backdrop-blur">
        <div className="min-w-0">
          <h2 id={titleId} className="truncate text-lg font-semibold">
            {title}
          </h2>
          {subtitle !== undefined && <div className="mt-0.5 text-sm text-muted">{subtitle}</div>}
        </div>
        <button
          type="button"
          onClick={() => dialog.current?.close()}
          aria-label="Fermer"
          className="rounded-lg p-1.5 text-muted transition-colors duration-150 hover:bg-foreground/5 hover:text-foreground"
        >
          <CloseIcon />
        </button>
      </div>
      <div className="flex flex-col gap-8 px-6 py-6">{children}</div>
    </dialog>
  );
}

/** Une rubrique du panneau : un intitulé discret, puis son contenu. */
export function PanelSection({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section>
      <h3 className="text-xs font-semibold tracking-wide text-muted uppercase">{title}</h3>
      <div className="mt-3">{children}</div>
    </section>
  );
}
