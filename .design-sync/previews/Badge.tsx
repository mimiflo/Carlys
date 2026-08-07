import { Badge } from '@carlys/ui';

export function Variantes() {
  return (
    <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
      <Badge>Débutant</Badge>
      <Badge variant="primary">Renforcement</Badge>
      <Badge variant="accent">Premium</Badge>
      <Badge variant="warning">Paiement en attente</Badge>
    </div>
  );
}

export function AvecIcone() {
  return (
    <div style={{ display: 'flex', gap: 8 }}>
      <Badge variant="accent" icon={<span>★</span>}>
        Record personnel
      </Badge>
      <Badge variant="primary" icon={<span>◆</span>}>
        Corpulence normale
      </Badge>
    </div>
  );
}
