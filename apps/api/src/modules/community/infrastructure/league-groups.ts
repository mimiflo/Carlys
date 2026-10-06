import { type LeagueDivision, type Prisma } from '@prisma/client';
import { createHash } from 'node:crypto';
import { cohortToJoin, LEAGUE_GROUP_SIZE, type LeagueGroupCount } from '../domain/league-ladder';

/**
 * LE REMPLISSAGE DES GROUPES DE LIGUE, sous verrou.
 *
 * Compter les membres d'un groupe puis y écrire est une lecture-écriture :
 * deux ouvertures simultanées dans la même (période, division) liraient
 * chacune « 19 membres » et rempliraient le groupe à 21. Un index unique ne
 * sait pas dire « au plus 20 lignes par groupe » ; un verrou consultatif
 * TRANSACTIONNEL de PostgreSQL, pris par (période, division), sérialise
 * l'attribution sans bloquer les autres divisions ni les autres semaines. Il
 * se libère tout seul à la fin de la transaction, validée ou annulée : aucun
 * déverrouillage à oublier.
 */

/**
 * La clé du verrou de (période, division) : un entier 64 bits STABLE, tiré
 * d'une empreinte SHA-256 de la clé en clair.
 *
 * Stable d'un processus à l'autre et d'un réplica à l'autre — c'est tout ce
 * que demande un verrou partagé ; `hashtext` de PostgreSQL l'est aussi, mais
 * il n'est pas documenté comme tel d'une version majeure à l'autre. Le
 * préfixe range ces clés à part de tout autre usage futur des verrous
 * consultatifs.
 */
function groupLockKey(periodKey: string, division: LeagueDivision): bigint {
  return createHash('sha256')
    .update(`carlys:ligue:${periodKey}:${division}`)
    .digest()
    .readBigInt64BE(0);
}

/**
 * Prend les verrous des (période, division) données, dans l'ordre CROISSANT
 * de leur clé, pour la durée de la transaction `tx`.
 *
 * L'ordre fixe est ce qui évite l'interblocage quand deux règlements
 * simultanés déplacent chacun des membres vers plusieurs divisions : chacun
 * attend l'autre dans le même ordre, jamais en croix. Reprendre un verrou
 * déjà tenu par la même transaction ne bloque pas.
 */
export async function lockGroups(
  tx: Prisma.TransactionClient,
  places: ReadonlyArray<{ periodKey: string; division: LeagueDivision }>,
): Promise<void> {
  const cles = [...new Set(places.map((place) => groupLockKey(place.periodKey, place.division)))];
  cles.sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
  if (cles.length === 0) {
    return;
  }
  // UN aller-retour pour tous : la sous-requête rend les clés dans l'ordre
  // croissant, et l'appel les prend dans cet ordre. `$executeRaw` et non
  // `$queryRaw` : la fonction rend `void`, que le client ne sait pas
  // désérialiser en colonne.
  await tx.$executeRaw`
    SELECT pg_advisory_xact_lock(cle)
    FROM (SELECT cle FROM unnest(${cles}::bigint[]) AS cle ORDER BY cle) AS triees
  `;
}

/**
 * Le groupe qui accueillera un nouveau membre de (période, division).
 *
 * À appeler SOUS le verrou de (période, division) ([lockGroups]), dans la
 * transaction qui écrira la ligne : c'est ce qui rend le compte vrai au
 * moment de l'écriture.
 */
export async function groupWithRoom(
  tx: Prisma.TransactionClient,
  periodKey: string,
  division: LeagueDivision,
): Promise<number> {
  return cohortToJoin(await groupCounts(tx, periodKey, division));
}

/**
 * Ce qu'il faut savoir des groupes de (période, division) pour y placer
 * quelqu'un : ceux qui ont de la place, et le dernier (après lequel un
 * nouveau s'ouvre). Lu dans `LeagueCohort`, tenu par la base : quelques
 * lignes par index, là où compter les membres relisait toute la division
 * sous le verrou. [cohortToJoin] rend sur ces lignes la même réponse que sur
 * tous les groupes.
 */
