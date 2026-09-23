import { type FriendChallenge as FriendChallengeContract } from '@carlys/api-contracts';
import { METRIC_UNITS } from '../domain/challenge-catalog';
import { competitionRanks } from '../domain/competition-ranks';
import { type FriendChallengeWithMembers } from '../infrastructure/friend-challenges.repository';

/**
 * Le CLASSEMENT d'un défi entre amis, calculé à la lecture tant qu'il est
 * ouvert, FIGÉ dès qu'il est clos.
 *
 * Deux régimes, et c'est nécessaire : pendant le défi, le rang doit suivre
 * la moindre séance, donc il se recalcule ; après, il ne doit plus bouger,
 * même si quelqu'un continue à s'entraîner — un résultat qui change après la
 * fin n'est pas un résultat.
 *
 * Seuls les membres qui ont ACCEPTÉ sont classés. On ne donne pas de rang à
 * quelqu'un qui n'a rien accepté, et on n'en retire pas un à qui est parti :
 * son départ le sort du classement, point.
 */
function ranksOf(challenge: FriendChallengeWithMembers): Map<string, number> {
  return competitionRanks(
    challenge.members.filter((member) => member.status === 'ACCEPTED'),
    (member) => member.contribution,
    (member) => member.userId,
  );
}

/**
 * Le défi tel que `userId` le voit.
 *
 * `blockedEitherWay` : les personnes qu'un blocage sépare de lui, dans un
 * sens ou dans l'autre. Obligatoire, pour qu'aucun appelant ne l'oublie :
 * quand le créateur en fait partie, son MOT n'est plus servi. Un texte libre
 * suit la règle du fil, qui tait les personnes bloquées ; le défi, lui,
 * reste lisible, parce que son classement est un résultat partagé qui ne se
 * réécrit pas.
 */
export function presentFriendChallenge(
  challenge: FriendChallengeWithMembers,
  userId: string,
  blockedEitherWay: ReadonlySet<string>,
): FriendChallengeContract {
  const vivant = ranksOf(challenge);
  const moi = challenge.members.find((member) => member.userId === userId);

  return {
    id: challenge.id,
    title: challenge.title,
    message: blockedEitherWay.has(challenge.creatorId) ? null : challenge.message,
    metric: challenge.metric,
    unit: METRIC_UNITS[challenge.metric],
    target: challenge.target,
    status: challenge.status,
    durationDays: challenge.durationDays,
    // L'heure du message, puisqu'il naît avec le défi et ne change plus.
    createdAt: challenge.createdAt.toISOString(),
    startsAt: challenge.startsAt.toISOString(),
    endsAt: challenge.endsAt.toISOString(),
    creatorDisplayName: challenge.creator.profile?.displayName ?? 'Membre Carlys',
    // Un non-membre ne devrait jamais arriver ici — le service l'a déjà
    // refusé — mais présenter « invité » plutôt que lever garde l'affichage
    // possible si la ligne disparaît entre deux requêtes.
    myStatus: moi?.status ?? 'INVITED',
    members: challenge.members.map((member) => ({
      userId: member.userId,
      displayName: member.user.profile?.displayName ?? 'Membre Carlys',
      status: member.status,
      contribution: member.contribution,
      // Le rang FIGÉ l'emporte dès qu'il existe : c'est celui du résultat.
      rank: member.finalRank ?? vivant.get(member.userId) ?? null,
      isMe: member.userId === userId,
      isCreator: member.userId === challenge.creatorId,
    })),
  };
}

/**
 * Les rangs à FIGER pour un défi qui vient d'échoir.
 *
 * Même calcul que l'affichage vivant, ce qui est le but : le classement
 * annoncé la veille de la fin est celui qui est inscrit.
 */
export function finalRanks(
  challenge: FriendChallengeWithMembers,
): Array<{ userId: string; rank: number }> {
  return [...ranksOf(challenge)].map(([userId, rank]) => ({ userId, rank }));
}
