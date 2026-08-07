import { TextField } from '@carlys/ui';

export function Standard() {
  return (
    <div style={{ width: 320 }}>
      <TextField label="Taille (cm)" hint="Par exemple 178" placeholder="178" inputMode="decimal" />
    </div>
  );
}

export function Erreur() {
  return (
    <div style={{ width: 320 }}>
      <TextField
        label="Adresse e-mail"
        defaultValue="camille@exemple"
        error="Adresse e-mail invalide"
      />
    </div>
  );
}

export function Desactive() {
  return (
    <div style={{ width: 320 }}>
      <TextField label="Identifiant" defaultValue="camille.dupont" disabled />
    </div>
  );
}
