import type { NextConfig } from 'next';
import { securityHeaders } from './src/lib/security-headers';

const nextConfig: NextConfig = {
  // Build autonome pour l'image Docker (copie .next/standalone).
  output: 'standalone',
  // `X-Powered-By: Next.js` n'apprend rien à personne, sauf à qui cherche une
  // version à attaquer.
  poweredByHeader: false,
  headers() {
    return Promise.resolve([
      {
        source: '/:path*',
        headers: securityHeaders({
          apiBaseUrl: process.env.NEXT_PUBLIC_API_BASE_URL ?? 'http://localhost:3000',
          isDevelopment: process.env.NODE_ENV !== 'production',
        }),
      },
    ]);
  },
};

export default nextConfig;
