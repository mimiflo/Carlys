'use client';

import { useInfiniteQuery, type QueryKey } from '@tanstack/react-query';
import type { Page } from '@/lib/admin-api-client';
import { button } from './ui/button';

/**
 * Une liste paginée par curseur : les pages lues s'empilent dans `items`, et
 * il n'y a de page suivante que si le serveur en annonce une.
 */
export function useCursorPages<T>(
  queryKey: QueryKey,
  fetchPage: (cursor: string | undefined) => Promise<Page<T>>,
) {
  const { data, isPending, error, refetch, fetchNextPage, hasNextPage, isFetchingNextPage } =
    useInfiniteQuery({
      queryKey,
      queryFn: ({ pageParam }) => fetchPage(pageParam),
      initialPageParam: undefined as string | undefined,
      getNextPageParam: (last) =>
        last.hasMore && last.nextCursor !== null ? last.nextCursor : undefined,
    });
  const items = data?.pages.flatMap((page) => page.items) ?? [];
  return { items, data, isPending, error, refetch, fetchNextPage, hasNextPage, isFetchingNextPage };
}

/** « Charger la suite », tant que le serveur annonce une page de plus. */
export function LoadMore({
  hasNextPage,
  isFetchingNextPage,
  fetchNextPage,
}: {
  hasNextPage: boolean;
  isFetchingNextPage: boolean;
  fetchNextPage: () => Promise<unknown>;
}) {
  if (!hasNextPage) {
    return null;
  }
  return (
    <button
      type="button"
      onClick={() => void fetchNextPage()}
      disabled={isFetchingNextPage}
      className={`${button('secondary')} mt-4`}
    >
      {isFetchingNextPage ? 'Chargement…' : 'Charger la suite'}
    </button>
  );
}
