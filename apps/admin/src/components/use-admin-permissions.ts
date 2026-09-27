import { useSyncExternalStore } from 'react';
import { EMPTY_PERMISSIONS, adminPermissions, adminToken } from '@/lib/admin-api';

/**
 * Les permissions de l'administrateur connecté, telles que la connexion les a
 * rendues, relues à chaque changement de session.
 *
 * De l'ERGONOMIE, jamais un contrôle d'accès : le serveur revérifie chaque
 * requête. Elle sert à ne pas proposer un geste qu'on sait refusé, et à dire
 * à qui le demander.
 */
export function useAdminPermissions(): readonly string[] {
  return useSyncExternalStore(adminToken.subscribe, adminPermissions.get, () => EMPTY_PERMISSIONS);
}
