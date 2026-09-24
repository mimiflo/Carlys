import { z } from 'zod';
import { codePointLength } from './text';

/**
 * Contrats de la communauté (/api/v1/community).
 *
 * La séparation public/privé est décidée par le SERVEUR : quand un ami ne
 * partage pas sa progression, `streakDays` et `weeklySessions` sont `null`
 * — le client n'a jamais la donnée, il ne peut donc pas la montrer.
 */

export const communityFriendSchema = z.object({
  userId: z.string(),
  displayName: z.string(),
  sharesProgress: z.boolean(),
  /** Jours consécutifs avec séance — `null` si la progression est privée. */
  streakDays: z.number().nullable(),
  /** Séances terminées sur les 7 derniers jours — `null` si privée. */
  weeklySessions: z.number().nullable(),
});
export type CommunityFriend = z.infer<typeof communityFriendSchema>;

/** Demande d'ami REÇUE. Les demandes envoyées ne sont jamais listées :
 *  c'est ce qui rend l'envoi par e-mail non énumérable. */
export const friendRequestSchema = z.object({
  id: z.string(),
  fromDisplayName: z.string(),
  createdAt: z.string(),
});
export type FriendRequest = z.infer<typeof friendRequestSchema>;

export const encouragementSchema = z.object({
  id: z.string(),
  fromUserId: z.string(),
  fromDisplayName: z.string(),
  message: z.string(),
  sentAt: z.string(),
});
export type Encouragement = z.infer<typeof encouragementSchema>;

/**
 * Longueur maximale d'un encouragement, en POINTS DE CODE
 * (`codePointLength`), comme le DTO de l'API (`@MaxCodePoints`).
 */
export const ENCOURAGEMENT_MESSAGE_MAX_LENGTH = 280;

/**
 * POST /community/encouragements — encourager un ami ACCEPTÉ (`403` sinon).
 *
 * Le mot est compté en points de code, pas en unités UTF-16 : `.max()` y
 * compterait un émoji pour deux, et refuserait ce que l'API accepte.
 */
export const encourageRequestSchema = z.object({
  recipientUserId: z.string().uuid(),
  message: z
    .string()
    .min(1)
    .refine((text) => codePointLength(text) <= ENCOURAGEMENT_MESSAGE_MAX_LENGTH, {
      message: `Ton mot tient en ${ENCOURAGEMENT_MESSAGE_MAX_LENGTH} caractères au plus.`,
    }),
});
export type EncourageRequest = z.infer<typeof encourageRequestSchema>;

export const challengeKindSchema = z.enum(['SPORT', 'CULTURE']);
export type ChallengeKind = z.infer<typeof challengeKindSchema>;

/**
 * CE QU'UN DÉFI COMPTE. `kind` ne disait que la famille ; l'unité vivait en
 * prose dans le catalogue et en `+1` codé en dur côté serveur, donc un défi
 * « 500 km ensemble » ne pouvait pas s'exprimer.
 */
export const challengeMetricSchema = z.enum([
  'WORKOUTS',
  'QUIZ_CORRECT',
  'ACTIVE_SECONDS',
  'DISTANCE_METERS',
]);
export type ChallengeMetric = z.infer<typeof challengeMetricSchema>;

export const communityChallengeSchema = z.object({
  id: z.string(),
  kind: challengeKindSchema,
  metric: challengeMetricSchema,
  /**
   * L'unité écrite en toutes lettres (« séances », « mètres »), servie par
   * le serveur comme le titre et la description : deux endroits où nommer la
   * même unité, c'est un endroit de trop pour la faire diverger.
   */
  unit: z.string(),
  title: z.string(),
  description: z.string(),
  /** Objectif collectif, dans l'unité de `metric`. */
  target: z.number(),
  /**
   * Somme BRUTE des contributions, non bornée : c'est elle qui permet
   * d'écrire « 127 / 500 séances » là où le seul ratio ne disait rien, et
   * un groupe qui dépasse son objectif mérite de le voir.
   */
  totalContribution: z.number(),
  /** Progression COLLECTIVE, bornée à [0, 1]. */
  progress: z.number(),
  participants: z.number(),
  joined: z.boolean(),
  endsAt: z.string(),
});
export type CommunityChallenge = z.infer<typeof communityChallengeSchema>;

/** Forme canonique d'un code ami : 8 caractères d'un alphabet sans
 *  ambiguïté visuelle (ni 0/O, ni 1/I/L…) — la normalisation des saisies
 *  (casse, tirets, préfixe QR) est faite AVANT validation. */
