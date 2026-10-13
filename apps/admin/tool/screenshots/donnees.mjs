// Jeu d'essai du harnais de captures : de fausses réponses de l'API, conformes
// aux contrats Zod de `packages/api-contracts` (le harnais les valide avant de
// lancer le navigateur, voir `capture.mjs`). Rien ici n'est importé par
// l'application : ce sont des données de démonstration, isolées.
//
// Les photos d'exercices sont les vraies illustrations de l'appli mobile
// (`apps/mobile/assets/academy/anatomie-*.webp`), servies par la route
// factice `http://api.mock/media/<nom>.webp`.

export const API = 'http://api.mock';

const jour = (n, heure = '09:30:00') => `2026-${n}T${heure}.000Z`;
const uuid = (n) => `0000${String(n).padStart(4, '0')}-7c1e-4a2b-9d3f-5e6a7b8c9d0e`;

// ── Utilisateurs ──────────────────────────────────────────────────────────

const PERSONNES = [
  ['camille.laurent', 'Camille Laurent', 'ACTIVE', true, true, '03-14'],
  ['hugo.martin', 'Hugo Martin', 'ACTIVE', true, false, '04-02'],
  ['lea.bernard', 'Léa Bernard', 'ACTIVE', true, true, '04-21'],
  ['nathan.dubois', 'Nathan Dubois', 'SUSPENDED', false, false, '05-08'],
  ['chloe.thomas', 'Chloé Thomas', 'ACTIVE', true, false, '05-30'],
  ['lucas.robert', null, 'ACTIVE', false, false, '06-11'],
  ['manon.richard', 'Manon Richard', 'DELETED', true, false, '06-27'],
  ['theo.petit', 'Théo Petit', 'ACTIVE', true, true, '07-15'],
  ['ines.durand', 'Inès Durand', 'ACTIVE', true, false, '08-03'],
  ['louis.leroy', 'Louis Leroy', 'SUSPENDED', true, false, '08-19'],
  ['jade.moreau', 'Jade Moreau', 'ACTIVE', false, false, '09-07'],
  ['gabriel.simon', 'Gabriel Simon', 'ACTIVE', true, true, '10-01'],
];

export const USERS = PERSONNES.map(([login, nom, status, verifie, premium, date], i) => ({
  id: uuid(101 + i),
  email: `${login}@example.com`,
  displayName: nom,
  status,
  emailVerified: verifie,
  isPremium: premium,
  createdAt: jour(date, '18:42:10'),
}));

/** La fiche détaillée : la première personne, abonnée Stripe, plus un droit offert. */
export function userDetail(id) {
  const user = USERS.find((u) => u.id === id) ?? USERS[0];
  const premiumKeys = [
    'unlimited_programs',
    'advanced_statistics',
    'premium_exercises',
    'cloud_backup',
    'priority_support',
    'ai_coaching',
  ];
  const entitlements = user.isPremium
    ? [
        ...premiumKeys.map((key) => ({
          key,
          isActive: true,
          expiresAt: jour('11-14', '00:00:00'),
          source: 'SUBSCRIPTION',
          provider: 'STRIPE',
        })),
        {
          key: 'health_sync',
          isActive: true,
          expiresAt: null,
          source: 'MANUAL_GRANT',
        },
      ]
    : [];
  return {
    ...user,
    sessionsCount: user.isPremium ? 3 : 1,
    completedWorkoutsCount: user.isPremium ? 87 : 12,
    entitlements,
    paidSubscription: user.isPremium
      ? {
          provider: 'STRIPE',
          status: 'ACTIVE',
          currentPeriodEnd: jour('11-14', '00:00:00'),
          cancelAtPeriodEnd: false,
        }
      : null,
  };
}

export const OVERVIEW = {
  usersCount: 1284,
  premiumUsersCount: 317,
  workoutSessionsCount: 18452,
  completedWorkoutSessionsCount: 16903,
  exercisesCount: 186,
  publishedExercisesCount: 171,
};