async function groupCounts(
  tx: Prisma.TransactionClient,
  periodKey: string,
  division: LeagueDivision,
): Promise<LeagueGroupCount[]> {
  // ponytail: parcours linéaire des GROUPES (pas des membres) de la division,
  // ~6 ms à 50 000 groupes (un million de membres) ; au-delà, un index
  // partiel `WHERE members < 20` le ramène à 0,1 ms.
  // UNE lecture : les groupes qui ont de la place, plus le dernier. `> 0` :
  // un groupe vidé par des départs n'existe plus, il n'a donc pas de place
  // — comme quand on comptait les membres (`cohortToJoin`).
  return tx.$queryRaw<LeagueGroupCount[]>`
    SELECT "cohort", "members" FROM "LeagueCohort"
    WHERE "periodKey" = ${periodKey}
      AND "division" = ${division}::"LeagueDivision"
      AND "members" > 0
      AND ("members" < ${LEAGUE_GROUP_SIZE} OR "cohort" = (
        SELECT MAX("cohort") FROM "LeagueCohort"
        WHERE "periodKey" = ${periodKey}
          AND "division" = ${division}::"LeagueDivision"
          AND "members" > 0
      ))
    ORDER BY "cohort"
  `;
}

/**
 * Le groupe de chacun des `arrivals`, nouveaux membres de la MÊME (période,
 * division), dans leur ordre d'arrivée : exactement ce que rendraient autant
 * d'appels successifs à [groupWithRoom], chacun suivi de l'écriture de sa
 * ligne — le premier groupe qui a de la place, et chaque arrivée y prend une
 * place.
 *
 * Pure : c'est ce qui permet de ranger un lot sur UN comptage au lieu d'un
 * par membre (voir [groupsForArrivals]).
 */
export function assignCohorts<T>(
  groups: readonly LeagueGroupCount[],
  arrivals: readonly T[],
): Array<T & { cohort: number }> {
  const effectifs = new Map(groups.map((group) => [group.cohort, group.members]));
  return arrivals.map((arrival) => {
    const cohort = cohortToJoin(
      [...effectifs].map(([numero, members]) => ({ cohort: numero, members })),
    );
    effectifs.set(cohort, (effectifs.get(cohort) ?? 0) + 1);
    return { ...arrival, cohort };
  });
}

/**
 * Le groupe de chaque membre d'un lot à ranger, UN comptage par (période,
 * division) au lieu d'un par membre. À appeler SOUS les verrous de toutes
 * les (période, division) du lot ([lockGroups]), dans la transaction qui
 * écrira les lignes.
 *
 * L'ordre du lot est respecté à l'intérieur de chaque (période, division) :
 * le résultat est celui qu'aurait donné un [groupWithRoom] par membre, pris
 * dans cet ordre, chacun suivi de son écriture.
 */
export async function groupsForArrivals<T extends { periodKey: string; division: LeagueDivision }>(
  tx: Prisma.TransactionClient,
  lot: readonly T[],
): Promise<Array<T & { cohort: number }>> {
  const parPlace = new Map<
    string,
    { periodKey: string; division: LeagueDivision; arrivees: T[] }
  >();
  for (const arrivee of lot) {
    const cle = `${arrivee.periodKey}|${arrivee.division}`;
    const place = parPlace.get(cle) ?? { ...arrivee, arrivees: [] };
    place.arrivees.push(arrivee);
    parPlace.set(cle, place);
  }
  const ranges: Array<T & { cohort: number }> = [];
  for (const { periodKey, division, arrivees } of parPlace.values()) {
    ranges.push(...assignCohorts(await groupCounts(tx, periodKey, division), arrivees));
  }
  return ranges;
}
