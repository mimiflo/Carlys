import { type ExecutionContext, ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { METHOD_METADATA, PATH_METADATA } from '@nestjs/common/constants';
import { type Reflector } from '@nestjs/core';
import {
  AdminExerciseMediaController,
  MediaController,
} from '../../../media/presentation/http/media.controller';
import {
  AdminCatalogController,
  AdminCategoriesController,
} from '../http/admin-catalog.controller';
import { AdminPlatformController } from '../http/admin-platform.controller';
import { AdminUsersController } from '../http/admin-users.controller';
import { type AdminRequest } from './admin-auth.guard';
import { AdminPermissionsGuard, REQUIRED_PERMISSIONS_KEY } from './admin-permissions.guard';

function contextFor(request: Partial<AdminRequest>): ExecutionContext {
  return {
    getHandler: () => function handler() {},
    getClass: () => class Controller {},
    switchToHttp: () => ({ getRequest: () => request }),
  } as unknown as ExecutionContext;
}

function buildGuard(required: string[] | undefined): AdminPermissionsGuard {
  const reflector = { getAllAndOverride: jest.fn().mockReturnValue(required) };
  return new AdminPermissionsGuard(reflector as unknown as Reflector);
}

const SUPPORT: AdminRequest['adminPrincipal'] = {
  adminUserId: 'admin-1',
  email: 'support@carlys.local',
  permissions: ['user:read', 'audit:read'],
};

/**
 * RBAC du back-office : la garde échoue FERMÉ. Tout ce qui n'est pas
 * explicitement autorisé (principal absent, route sans permission déclarée,
 * permission manquante) est refusé.
 */
describe('AdminPermissionsGuard', () => {
  it('laisse passer quand toutes les permissions exigées sont accordées', () => {
    const guard = buildGuard(['user:read']);

    expect(guard.canActivate(contextFor({ adminPrincipal: SUPPORT }))).toBe(true);
  });

  it('refuse (403) dès qu’une permission exigée manque, en la nommant', () => {
    const guard = buildGuard(['user:read', 'user:update']);

    expect(() => guard.canActivate(contextFor({ adminPrincipal: SUPPORT }))).toThrow(
      ForbiddenException,
    );
    expect(() => guard.canActivate(contextFor({ adminPrincipal: SUPPORT }))).toThrow('user:update');
  });

  it('refuse (401) sans principal, même sur une route sans permission déclarée', () => {
    // AdminAuthGuard doit précéder cette garde : sans lui, personne n'est identifié.
    expect(() => buildGuard(['user:read']).canActivate(contextFor({}))).toThrow(
      UnauthorizedException,
    );
    expect(() => buildGuard(undefined).canActivate(contextFor({}))).toThrow(UnauthorizedException);
  });

  it('refuse (403) une route SANS @RequirePermissions : l’oubli ferme, il n’ouvre pas', () => {
    // Une route ajoutée sans le décorateur serait sinon accessible à tout
    // admin connecté, rôle support compris.
    expect(() =>
      buildGuard(undefined).canActivate(contextFor({ adminPrincipal: SUPPORT })),
    ).toThrow(ForbiddenException);
    expect(() => buildGuard([]).canActivate(contextFor({ adminPrincipal: SUPPORT }))).toThrow(
      ForbiddenException,
    );
  });
});

/**
 * Chaque route HTTP protégée par la garde déclare ses permissions. C'est ce
 * test qui rattrape la prochaine route ajoutée sans `@RequirePermissions` :
 * la garde la fermerait, mais un 403 systématique sur une route neuve doit
 * se voir ici, pas en production.
 */
describe('Routes d’administration : toutes déclarent leurs permissions', () => {
  const controllers = [
    AdminUsersController,
    AdminPlatformController,
    AdminCatalogController,
    AdminCategoriesController,
    MediaController,
    AdminExerciseMediaController,
  ];

  const prototypeOf = (controller: (typeof controllers)[number]): Record<string, unknown> =>
    controller.prototype as unknown as Record<string, unknown>;

  const routesOf = (controller: (typeof controllers)[number]): string[] =>
    Object.getOwnPropertyNames(controller.prototype).filter((name) => {
      const handler = prototypeOf(controller)[name];
      return (
        typeof handler === 'function' &&
        Reflect.getMetadata(PATH_METADATA, handler) !== undefined &&
        Reflect.getMetadata(METHOD_METADATA, handler) !== undefined
      );
    });

  it('parcourt réellement des routes (le test ne peut pas passer à vide)', () => {
    const total = controllers.reduce((count, controller) => count + routesOf(controller).length, 0);
    expect(total).toBeGreaterThanOrEqual(21);
  });

  it.each(controllers.map((controller) => [controller.name, controller] as const))(
    '%s : chaque route porte un @RequirePermissions non vide',
    (_name, controller) => {
      for (const route of routesOf(controller)) {
        const handler = prototypeOf(controller)[route];
        const required: unknown = Reflect.getMetadata(REQUIRED_PERMISSIONS_KEY, handler as object);
        // Le nom de la route apparaît dans le message d'échec.
        expect({ route, declared: Array.isArray(required) && required.length > 0 }).toEqual({
          route,
          declared: true,
        });
      }
    },
  );
});