// ── Catalogue ─────────────────────────────────────────────────────────────

export const MUSCLE_GROUPS = [
  ['pectoraux', 'Pectoraux', 18, 11],
  ['dos', 'Dos', 22, 14],
  ['epaules', 'Épaules', 16, 9],
  ['biceps', 'Biceps', 10, 7],
  ['triceps', 'Triceps', 12, 6],
  ['abdominaux', 'Abdominaux', 15, 12],
  ['quadriceps', 'Quadriceps', 19, 10],
  ['ischio-jambiers', 'Ischio-jambiers', 11, 5],
  ['fessiers', 'Fessiers', 14, 8],
  ['mollets', 'Mollets', 6, 4],
].map(([slug, name, exercisesCount, primaryExercisesCount], i) => ({
  id: uuid(201 + i),
  slug,
  name,
  sortOrder: i + 1,
  primaryExercisesCount,
  exercisesCount,
}));

export const EQUIPMENT = [
  ['barre', 'Barre'],
  ['halteres', 'Haltères'],
  ['banc', 'Banc'],
  ['poulie', 'Poulie'],
  ['kettlebell', 'Kettlebell'],
  ['poids-du-corps', 'Poids du corps'],
  ['barre-de-traction', 'Barre de traction'],
].map(([slug, name], i) => ({ id: uuid(301 + i), slug, name }));

function photo(n, muscle) {
  return {
    id: uuid(401 + n),
    kind: 'IMAGE',
    url: `${API}/media/anatomie-${muscle}.webp`,
    mimeType: 'image/webp',
    byteSize: 38_000 + n * 4_127,
    width: 800,
    height: 450,
    originalName: `anatomie-${muscle}.webp`,
    createdAt: jour('09-12', `1${n % 10}:05:00`),
  };
}

const groupe = (slug) => MUSCLE_GROUPS.find((g) => g.slug === slug).name;

const EXERCICES = [
  [
    'developpe-couche',
    'Développé couché',
    ['pectoraux', 'triceps'],
    ['barre', 'banc'],
    'pectoraux',
  ],
  ['squat-barre', 'Squat à la barre', ['quadriceps', 'fessiers'], ['barre'], 'quadriceps'],
  [
    'souleve-de-terre',
    'Soulevé de terre',
    ['ischio-jambiers', 'dos'],
    ['barre'],
    'ischio-jambiers',
  ],
  ['tractions', 'Tractions pronation', ['dos', 'biceps'], ['barre-de-traction'], 'dos'],
  ['curl-halteres', 'Curl biceps aux haltères', ['biceps'], ['halteres'], 'biceps'],
  ['developpe-militaire', 'Développé militaire', ['epaules', 'triceps'], ['barre'], 'epaules'],
  ['hip-thrust', 'Hip thrust', ['fessiers', 'ischio-jambiers'], ['barre', 'banc'], 'fessiers'],
  ['extension-triceps-poulie', 'Extension des triceps à la poulie', ['triceps'], ['poulie'], null],
  ['gainage-planche', 'Gainage planche', ['abdominaux'], ['poids-du-corps'], 'abdominaux'],
  ['mollets-debout', 'Extension des mollets debout', ['mollets'], ['halteres'], 'mollets'],
  [
    'swing-kettlebell',
    'Swing au kettlebell',
    ['fessiers', 'ischio-jambiers'],
    ['kettlebell'],
    null,
  ],
  [
    'rowing-haltere',
    'Rowing unilatéral à l’haltère',
    ['dos', 'biceps'],
    ['halteres', 'banc'],
    null,
  ],
  ['pompes-declinees', 'Pompes déclinées', ['pectoraux', 'epaules'], ['poids-du-corps'], null],
];

