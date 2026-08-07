import { Card, Metric } from '@carlys/ui';

export function Standard() {
  return <Metric value="82,5 kg" label="Dernière pesée" />;
}

export function Hero() {
  return <Metric value="2759 kcal" label="Objectif quotidien" size="lg" />;
}

export function Grille() {
  return (
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, width: 360 }}>
      <Card>
        <Metric value="14" label="Séances ce mois-ci" />
      </Card>
      <Card>
        <Metric value="22 850 kg" label="Volume soulevé" />
      </Card>
      <Card>
        <Metric value="1780 kcal" label="Métabolisme de base" />
      </Card>
      <Card>
        <Metric value="24,6" label="IMC" />
      </Card>
    </div>
  );
}