export const friendCodeSchema = z.string().regex(/^[23456789ACDEFHJKMNPRTUVWXY]{8}$/);
export type FriendCode = z.infer<typeof friendCodeSchema>;

/** Aperçu renvoyé par la résolution d'un code ami : juste de quoi
 *  confirmer « c'est bien elle/lui » avant d'envoyer la demande. */
export const friendCodePreviewSchema = z.object({
  displayName: z.string(),
});
export type FriendCodePreview = z.infer<typeof friendCodePreviewSchema>;

export const communityProfileSchema = z.object({
  sharesProgress: z.boolean(),
  /** Mon code ami — affiché en XXXX-XXXX et porté par le QR de profil. */
  friendCode: friendCodeSchema,
});
export type CommunityProfile = z.infer<typeof communityProfileSchema>;

// ── Modération : blocages et signalements ─────────────────────────────────

/**
 * Personne que J'AI bloquée (GET /community/blocks). Un blocage est
 * unilatéral et opaque : l'autre n'en est jamais informé, il ne voit qu'un
 * compte qui n'existe plus (demande muette, code ami inconnu, encouragement
 * refusé). Bloquer retire l'amitié et les demandes en attente dans les deux
 * sens ; débloquer ne les rétablit pas.
 */
export const blockedUserSchema = z.object({
  userId: z.string(),
  displayName: z.string(),
  blockedAt: z.string(),
});
export type BlockedUser = z.infer<typeof blockedUserSchema>;

export const communityReportReasonSchema = z.enum([
  'HARCELEMENT',
  'SPAM',
  'CONTENU_INAPPROPRIE',
  'AUTRE',
]);
export type CommunityReportReason = z.infer<typeof communityReportReasonSchema>;

export const communityReportStatusSchema = z.enum(['OPEN', 'RESOLVED']);
export type CommunityReportStatus = z.infer<typeof communityReportStatusSchema>;

/**
 * Longueur maximale des précisions d'un signalement, en POINTS DE CODE
 * (`codePointLength`), comme le DTO de l'API (`@MaxCodePoints`).
 */
export const COMMUNITY_REPORT_DETAILS_MAX_LENGTH = 500;

/**
 * POST /community/reports — signaler une personne, un encouragement précis
 * qu'elle m'a envoyé, OU un défi entre amis qu'elle a créé (son titre et son
 * message). Viser les deux à la fois est refusé (`400`).
 */
export const createCommunityReportSchema = z
  .object({
    reportedUserId: z.string().uuid(),
    /** Encouragement visé : doit avoir été envoyé PAR la personne signalée AU signalant. */
    encouragementId: z.string().uuid().nullable().optional(),
    /**
     * Défi entre amis visé : le signalant doit en être membre (quel que soit
     * son statut, il a pu lire le message avant de refuser) et la personne
     * signalée doit en être la CRÉATRICE. Sinon `404`, sans dire lequel.
     */
    friendChallengeId: z.string().uuid().nullable().optional(),
    reason: communityReportReasonSchema,
    // Pas `.max()`, qui compte les unités UTF-16 : voir `codePointLength`.
    details: z
      .string()
      .refine((text) => codePointLength(text) <= COMMUNITY_REPORT_DETAILS_MAX_LENGTH, {
        message: `Tes précisions tiennent en ${COMMUNITY_REPORT_DETAILS_MAX_LENGTH} caractères au plus.`,
      })
      .optional(),
  })
  // `null` et absent disent la même chose : pas de cible de ce type.
  .refine(
    (body) => (body.encouragementId ?? null) === null || (body.friendChallengeId ?? null) === null,
    {
      message: 'Un encouragement OU un défi, pas les deux.',
      path: ['friendChallengeId'],
    },
  );
export type CreateCommunityReport = z.infer<typeof createCommunityReportSchema>;

/**
 * Signalement tel que le voit son AUTEUR : l'accusé de réception. Un
 * signalement OUVERT identique (même personne, même encouragement ou même
 * défi) n'est pas dupliqué : le rejeu rend le même.
 */
export const communityReportSchema = z.object({
  id: z.string(),
  reportedUserId: z.string(),
  encouragementId: z.string().nullable(),
  /** Défi entre amis visé, `null` si le signalement n'en vise aucun. */
  friendChallengeId: z.string().nullable(),
  reason: communityReportReasonSchema,
  details: z.string().nullable(),
  status: communityReportStatusSchema,
  createdAt: z.string(),
  resolvedAt: z.string().nullable(),
});
export type CommunityReport = z.infer<typeof communityReportSchema>;