export const EXERCISES = EXERCICES.map(([slug, name, groups, equipmentSlugs, photoDe], i) => ({
  id: uuid(501 + i),
  slug,
  name,
  isPublished: i !== 7 && i !== 10,
  isPremium: [2, 6, 10].includes(i),
  primaryMuscleGroupName: groupe(groups[0]),
  muscleGroupSlugs: groups,
  primaryMuscleGroupSlug: groups[0],
  equipmentSlugs,
  deletedAt: i === 12 ? jour('09-28', '16:20:00') : null,
  image: photoDe === null ? null : photo(i, photoDe),
  mesh: null,
}));

// La bibliothèque dit qui montre chaque fichier (`usedBy`) : les photos des
// exercices le sont par leur exercice, les autres par personne.
const libre = (asset) => ({ ...asset, usedBy: [] });

export const MEDIA = [
  ...EXERCISES.flatMap((e) =>
    e.image === null ? [] : [{ ...e.image, usedBy: [{ id: e.id, name: e.name }] }],
  ),
  libre(photo(20, 'avant-bras')),
  libre(photo(21, 'lombaires')),
  {
    id: uuid(451),
    kind: 'MESH_3D',
    url: `${API}/media/squat-barre.glb`,
    mimeType: 'model/gltf-binary',
    byteSize: 2_457_600,
    width: null,
    height: null,
    originalName: 'squat-barre.glb',
    createdAt: jour('09-30', '11:12:00'),
    usedBy: [],
  },
  {
    id: uuid(452),
    kind: 'VIDEO',
    url: `${API}/media/hip-thrust-demo.mp4`,
    mimeType: 'video/mp4',
    byteSize: 8_912_896,
    width: 1080,
    height: 1920,
    originalName: 'hip-thrust-démonstration.mp4',
    createdAt: jour('10-02', '08:47:00'),
    usedBy: [],
  },
];

// ── Signalements ──────────────────────────────────────────────────────────

const partie = (u) => ({ id: u.id, email: u.email, displayName: u.displayName });

export const REPORTS = [
  [
    8,
    3,
    'HARCELEMENT',
    'Il m’envoie des messages moqueurs après chaque séance.',
    'OPEN',
    'T’appelles ça une séance ? Mon chat soulève plus lourd.',
    null,
  ],
  [
    4,
    9,
    'SPAM',
    'Lien vers un site de compléments à chaque encouragement.',
    'OPEN',
    'Bravo ! -50 % sur les protéines avec mon code CARLYS50 👉',
    null,
  ],
  [10, 9, 'CONTENU_INAPPROPRIE', null, 'OPEN', null, null],
  [
    2,
    3,
    'AUTRE',
    'Le défi demande de courir 30 km par jour, c’est dangereux.',
    'OPEN',
    null,
    ['Défi 30 km/jour pendant 7 jours', 'Celui qui lâche paie le resto 😈'],
  ],
  [
    0,
    5,
    'SPAM',
    'Même message copié-collé à tout le monde.',
    'RESOLVED',
    'Rejoins mon groupe privé, lien en bio !!!',
    null,
  ],
  [7, 1, 'HARCELEMENT', 'Commentaires insistants sur mon physique.', 'RESOLVED', null, null],
].map(([qui, vise, reason, details, status, message, defi], i) => ({
  id: uuid(601 + i),
  reportedUserId: USERS[vise].id,
  encouragementId: message === null ? null : uuid(651 + i),
  friendChallengeId: defi === null ? null : uuid(681 + i),
  reason,
  details,
  status,
  createdAt: jour(`10-${String(12 - i).padStart(2, '0')}`, `1${i}:24:00`),
  resolvedAt: status === 'RESOLVED' ? jour('10-12', '17:02:00') : null,
  reporter: partie(USERS[qui]),
  reportedUser: partie(USERS[vise]),
  encouragementMessage: message,
  friendChallengeTitle: defi?.[0] ?? null,
  friendChallengeMessage: defi?.[1] ?? null,
  friendChallengeMessageRemoved: false,
  // Le premier résolu a été tranché : contenu retiré, note au dossier.
  resolvedBy:
    status === 'RESOLVED' ? partie({ ...USERS[0], displayName: 'Florence (admin)' }) : null,
  resolutionNote: i === 4 ? 'Spam répété à tout le groupe : message retiré.' : null,
  contentRemoved: i === 4,
  userSuspended: false,
  reportedUserStatus: USERS[vise].status,
  // Nathan (3) et Louis (9) sont visés deux fois chacun : la récidive se voit.
  reportedUserReportsCount: vise === 3 || vise === 9 ? 2 : 1,
  reportedUserOpenReportsCount: vise === 3 || vise === 9 ? 2 : status === 'OPEN' ? 1 : 0,
}));

