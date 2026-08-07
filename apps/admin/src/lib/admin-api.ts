import {
  adminAuditLogSchema,
  adminLoginResultSchema,
  adminMeSchema,
  adminOverviewSchema,
  managedUserDetailSchema,
  managedUserSummarySchema,
  type AdminAuditLog,
  type AdminLoginResult,
  type AdminMe,
  type AdminOverview,
  type EntitlementKey,
  type ManagedUserDetail,
  type ManagedUserSummary,
} from '@carlys/api-contracts';
import { z } from 'zod';
import { publicEnv } from './env';

/**
 * Client de l'API d'administration : réponses VALIDÉES par les contrats Zod
 * partagés — un contrat cassé se voit immédiatement, jamais silencieusement.
 */

const TOKEN_KEY = 'carlys-admin-token';

export const adminToken = {
  get(): string | null {
    return typeof window === 'undefined' ? null : window.sessionStorage.getItem(TOKEN_KEY);
  },
  set(token: string): void {
    window.sessionStorage.setItem(TOKEN_KEY, token);
  },
  clear(): void {
    window.sessionStorage.removeItem(TOKEN_KEY);
  },
};

export class AdminApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
  }
}

const successEnvelopeSchema = z.object({ data: z.unknown() });
const errorEnvelopeSchema = z.object({
  error: z.object({ message: z.string() }),
});
const pageMetaSchema = z.object({
  nextCursor: z.string().nullable(),
  hasMore: z.boolean(),
});

export interface Page<T> {
  items: T[];
  nextCursor: string | null;
  hasMore: boolean;
}

/** Extrait `data` d'une enveloppe de succès et le valide. */
export function parseData<T>(body: unknown, schema: z.ZodType<T>): T {
  const envelope = successEnvelopeSchema.safeParse(body);
  if (!envelope.success) {
    throw new AdminApiError('Réponse inattendue du serveur.', 0);
  }
  const parsed = schema.safeParse(envelope.data.data);
  if (!parsed.success) {
    throw new AdminApiError('Réponse inattendue du serveur.', 0);
  }
  return parsed.data;
}

/** Variante paginée : `data` + `meta.nextCursor`/`meta.hasMore`. */
export function parsePage<T>(body: unknown, itemSchema: z.ZodType<T>): Page<T> {
  const items = parseData(body, z.array(itemSchema));
  const meta = pageMetaSchema.safeParse(
    (body as { meta?: unknown }).meta ?? { nextCursor: null, hasMore: false },
  );
  return {
    items,
    nextCursor: meta.success ? meta.data.nextCursor : null,
    hasMore: meta.success ? meta.data.hasMore : false,
  };
}

function errorMessageOf(body: unknown, status: number): string {
  const envelope = errorEnvelopeSchema.safeParse(body);
  return envelope.success ? envelope.data.error.message : `Erreur ${status}`;
}

async function call(path: string, init: RequestInit = {}): Promise<unknown> {
  const token = adminToken.get();
  const response = await fetch(`${publicEnv.apiBaseUrl}/api/v1${path}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(token === null ? {} : { Authorization: `Bearer ${token}` }),
      ...init.headers,
    },
    cache: 'no-store',
  });
  const body: unknown = response.status === 204 ? null : await response.json().catch(() => null);
  if (!response.ok) {
    throw new AdminApiError(errorMessageOf(body, response.status), response.status);
  }
  return body;
}

function query(params: Record<string, string | undefined>): string {
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== '') {
      search.set(key, value);
    }
  }
  const encoded = search.toString();
  return encoded === '' ? '' : `?${encoded}`;
}

export const adminApi = {
  async login(email: string, password: string): Promise<AdminLoginResult> {
    const body = await call('/admin/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    });
    return parseData(body, adminLoginResultSchema);
  },

  async me(): Promise<AdminMe> {
    return parseData(await call('/admin/auth/me'), adminMeSchema);
  },

  async overview(): Promise<AdminOverview> {
    return parseData(await call('/admin/overview'), adminOverviewSchema);
  },

  async listUsers(search?: string, cursor?: string): Promise<Page<ManagedUserSummary>> {
    const body = await call(`/admin/users${query({ search, cursor })}`);
    return parsePage(body, managedUserSummarySchema);
  },

  async userDetail(id: string): Promise<ManagedUserDetail> {
    return parseData(await call(`/admin/users/${id}`), managedUserDetailSchema);
  },

  async setUserStatus(id: string, status: 'ACTIVE' | 'SUSPENDED'): Promise<ManagedUserSummary> {
    const body = await call(`/admin/users/${id}/status`, {
      method: 'PATCH',
      body: JSON.stringify({ status }),
    });
    return parseData(body, managedUserSummarySchema);
  },

  async setEntitlement(
    id: string,
    key: EntitlementKey,
    isActive: boolean,
  ): Promise<ManagedUserDetail> {
    const body = await call(`/admin/users/${id}/entitlements`, {
      method: 'PUT',
      body: JSON.stringify({ key, isActive }),
    });
    return parseData(body, managedUserDetailSchema);
  },

  async auditLogs(cursor?: string): Promise<Page<AdminAuditLog>> {
    const body = await call(`/admin/audit-logs${query({ cursor, limit: '50' })}`);
    return parsePage(body, adminAuditLogSchema);
  },
};
