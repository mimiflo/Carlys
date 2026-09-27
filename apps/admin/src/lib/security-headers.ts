/**
 * En-têtes de sécurité de TOUTES les pages servies par cette application :
 * le back-office et les pages publiques ouvertes depuis un e-mail.
 *
 * Il n'y en avait aucun, et `X-Powered-By: Next.js` en prime. Or le jeton
 * d'administration (douze heures) vit en `sessionStorage`, lisible par tout
 * script de l'origine, et « Suspendre le compte » part en un clic : la
 * console pouvait être encadrée par n'importe quel site (clickjacking).
 * Aucune faille XSS n'est connue, React échappe tout et rien n'injecte de
 * HTML ; ces en-têtes sont la défense en profondeur qui manquait.
 *
 * Lu par `next.config.ts` AU BUILD : `NEXT_PUBLIC_API_BASE_URL` y a la même
 * valeur que celle inlinée dans le code client (argument de build du
 * Dockerfile).
 */

export interface SecurityHeadersOptions {
  /** Base de l'API, ex. https://api.carlys.app : seule origine joignable en plus de la page. */
  apiBaseUrl: string;
  /** `next dev` : le rechargement à chaud exige `eval`, et le stockage local sert en http. */
  isDevelopment: boolean;
}

/**
 * La politique de contenu.
 *
 * - `script-src 'unsafe-inline'` : Next pose ses données de page dans des
 *   scripts EN LIGNE. Les remplacer par un nonce forcerait le rendu dynamique
 *   de chaque page (plus aucune page statique) : l'échange n'en vaut pas la
 *   peine tant que rien n'injecte de HTML. Les scripts EXTERNES, eux, ne
 *   viennent que de l'origine.
 * - `connect-src` : la page et l'API, rien d'autre. Un script injecté ne
 *   pourrait pas envoyer le jeton ailleurs par `fetch`.
 * - `img-src https:` : les photos viennent du stockage objet, dont le
 *   domaine change d'un environnement à l'autre ; une image n'exécute rien.
 *   `http:` s'y ajoute seulement pour un build sans TLS (API en `http://`,
 *   donc un poste local et son MinIO) : un build de production servi en
 *   HTTPS ne charge jamais d'image en clair.
 * - `frame-ancestors 'none'` : personne n'encadre la console.
 */
export function contentSecurityPolicy({
  apiBaseUrl,
  isDevelopment,
}: SecurityHeadersOptions): string {
  const api = new URL(apiBaseUrl);
  const plainHttp = isDevelopment || api.protocol === 'http:';
  return [
    "default-src 'self'",
    `script-src 'self' 'unsafe-inline'${isDevelopment ? " 'unsafe-eval'" : ''}`,
    "style-src 'self' 'unsafe-inline'",
    `img-src 'self' data: blob: https:${plainHttp ? ' http:' : ''}`,
    "font-src 'self'",
    `connect-src 'self' ${api.origin}`,
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    "frame-ancestors 'none'",
  ].join('; ');
}

export function securityHeaders(options: SecurityHeadersOptions): { key: string; value: string }[] {
  return [
    { key: 'Content-Security-Policy', value: contentSecurityPolicy(options) },
    // Pour les navigateurs qui ignorent encore `frame-ancestors`.
    { key: 'X-Frame-Options', value: 'DENY' },
    { key: 'X-Content-Type-Options', value: 'nosniff' },
    // `/reset-password?token=…` porte un secret dans l'URL : aucune page ne
    // transmet son adresse à un autre site.
    { key: 'Referrer-Policy', value: 'no-referrer' },
    { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
  ];
}
