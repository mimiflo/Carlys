import { SearchField } from '@carlys/ui';

export function Standard() {
  return (
    <div style={{ width: 320 }}>
      <SearchField aria-label="Rechercher un exercice" placeholder="Rechercher un exercice…" />
    </div>
  );
}

export function AvecValeur() {
  return (
    <div style={{ width: 320 }}>
      <SearchField aria-label="Rechercher un exercice" defaultValue="développé" />
    </div>
  );
}