/**
 * GET /community/quiz-answers — les leçons de l'Academy déjà répondues,
 * relues pour reconstruire la progression sur un nouvel appareil.
 *
 * Une entrée par leçon : la PREMIÈRE réponse fait foi, comme sur l'appareil
 * (le magasin local applique « la première gagne »). `choiceIndex` est
 * `null` sur les réponses enregistrées avant que le choix ne soit transmis :
 * on sait que la leçon a été abordée, pas ce qui a été coché.
 */
export const quizAnswerRecordSchema = z.object({
  lessonId: z.string(),
  choiceIndex: z.number().int().nullable(),
  correct: z.boolean(),
  /** Jour LOCAL de l'appareil au moment de la réponse (YYYY-MM-DD). */
  answeredOn: z.string(),
});
export type QuizAnswerRecord = z.infer<typeof quizAnswerRecordSchema>;

// ── Défis entre amis (Plan 7) ───────────────────────────────────────────────

/**
 * Durées offertes. Trois valeurs, et pas un champ libre : un défi « entre
 * amis » de 400 jours n'est plus un défi, c'est une dette. La liste est du
 * CODE — l'allonger ne demande pas de migration.
 */
export const FRIEND_CHALLENGE_DURATIONS = [3, 7, 30] as const;
export type FriendChallengeDuration = (typeof FRIEND_CHALLENGE_DURATIONS)[number];

/** Nombre d'invités en plus du créateur. Au-delà, ce n'est plus « entre amis ». */
export const FRIEND_CHALLENGE_MAX_INVITES = 9;

/**
 * Défis OUVERTS qu'une personne peut avoir créés en même temps.
 *
 * Sans ce plafond, l'invitation devient un canal d'envoi de messages vers
 * quelqu'un qui ne l'a pas demandé — exactement ce que le refus opposable
 * des demandes d'ami avait fermé.
 */
export const FRIEND_CHALLENGE_MAX_OPEN_PER_CREATOR = 5;

/**
 * Longueur maximale du mot du créateur, mesurée APRÈS découpage des blancs
 * autour. La même que celle d'un encouragement : c'en est un, adressé à tous
 * les invités d'un coup.
 *
 * Comptée en POINTS DE CODE (`codePointLength`), des deux côtés : ce contrat
 * et le DTO de l'API (`@MaxCodePoints`). Un émoji simple vaut un, un émoji
 * composé (❤️, drapeau, teinte de peau) plusieurs.
 */
export const FRIEND_CHALLENGE_MESSAGE_MAX_LENGTH = 280;

/**
 * Longueur maximale du titre d'un défi entre amis, APRÈS découpage des blancs
 * autour, en POINTS DE CODE (`codePointLength`) comme le mot du créateur.
 */
export const FRIEND_CHALLENGE_TITLE_MAX_LENGTH = 80;

export const friendChallengeStatusSchema = z.enum(['OPEN', 'CLOSED', 'CANCELLED']);
export type FriendChallengeStatus = z.infer<typeof friendChallengeStatusSchema>;

export const friendChallengeMemberStatusSchema = z.enum([
  'INVITED',
  'ACCEPTED',
  'DECLINED',
  'LEFT',
]);
export type FriendChallengeMemberStatus = z.infer<typeof friendChallengeMemberStatusSchema>;

/** Une ligne du classement : qui, combien, et à quelle place. */
export const friendChallengeMemberSchema = z.object({
  userId: z.string(),
  displayName: z.string(),
  status: friendChallengeMemberStatusSchema,
  contribution: z.number(),
  /**
   * Rang courant pendant le défi, FIGÉ à la clôture. `null` pour qui n'a pas
   * encore accepté : on ne classe pas quelqu'un qui n'a rien accepté.
   */
  rank: z.number().nullable(),
  isMe: z.boolean(),
  /** Vrai pour la personne qui a lancé le défi (membre ACCEPTÉ d'office). */
  isCreator: z.boolean(),
});
export type FriendChallengeMember = z.infer<typeof friendChallengeMemberSchema>;

