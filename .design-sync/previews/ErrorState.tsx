import { ErrorState } from '@carlys/ui';

export function AvecRelance() {
  return (
    <div style={{ width: 360 }}>
      <ErrorState
        title="Statistiques indisponibles"
        message="Vérifiez votre connexion puis réessayez."
        onRetry={() => {}}
      />
    </div>
  );
}

export function SansRelance() {
  return (
    <div style={{ width: 360 }}>
      <ErrorState title="Métabolisme indisponible" />
    </div>
  );
}
