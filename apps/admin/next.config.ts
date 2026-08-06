import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  // Build autonome pour l'image Docker (copie .next/standalone).
  output: 'standalone',
};

export default nextConfig;