// ── Journal d'audit ───────────────────────────────────────────────────────

export const ADMIN_ME = {
  id: uuid(1),
  email: 'florence.admin@example.com',
  displayName: 'Florence (admin)',
  roles: ['super-admin'],
  permissions: [
    'user:read',
    'user:update',
    'entitlement:grant',
    'exercise:read',
    'exercise:publish',
    'exercise:write',
    'media:read',
    'media:write',
    'audit:read',
    'community:moderate',
  ],
};

const AUDIT = [
  [
    'ADMIN',
    'admin.community_report_resolved',
    'CommunityReport',
    REPORTS[4].id,
    { status: 'RESOLVED' },
  ],
  ['ADMIN', 'admin.user_suspended', 'User', USERS[3].id, { reason: 'Signalements répétés' }],
  ['USER', 'auth.login', null, null, { device: 'iPhone 15' }],
  ['ADMIN', 'admin.entitlement_granted', 'User', USERS[0].id, { key: 'health_sync' }],
  ['SYSTEM', 'subscription.renewed', 'Subscription', uuid(701), { provider: 'STRIPE' }],
  ['ADMIN', 'admin.exercise_published', 'Exercise', EXERCISES[5].id, { isPublished: true }],
  ['USER', 'auth.password_reset', null, null, null],
  ['ADMIN', 'admin.media_uploaded', 'MediaAsset', MEDIA[0].id, { mimeType: 'image/webp' }],
  ['USER', 'auth.email_verified', null, null, null],
  ['ADMIN', 'admin.muscle_group_created', 'MuscleGroup', MUSCLE_GROUPS[9].id, { slug: 'mollets' }],
  ['SYSTEM', 'account.deleted', 'User', USERS[6].id, { requestedBy: 'user' }],
  ['ADMIN', 'admin.entitlement_released', 'User', USERS[9].id, { key: 'premium_exercises' }],
  ['USER', 'auth.refresh_reuse_detected', null, null, { sessionsRevoked: 2 }],
  ['ADMIN', 'admin.totp_enrolled', 'AdminUser', uuid(1), null],
  ['ADMIN', 'admin.login_failed', null, null, { attempts: 1 }],
];

export const AUDIT_LOGS = AUDIT.map(
  ([actorType, action, resourceType, resourceId, metadata], i) => ({
    id: uuid(801 + i),
    actorType,
    action,
    userId: actorType === 'USER' ? USERS[i % USERS.length].id : null,
    adminUserId: actorType === 'ADMIN' ? uuid(1) : null,
    resourceType,
    resourceId,
    ipAddress: actorType === 'SYSTEM' ? null : `82.64.${17 + i}.${100 + i * 7}`,
    metadata,
    createdAt: jour(
      '10-13',
      `${String(13 - Math.floor(i / 2)).padStart(2, '0')}:${String(50 - i * 3).padStart(2, '0')}:00`,
    ),
  }),
);

// ── État de santé (/health, hors /api/v1) ─────────────────────────────────

export function health(degrade) {
  return {
    status: degrade ? 'error' : 'ok',
    timestamp: jour('10-13', '14:00:00'),
    uptimeSeconds: 284_311,
    components: {
      database: { status: 'up', latencyMs: 3 },
      redis: degrade ? { status: 'down' } : { status: 'up', latencyMs: 1 },
    },
  };
}
