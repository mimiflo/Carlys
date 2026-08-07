import { LoadingIndicator } from '@carlys/ui';

export function AvecLibelle() {
  return (
    <div style={{ width: 320 }}>
      <LoadingIndicator label="Analyse du métabolisme…" />
    </div>
  );
}

export function Seul() {
  return (
    <div style={{ width: 160 }}>
      <LoadingIndicator />
    </div>
  );
}
