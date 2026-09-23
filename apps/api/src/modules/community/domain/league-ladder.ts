/**
 * LE BARÈME DES LIGUES — une fonction pure, ni horloge ni base.
 *
 * Tout ce qui décide d'un rang, d'une montée ou d'une descente vit ici, pour
 * la même raison que `progression_engine.dart` côté mobile : un barème
 * éprouvable au cas par cas vaut mieux qu'un barème réparti dans un service.
 *
 * La règle écrite, avec ses raisons, est dans `docs/product/community.md`,
 * section « Les ligues, barème complet ». Ce fichier en est la traduction, et
 * ne doit jamais la dépasser.
 */
import { LeagueDivision, type ChallengeMetric } from '@prisma/client';
import { addDays, daysBetween, mondayOf } from '../../../common/utilities/civil-day';
import { competitionRanks } from './competition-ranks';

/**
 * Les divisions, de la plus basse à la plus haute.
 *
 * Recopie l'ordre de déclaration de l'enum Prisma, que le langage n'expose
 * pas comme une séquence ordonnée. `league-ladder.spec.ts` compare les deux
 * listes : ajouter une division au schéma sans l'ajouter ici casse un test,
 * jamais la production en silence.
 */
export const LEAGUE_LADDER: readonly LeagueDivision[] = [
  LeagueDivision.BRONZE,
  LeagueDivision.ARGENT,
  LeagueDivision.OR,
  LeagueDivision.PLATINE,
  LeagueDivision.DIAMANT,
];

/** Places d'une division. Une division qui en compte moins se joue telle quelle. */
export const LEAGUE_DIVISION_SIZE = 20;

/** Combien montent, et combien descendent, au règlement d'une période. */
export const LEAGUE_PROMOTED = 5;
export const LEAGUE_RELEGATED = 5;

/**
 * En dessous de ce nombre de JOUEURS (score non nul), personne ne bouge.
 *
 * Un classement à trois ne décide pas d'une division — et au lancement, une
 * division d'une personne la ferait monter chaque semaine jusqu'à Diamant
 * sans avoir croisé personne.
 */
export const LEAGUE_MIN_PLAYERS = 10;

/**
 * Ce que vaut une unité de contribution, en POINTS de ligue.
 *
 * Les valeurs sont choisies pour qu'aucune métrique n'écrase les autres :
 * 10 km de course valent 100 points, soit deux séances ; une heure
 * chronométrée en vaut 60, soit un peu plus d'une. Sans conversion, les
 * mètres écraseraient les séances de deux ordres de grandeur, et la ligue ne
 * classerait que des coureurs.
 *
 * La division est ENTIÈRE et tronquée : 59 secondes valent 0 point, 119
 * mètres en valent 1. Le reste n'est pas reporté — le reporter demanderait
 * un registre de restes par personne et par métrique, et rendrait le score
 * dépendant de l'ordre des écritures.
 */
export const POINTS_PER_METRIC: Record<ChallengeMetric, { per: number; points: number }> = {
  /** Une séance terminée. */
  WORKOUTS: { per: 1, points: 50 },
  /** Soixante secondes réellement chronométrées dans les séries. */
  ACTIVE_SECONDS: { per: 60, points: 1 },
  /** Cent mètres parcourus. */
  DISTANCE_METERS: { per: 100, points: 1 },
  /** Une bonne réponse, la première de la journée pour cette leçon. */
  QUIZ_CORRECT: { per: 1, points: 10 },
};

/** Les points que vaut `amount` unités de `metric`. Jamais négatif. */
export function pointsOf(metric: ChallengeMetric, amount: number): number {
  const bareme = POINTS_PER_METRIC[metric];
  if (amount <= 0) {
    return 0;
  }
  return Math.floor(amount / bareme.per) * bareme.points;
}

/**
 * La semaine ISO d'un instant, en UTC : `YYYY-Www`.
 *
 * Une chaîne, comme les jours civils : une période est un fait CIVIL, et un
 * instant se décale d'un fuseau à l'autre. UTC plutôt que l'heure de
 * l'appareil parce qu'une ligue compare des gens de plusieurs fuseaux — une
 * période par fuseau rendrait les classements incomparables.
 *
 * Le 4 janvier appartient TOUJOURS à la semaine 1 (définition ISO 8601),
 * et l'année d'une semaine est celle de son JEUDI : c'est ce qui range le
 * 31 décembre dans la semaine 1 de l'année suivante quand il tombe un lundi.
 */
