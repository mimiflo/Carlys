/** Taille lisible : les octets bruts ne disent rien à l'œil. */
export function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} o`;
  const kilo = bytes / 1024;
  if (kilo < 1024) return `${Math.round(kilo)} Ko`;
  return `${(kilo / 1024).toFixed(1).replace('.', ',')} Mo`;
}
