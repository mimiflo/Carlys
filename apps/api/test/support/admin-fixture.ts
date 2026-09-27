import { ADMIN_PERMISSIONS, type AdminPermission } from '@carlys/api-contracts';
import { type PrismaClient } from '@prisma/client';
import * as argon2 from 'argon2';

/**
 * Crée un compte d'administration porteur d'un rôle aux permissions
 * choisies — mêmes upserts idempotents que le seed, pour qu'une suite reste
 * autonome sur une base vierge. Le rôle est propre à la suite (`slug`) :
 * deux suites qui tournent l'une après l'autre ne se retirent pas leurs
 * permissions.
 */
export async function createAdminAccount(
  prisma: PrismaClient,
  input: {
    email: string;
    password: string;
    roleSlug: string;
    permissions: readonly AdminPermission[];
  },
): Promise<void> {
  for (const permission of ADMIN_PERMISSIONS) {
    const [resource, action] = permission.split(':') as [string, string];
    await prisma.adminPermission.upsert({
      where: { resource_action: { resource, action } },
      update: {},
      create: { resource, action },
    });
  }
  const all = await prisma.adminPermission.findMany();
  const role = await prisma.adminRole.upsert({
    where: { slug: input.roleSlug },
    update: {},
    create: { slug: input.roleSlug, name: input.roleSlug },
  });
  await prisma.adminRolePermission.deleteMany({ where: { roleId: role.id } });
  await prisma.adminRolePermission.createMany({
    data: all
      .filter((permission) =>
        input.permissions.includes(
          `${permission.resource}:${permission.action}` as AdminPermission,
        ),
      )
      .map((permission) => ({ roleId: role.id, permissionId: permission.id })),
  });
  const passwordHash = await argon2.hash(input.password, { type: argon2.argon2id });
  const admin = await prisma.adminUser.create({
    data: { email: input.email, displayName: 'Admin E2E', passwordHash },
  });
  await prisma.adminUserRole.create({ data: { adminUserId: admin.id, roleId: role.id } });
}
