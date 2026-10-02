/** Ce que la route EN FLUX donne au tour : texte, file, annulation. */
export interface CoachStream {
  onText?: (delta: string) => void;
  /** Attentes devant cette demande, à chaque changement. */
  onQueued?: (ahead: number) => void;
  /** Son tour est venu, après avoir attendu. */
  onStarted?: () => void;
  /** Une étape de sa réflexion, commencée puis finie (coach-steps.ts). */
  onStep?: (label: string, done: boolean, elapsedMs: number) => void;
  /** Écran fermé, « Arrêter », réseau coupé : la génération s'arrête. */
  signal?: AbortSignal;
}