export const friendChallengeSchema = z.object({
  id: z.string(),
  title: z.string(),
  /**
   * Le mot du créateur à ses invités, `null` s'il n'a rien écrit. Lu par les
   * seuls membres (le défi est `404` pour les autres), jamais porté par la
   * notification d'invitation. `null` aussi quand un blocage, dans un sens ou
   * l'autre, sépare le lecteur du créateur : le défi reste, son mot est masqué.
   */
  message: z.string().nullable(),
  metric: challengeMetricSchema,
  unit: z.string(),
  /** Objectif commun, ou `null` : c'est alors « qui en fait le plus ». */
  target: z.number().nullable(),
  status: friendChallengeStatusSchema,
  /** 3, 7 ou 30 : la durée choisie à la création. */
  durationDays: z.number().int(),
  /** Création du défi (ISO UTC) — c'est aussi l'heure du message. */
  createdAt: z.string(),
  startsAt: z.string(),
  endsAt: z.string(),
  creatorDisplayName: z.string(),
  /** L'état de l'appelant DANS ce défi — ce qui décide des boutons offerts. */
  myStatus: friendChallengeMemberStatusSchema,
  members: z.array(friendChallengeMemberSchema),
});
export type FriendChallenge = z.infer<typeof friendChallengeSchema>;

/**
 * Corps de `POST /community/friend-challenges`.
 *
 * L'identifiant vient de l'appareil, comme partout ailleurs : rejouer la
 * création après une coupure ne crée pas un second défi. `endsAt` n'y figure
 * PAS — le serveur le calcule depuis la durée, sinon une seule requête
 * suffirait à poser un défi éternel.
 */
export const createFriendChallengeRequestSchema = z.object({
  id: z.string().uuid(),
  title: z
    .string()
    .trim()
    .min(1)
    .refine((text) => codePointLength(text) <= FRIEND_CHALLENGE_TITLE_MAX_LENGTH, {
      message: `Ton titre tient en ${FRIEND_CHALLENGE_TITLE_MAX_LENGTH} caractères au plus.`,
    }),
  metric: challengeMetricSchema,
  target: z.number().int().positive().max(10_000_000).nullable().optional(),
  durationDays: z.union([z.literal(3), z.literal(7), z.literal(30)]),
  /**
   * Le mot du créateur, facultatif. Découpé des blancs autour AVANT d'être
   * mesuré ; vide après découpage, il vaut « pas de message » (`null` en
   * base). Un rejeu de la création ne le modifie pas.
   */
  message: z
    .string()
    .trim()
    // Pas `.max()`, qui compte les unités UTF-16 : un émoji y vaut deux, et
    // le contrat refusait ce que l'API accepte. Voir `codePointLength`.
    .refine((text) => codePointLength(text) <= FRIEND_CHALLENGE_MESSAGE_MAX_LENGTH, {
      message: `Ton mot tient en ${FRIEND_CHALLENGE_MESSAGE_MAX_LENGTH} caractères au plus.`,
    })
    .nullable()
    .optional(),
  /** Amis invités — au moins un : un défi contre personne n'en est pas un. */
  invitedUserIds: z.array(z.string().uuid()).min(1).max(FRIEND_CHALLENGE_MAX_INVITES),
});
export type CreateFriendChallengeRequest = z.infer<typeof createFriendChallengeRequestSchema>;

// ──────────────────────────────── Ligues ─────────────────────────────────

/**
 * Les cinq divisions, de la plus basse à la plus haute. L'ordre EST le
 * barème : le mobile s'en sert pour dessiner l'échelle.
 */
export const leagueDivisionSchema = z.enum(['BRONZE', 'ARGENT', 'OR', 'PLATINE', 'DIAMANT']);
export type LeagueDivision = z.infer<typeof leagueDivisionSchema>;

/**
 * Une ligne du classement de MON GROUPE : les membres de ma division rangés
 * avec moi pour la période, 20 au plus (`LEAGUE_GROUP_SIZE` côté serveur),
 * jamais la division entière. Une personne qu'un blocage sépare de moi, dans
 * un sens ou dans l'autre, n'y figure pas.
 */
export const leagueStandingSchema = z.object({
  userId: z.string(),
  displayName: z.string(),
  /** Points de la période, jamais l'unité brute d'une métrique. */
  score: z.number(),
  /**
   * Rang courant dans le groupe ENTIER, FIGÉ dès que la période est réglée.
   * Une personne tue (blocage) garde son rang : la numérotation peut donc
   * sauter (1, 3, 4…), et c'est voulu — on ne décale personne.
   */
  rank: z.number(),
  isMe: z.boolean(),
});
export type LeagueStanding = z.infer<typeof leagueStandingSchema>;

