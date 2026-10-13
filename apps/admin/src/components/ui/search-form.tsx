'use client';

import { useState, type ReactNode } from 'react';
import { button, field } from './button';
import { SearchIcon } from './icons';

/**
 * Une recherche soumise (pas de requête à chaque frappe) : le terme part
 * quand on valide. `aria-label` reste le nom du champ — l'indicatif seul
 * disparaît dès la première lettre.
 */
export function SearchForm({
  label,
  placeholder,
  onSubmit,
  children,
}: {
  label: string;
  placeholder: string;
  onSubmit: (term: string) => void;
  children?: ReactNode;
}) {
  const [search, setSearch] = useState('');
  return (
    <form
      className="flex flex-wrap items-center gap-3"
      onSubmit={(event) => {
        event.preventDefault();
        onSubmit(search.trim());
      }}
    >
      <div className="relative w-full max-w-md flex-1">
        <span className="pointer-events-none absolute inset-y-0 left-3 flex items-center text-muted">
          <SearchIcon width={16} height={16} />
        </span>
        <input
          type="search"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          placeholder={placeholder}
          aria-label={label}
          className={`${field} pl-9`}
        />
      </div>
      <button type="submit" className={button('primary')}>
        Rechercher
      </button>
      {children}
    </form>
  );
}
