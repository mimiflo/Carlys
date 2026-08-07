import { Badge, Button, Card, CarlysProvider, Metric } from '@carlys/ui';

function Sample() {
  return (
    <div style={{ padding: 16, width: 280 }}>
      <Card>
        <Metric value="82,5 kg" label="Dernière pesée" />
        <div style={{ marginTop: 12, display: 'flex', gap: 8, alignItems: 'center' }}>
          <Badge variant="accent">Premium</Badge>
          <Button size="sm" variant="secondary">
            Détails
          </Button>
        </div>
      </Card>
    </div>
  );
}

export function ThemeClair() {
  return (
    <CarlysProvider theme="light">
      <Sample />
    </CarlysProvider>
  );
}

export function ThemeSombre() {
  return (
    <CarlysProvider theme="dark">
      <Sample />
    </CarlysProvider>
  );
}

export function ThemeSombreOled() {
  return (
    <CarlysProvider theme="oled">
      <Sample />
    </CarlysProvider>
  );
}
