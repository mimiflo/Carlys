/** Les initiales d'une personne, dans une pastille violette. */
export function initials(name: string | null, email: string): string {
  const source = name !== null && name.trim() !== '' ? name : (email.split('@')[0] ?? email);
  const words = source.split(/[\s._-]+/u).filter((word) => word !== '');
  const letters =
    words.length > 1 ? `${words[0]?.[0] ?? ''}${words[1]?.[0] ?? ''}` : source.slice(0, 2);
  return letters.toUpperCase();
}

export function Avatar({
  name,
  email,
  size = 'md',
}: {
  name: string | null;
  email: string;
  size?: 'md' | 'lg';
}) {
  return (
    <span
      aria-hidden
      className={`inline-flex shrink-0 items-center justify-center rounded-full bg-primary/12 font-semibold text-primary-ink ${
        size === 'lg' ? 'h-14 w-14 text-lg' : 'h-9 w-9 text-xs'
      }`}
    >
      {initials(name, email)}
    </span>
  );
}
