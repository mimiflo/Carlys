import { Badge, Button, Card, Metric } from '@carlys/ui';

export function Simple() {
  return (
    <div style={{ width: 320 }}>
      <Card>
        <h3 style={{ margin: 0 }}>Développé couché</h3>
        <p style={{ margin: '8px 0 0', opacity: 0.7 }}>
          Poussée horizontale à la barre, allongé sur un banc.
        </p>
      </Card>
    </div>
  );
}

export function Cliquable() {
  return (
    <div style={{ width: 320 }}>
      <Card onClick={() => {}} aria-label="Ouvrir la fiche Squat">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <strong>Squat</strong>
          <Badge variant="primary">Quadriceps</Badge>
        </div>
      </Card>
    </div>
  );
}

export function Composee() {
  return (
    <div style={{ width: 320 }}>
      <Card>
        <Metric value="2759 kcal" label="Objectif quotidien" size="lg" />
        <div style={{ marginTop: 12, display: 'flex', gap: 8 }}>
          <Badge variant="accent">Prendre du muscle</Badge>
        </div>
        <div style={{ marginTop: 16 }}>
          <Button isExpanded variant="secondary">
            Ajuster mon profil
          </Button>
        </div>
      </Card>
    </div>
  );
}
