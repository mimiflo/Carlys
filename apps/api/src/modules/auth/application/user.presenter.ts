import { type AuthSession, type AuthUser } from '@carlys/api-contracts';
import { type UserSession } from '@prisma/client';
import { type UserWithProfile } from '../../users/infrastructure/users.repository';

/** Convertit les modèles Prisma vers les contrats d'API — jamais de hash ni de champ interne. */
export function presentUser(user: UserWithProfile): AuthUser {
  return {
    id: user.id,
    email: user.email,
    displayName: user.profile?.displayName ?? '',
    emailVerified: user.emailVerifiedAt !== null,
    locale: user.profile?.locale ?? 'fr',
    timezone: user.profile?.timezone ?? 'Europe/Paris',
    createdAt: user.createdAt.toISOString(),
  };
}

export function presentSession(session: UserSession, currentSessionId: string): AuthSession {
  return {
    id: session.id,
    deviceName: session.deviceName,
    devicePlatform: session.devicePlatform,
    ipAddress: session.ipAddress,
    userAgent: session.userAgent,
    createdAt: session.createdAt.toISOString(),
    lastUsedAt: session.lastUsedAt.toISOString(),
    current: session.id === currentSessionId,
  };
}
