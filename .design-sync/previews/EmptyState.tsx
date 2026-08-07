import { Button, EmptyState } from '@carlys/ui';

const inboxIcon = (
  <svg width="32" height="32" viewBox="0 0 24 24" fill="none" aria-hidden>
    <path
      d="M4 13h4l2 3h4l2-3h4M5 6h14l2 7v5H3v-5l2-7Z"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinejoin="round"
    />
  </svg>
);

export function Standard() {
  return (
    <div style={{ width: 360 }}>
      <EmptyState
        icon={inboxIcon}
        title="Aucune mesure enregistrée"
        message="Ajoutez votre poids pour suivre son évolution."
      />
    </div>
  );
}

export function AvecAction() {
  return (
    <div style={{ width: 360 }}>
      <EmptyState
        icon={inboxIcon}
        title="Aucune séance sur la période"
        message="Terminez une séance pour voir votre volume ici."
        action={<Button>Démarrer une séance</Button>}
      />
    </div>
  );
}