export function periodKeyOf(at: Date): string {
  const lundi = mondayOf(at.toISOString().slice(0, 10));
  const annee = addDays(lundi, 3).slice(0, 4);
  const semaine = daysBetween(mondayOf(`${annee}-01-04`), lundi) / 7 + 1;
  return `${annee}-W${String(semaine).padStart(2, '0')}`;
}

/** Vrai si la chaîne a la forme `YYYY-Www` et désigne une semaine réelle. */
export function isPeriodKey(value: unknown): value is string {
  return (
    typeof value === 'string' &&
    /^\d{4}-W\d{2}$/.test(value) &&
    periodKeyOf(periodWindow(value).startsAt) === value
  );
}

/** La fenêtre d'une période : du lundi 00:00 UTC au lundi suivant, exclu. */
export function periodWindow(periodKey: string): { startsAt: Date; endsAt: Date } {
  const annee = periodKey.slice(0, 4);
  const semaine = Number(periodKey.slice(6));
  const lundi = addDays(mondayOf(`${annee}-01-04`), (semaine - 1) * 7);
  return {
    startsAt: new Date(`${lundi}T00:00:00Z`),
    endsAt: new Date(`${addDays(lundi, 7)}T00:00:00Z`),
  };
}

/** La période qui précède `periodKey`. */
export function previousPeriodKey(periodKey: string): string {
  return periodKeyOf(new Date(periodWindow(periodKey).startsAt.getTime() - 86_400_000));
}

/** Une division plus haut, ou la même si on est déjà en haut. */
export function promoted(division: LeagueDivision): LeagueDivision {
  const index = LEAGUE_LADDER.indexOf(division);
  return LEAGUE_LADDER[Math.min(index + 1, LEAGUE_LADDER.length - 1)] ?? division;
}

/** Une division plus bas, ou la même si on est déjà en bas. */
export function relegated(division: LeagueDivision): LeagueDivision {
  const index = LEAGUE_LADDER.indexOf(division);
  return LEAGUE_LADDER[Math.max(index - 1, 0)] ?? division;
}

export interface LeagueStanding {
  userId: string;
  score: number;
}

export interface LeagueSettlement {
  userId: string;
  rank: number;
  nextDivision: LeagueDivision;
}

/** Les JOUEURS d'une division : les membres dont le score de la période est non nul. */
function playersOf(members: readonly LeagueStanding[]): LeagueStanding[] {
  return members.filter((member) => member.score > 0);
}

/**
 * Vrai si `score` monterait parmi `players`, AU SENS DU RANG : il est non
 * nul, et moins de [LEAGUE_PROMOTED] joueurs font STRICTEMENT mieux.
 *
 * La règle de montée n'existe qu'ici : le règlement s'en sert pour décider,
 * `promotionOutlook` pour l'annoncer. Deux copies divergeraient exactement
 * sur l'ex æquo à la frontière, le seul cas où la règle demande à réfléchir.
 * Le minimum de joueurs n'y entre pas : chacun des deux appelants le dit à
 * sa façon.
 */
function ranksForPromotion(players: readonly LeagueStanding[], score: number): boolean {
  return score > 0 && players.filter((player) => player.score > score).length < LEAGUE_PROMOTED;
}

/**
 * Le règlement d'une division pour une période close : un rang par membre, et
 * la division de la période suivante.
 *
 * MONTER se décide au nombre de joueurs STRICTEMENT AU-DESSUS, descendre au
 * nombre de joueurs strictement en dessous. Compter les positions plutôt que
 * les rangs aurait fallu trancher les ex æquo à la frontière, c'est-à-dire
 * tirer au sort ; ainsi, une égalité en cinquième place fait monter tout le
 * monde à égalité, ce qui est la conséquence assumée de l'ex æquo.
 *
 * Trois gardes, chacune reprise d'une règle déjà écrite :
 *  - un score NUL ne fait jamais descendre. Il veut dire « n'a pas joué », et
 *    le dépôt tient qu'aucun axe ne punit une absence ;
 *  - en dessous de [LEAGUE_MIN_PLAYERS] joueurs, personne ne bouge ;
 *  - si la même personne remplit les deux conditions — dix joueurs tous à
 *    égalité — elle ne bouge pas. Une ligue parfaitement ambiguë ne relègue
 *    personne.
 */
