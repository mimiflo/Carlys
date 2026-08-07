import { Button } from '@carlys/ui';

export function Variantes() {
  return (
    <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
      <Button>Démarrer une séance</Button>
      <Button variant="secondary">Bibliothèque d’exercices</Button>
      <Button variant="ghost">Se déconnecter</Button>
      <Button variant="destructive">Supprimer la mesure</Button>
    </div>
  );
}

export function Tailles() {
  return (
    <div style={{ display: 'flex', gap: 12, alignItems: 'center', flexWrap: 'wrap' }}>
      <Button size="sm">Ajouter</Button>
      <Button size="md">Enregistrer</Button>
      <Button size="lg">Terminer la séance</Button>
    </div>
  );
}

export function Etats() {
  return (
    <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
      <Button isLoading>Enregistrement…</Button>
      <Button disabled>Indisponible</Button>
      <Button icon={<span>＋</span>}>Nouvelle série</Button>
    </div>
  );
}

export function PleineLargeur() {
  return (
    <div style={{ width: 320 }}>
      <Button isExpanded>Reprendre la séance</Button>
    </div>
  );
}
