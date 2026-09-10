import { ADMIN_PERMISSIONS, type AdminPermission } from '@carlys/api-contracts';
import type { PrismaClient } from '@prisma/client';

/**
 * RBAC de l'administration — les rôles, et ce qu'ils ont le droit de faire.
 *
 * LE CODE EST LA SOURCE DE VÉRITÉ, pas la base : `ADMIN_PERMISSIONS` vit dans
 * `packages/api-contracts`, les rôles ci-dessous, et `syncAdminRbac` projette
 * les deux dans PostgreSQL de façon idempotente. Cette fonction vivait dans le
 * seed de développement, ce qui avait une conséquence invisible : sur un
 * serveur, où seul `prisma migrate deploy` s'exécute, **aucun rôle, aucune
 * permission et aucun compte admin n'existaient**. La page de connexion du
 * back-office était là ; personne ne pouvait la passer. Le seed et la
 * commande `admin-bootstrap` appellent désormais le même code.
 */
export interface AdminRoleDefinition {
  readonly slug: string;
  readonly name: string;
  readonly permissions: readonly AdminPermission[];
}

export const ADMIN_ROLES: readonly AdminRoleDefinition[] = [
  { slug: 'superadmin', name: 'Super-administrateur', permissions: ADMIN_PERMISSIONS },
  {
    // Les signalements de la communauté sont un travail de support : les lire
    // et les résoudre va avec la lecture des comptes.
    slug: 'support',
    name: 'Support',
    permissions: ['user:read', 'audit:read', 'community:moderate'],
  },
  {
    // Le contenu, c'est aussi les médias : sans `media:write`, ce rôle ne
    // pourrait pas déposer la photo d'un exercice qu'il a le droit de publier.
    slug: 'content-manager',
    name: 'Gestion du contenu',
    permissions: [
      'exercise:read',
      'exercise:publish',
      'exercise:write',
      'media:read',
      'media:write',
    ],
  },
];

export function adminRoleBySlug(slug: string): AdminRoleDefinition | undefined {
  return ADMIN_ROLES.find((role) => role.slug === slug);
}

/**
 * Projette permissions et rôles dans la base. Idempotent : les permissions
 * sont créées si absentes, les rôles créés ou renommés, et les liens
 * rôle → permissions reconstruits à chaque appel pour refléter exactement
 * `ADMIN_ROLES` — une permission retirée d'un rôle dans le code disparaît
 * de la base au passage suivant, elle ne survit pas par oubli.
 */
export async function syncAdminRbac(prisma: PrismaClient): Promise<void> {
  for (const permission of ADMIN_PERMISSIONS) {
    const [resource, action] = permission.split(':') as [string, string];
    await prisma.adminPermission.upsert({
      where: { resource_action: { resource, action } },
      update: {},
      create: { resource, action },
    });
  }
  const permissionIds = new Map(
    (await prisma.adminPermission.findMany()).map((permission) => [
      `${permission.resource}:${permission.action}`,
      permission.id,
    ]),
  );

  for (const role of ADMIN_ROLES) {
    const { id } = await prisma.adminRole.upsert({
      where: { slug: role.slug },
      update: { name: role.name },
      create: { slug: role.slug, name: role.name },
    });
    await prisma.adminRolePermission.deleteMany({ where: { roleId: id } });
    await prisma.adminRolePermission.createMany({
      data: role.permissions.map((permission) => {
        const permissionId = permissionIds.get(permission);
        if (permissionId === undefined) {
          throw new Error(`Permission inconnue dans la base après synchronisation : ${permission}`);
        }
        return { roleId: id, permissionId };
      }),
    });
  }
}
