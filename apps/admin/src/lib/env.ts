/**
 * Variables d'environnement publiques de l'admin.
 * Les variables NEXT_PUBLIC_* sont inlinées au build ; on centralise leur
 * lecture ici pour ne jamais accéder à process.env depuis les composants.
 */
export const publicEnv = {
  /** Base de l'API sans le préfixe de version, ex. http://localhost:3000 */
  apiBaseUrl: process.env.NEXT_PUBLIC_API_BASE_URL ?? 'http://localhost:3000',
} as const;