/**
 * OÙ J'EN SUIS face à la zone de montée, si la période se fermait maintenant.
 *
 * Calculé par le SERVEUR, à côté du règlement et avec la même règle
 * (`league-ladder.ts`, `promotionOutlook`) : un client qui la recopierait
 * divergerait exactement sur l'ex æquo à la frontière, et à la première
 * retouche du barème. Le mobile ÉCRIT ces nombres, il ne les calcule pas.
 */
export const leaguePromotionSchema = z.object({
  /** Combien montent au règlement — servi pour être écrit, jamais recopié. */
  promotedCount: z.number(),
  /** En dessous de ce nombre de joueurs à score non nul, personne ne bouge. */
  minPlayers: z.number(),
  /**
   * Membres de mon groupe dont le score de la période est non nul, moi
   * compris (personnes tues comprises : la zone se lit sur tout le groupe). Face à `minPlayers`, il dit si la semaine COMPTERA — ce que
   * `inZone` ne dit volontairement pas.
   */
  activePlayers: z.number(),
  /** Vrai en Diamant : il n'y a rien au-dessus, donc ni zone ni écart. */
  topDivision: z.boolean(),
  /**
   * Je monterais si la période se fermait maintenant, AU SENS DU RANG SEUL :
   * j'ai marqué, et moins de `promotedCount` autres joueurs font strictement
   * mieux. Le minimum de joueurs n'y entre pas — il se lit à part, pour que
   * l'écran puisse dire « dans la zone, mais il faut dix joueurs » au lieu de
   * taire la zone. Ni la garde d'ambiguïté du règlement (des ex æquo à cheval
   * sur les cinq premières et les cinq dernières places ne bougent pas) :
   * c'est la ZONE, pas le verdict. Toujours faux en Diamant.
   */
  inZone: z.boolean(),
  /**
   * Le score qui fait entrer dans la zone : le `promotedCount`-ième plus haut
   * parmi les AUTRES joueurs. L'ÉGALER suffit, les ex æquo partagent le rang.
   * `null` quand moins de `promotedCount` autres ont marqué (un point suffit
   * alors), et en Diamant.
   */
  zoneScore: z.number().nullable(),
  /**
   * Points qui me manquent pour entrer dans la zone : `zoneScore` moins mon
   * score, jamais négatif ; sans `zoneScore`, 0 si j'ai marqué et 1 sinon.
   * Toujours 0 dans la zone et en Diamant.
   *
   * La montée se joue au RANG, pas à un seuil de points — ce champ dit
   * l'écart avec la 5e place, qui BOUGE avec les autres. C'est un état de la
   * semaine à relire, jamais un objectif fixé qu'on atteindrait une fois.
   */
  pointsToZone: z.number(),
});
export type LeaguePromotion = z.infer<typeof leaguePromotionSchema>;

/**
 * Ce que la ligue rend en une lecture.
 *
 * `joined` à `false` décrit une ligue à laquelle on n'a PAS adhéré : le
 * classement est alors vide, et l'écran montre l'invitation à entrer. La
 * ligue est un opt-in — voir `docs/product/community.md`, principe 5.
 */
export const leagueSchema = z.object({
  joined: z.boolean(),
  /** Semaine ISO en UTC, `YYYY-Www`. */
  periodKey: z.string(),
  /** Fin de la période, en ISO 8601 : ce qui écrit « il reste 3 jours ». */
  endsAt: z.string(),
  division: leagueDivisionSchema,
  /** Mon score de la période, 0 tant que rien n'a été versé. */
  score: z.number(),
  standings: z.array(leagueStandingSchema),
  /**
   * Le résultat de la semaine PASSÉE (la semaine ISO qui précède
   * immédiatement `periodKey`), si elle est réglée et que j'y figurais : ce
   * qui permet d'annoncer une montée ou une descente au lieu d'un changement
   * de division sans explication. Servi à CHAQUE membre du groupe, quel que
   * soit le lecteur qui a réglé la semaine, et pendant toute la semaine en
   * cours ; `null` si je n'ai pas joué la semaine passée (même si une
   * semaine plus ancienne vient d'être réglée).
   */
  lastResult: z
    .object({
      periodKey: z.string(),
      rank: z.number(),
      from: leagueDivisionSchema,
      to: leagueDivisionSchema,
    })
    .nullable(),
  /**
   * Où j'en suis face à la zone de montée ; `null` tant qu'on n'a pas
   * rejoint — il n'y a alors ni classement, ni zone à situer.
   */
  promotion: leaguePromotionSchema.nullable(),
});
export type League = z.infer<typeof leagueSchema>;