export function settleDivision(
  division: LeagueDivision,
  members: readonly LeagueStanding[],
): LeagueSettlement[] {
  const rangs = competitionRanks(
    members,
    (member) => member.score,
    (member) => member.userId,
  );
  const joueurs = playersOf(members);
  const fige = joueurs.length < LEAGUE_MIN_PLAYERS;

  return members.map((member) => {
    const rank = rangs.get(member.userId) ?? members.length;
    if (fige || member.score <= 0) {
      return { userId: member.userId, rank, nextDivision: division };
    }
    const dessous = joueurs.filter((autre) => autre.score < member.score).length;
    const monte = ranksForPromotion(joueurs, member.score);
    const descend = dessous < LEAGUE_RELEGATED;
    if (monte === descend) {
      return { userId: member.userId, rank, nextDivision: division };
    }
    return {
      userId: member.userId,
      rank,
      nextDivision: monte ? promoted(division) : relegated(division),
    };
  });
}

/** Où en est une personne face à la zone de montée — voir [promotionOutlook]. */
export interface PromotionOutlook {
  promotedCount: number;
  minPlayers: number;
  activePlayers: number;
  topDivision: boolean;
  inZone: boolean;
  zoneScore: number | null;
  pointsToZone: number;
}

/**
 * OÙ J'EN SUIS face à la zone de montée, si la période se fermait maintenant.
 *
 * Calculé à côté du règlement et avec SA règle (`ranksForPromotion`) : le
 * mobile l'écrit sans rien recopier du barème, et une retouche du barème ne
 * peut pas laisser l'annonce dire autre chose que le règlement.
 *
 * `inZone` est la règle du rang SEULE. Le minimum de joueurs se lit à part
 * (`activePlayers` face à `minPlayers`) : l'écran peut dire « dans la zone,
 * mais la semaine ne comptera qu'à partir de dix joueurs » au lieu de taire
 * la zone jusqu'au dixième. La garde d'ambiguïté du règlement n'y entre pas
 * non plus : elle ne mord que quand des ex æquo couvrent à la fois les cinq
 * premières et les cinq dernières places, et la taire ici garde `inZone`
 * d'accord avec `pointsToZone`.
 *
 * `zoneScore` est le [LEAGUE_PROMOTED]-ième score parmi les AUTRES joueurs :
 * l'ÉGALER suffit, puisque les ex æquo partagent le rang. Il n'existe pas
 * tant que moins de [LEAGUE_PROMOTED] autres ont marqué — marquer un point
 * suffit alors. En Diamant, rien au-dessus : ni zone, ni seuil, ni écart.
 */
export function promotionOutlook(
  division: LeagueDivision,
  members: readonly LeagueStanding[],
  userId: string,
): PromotionOutlook {
  const joueurs = playersOf(members);
  const monScore = members.find((member) => member.userId === userId)?.score ?? 0;
  const bareme = {
    promotedCount: LEAGUE_PROMOTED,
    minPlayers: LEAGUE_MIN_PLAYERS,
    activePlayers: joueurs.length,
  };
  // Le sommet se lit dans `promoted`, qui plafonne déjà le règlement : un
  // test de plus sur DIAMANT ferait une seconde source de « tout en haut ».
  if (promoted(division) === division) {
    return { ...bareme, topDivision: true, inZone: false, zoneScore: null, pointsToZone: 0 };
  }

  const autres = joueurs
    .filter((joueur) => joueur.userId !== userId)
    .map((joueur) => joueur.score)
    .sort((a, b) => b - a);
  const zoneScore = autres[LEAGUE_PROMOTED - 1] ?? null;
  return {
    ...bareme,
    topDivision: false,
    inZone: ranksForPromotion(joueurs, monScore),
    zoneScore,
    // Sans seuil, la zone est ouverte à qui marque : un point suffit.
    pointsToZone: zoneScore === null ? (monScore > 0 ? 0 : 1) : Math.max(0, zoneScore - monScore),
  };
}
