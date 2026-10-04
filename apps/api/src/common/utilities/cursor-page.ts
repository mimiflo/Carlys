/**
 * Une page « par curseur » : le dépôt lit `limit + 1` lignes, la dernière
 * ne sert qu'à dire qu'il y a une suite. Le curseur est l'identifiant du
 * dernier élément rendu.
 */
export interface CursorPage<T> {
  items: T[];
  nextCursor: string | null;
  hasMore: boolean;
}

export function cursorPage<R, T extends { id: string }>(
  rows: readonly R[],
  limit: number,
  present: (row: R) => T,
): CursorPage<T> {
  const hasMore = rows.length > limit;
  const items = rows.slice(0, limit).map((row) => present(row));
  return { items, hasMore, nextCursor: hasMore ? (items.at(-1)?.id ?? null) : null };
}
