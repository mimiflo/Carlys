import { type CommunityChallenge as ChallengeContract } from '@carlys/api-contracts';
import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { buildMonthlyChallenges } from '../domain/challenge-catalog';
import {
  type ChallengeWithStats,
  CommunityChallengesRepository,
} from '../infrastructure/community-challenges.repository';

function presentChallenge(challenge: ChallengeWithStats, userId: string): ChallengeContract {
  const total = challenge.participations.reduce((sum, p) => sum + p.contribution, 0);
  return {
    id: challenge.id,
    kind: challenge.kind,
    title: challenge.title,
    description: challenge.description,
    target: challenge.target,
    progress: challenge.target <= 0 ? 0 : Math.min(1, total / challenge.target),
    participants: challenge.participations.length,
    joined: challenge.participations.some((p) => p.userId === userId),
    endsAt: challenge.endsAt.toISOString(),
  };
}

/** Défis collectifs : progression de groupe, contributions des séances et des quiz. */
@Injectable()
export class CommunityChallengesService {
  constructor(
    private readonly challenges: CommunityChallengesRepository,
    @InjectPinoLogger(CommunityChallengesService.name)
    private readonly logger: PinoLogger,
  ) {}

  async listChallenges(userId: string): Promise<ChallengeContract[]> {
    const now = new Date();
    await this.ensureMonthlyChallenges(now);
    const challenges = await this.challenges.listOpenChallenges(now);
    return challenges.map((challenge) => presentChallenge(challenge, userId));
  }

  /**
   * Création PARESSEUSE et idempotente du jeu du mois : dès qu'une lecture
   * trouve le catalogue incomplet pour le mois courant, ce qui manque est
   * écrit (un mois vierge, ou un catalogue enrichi en cours de mois). Pas de
   * tâche planifiée à surveiller ; l'unicité (slug, mois) et `skipDuplicates`
   * absorbent les lectures concurrentes. Un mois déjà servi ne coûte qu'un
   * comptage.
   */
  private async ensureMonthlyChallenges(now: Date): Promise<void> {
    const seeds = buildMonthlyChallenges(now);
    const month = seeds[0]?.month;
    if (month === undefined) {
      return; // Catalogue vide : rien à matérialiser.
    }
    const present = await this.challenges.countForMonth(
      month,
      seeds.map((seed) => seed.slug),
    );
    if (present >= seeds.length) {
      return;
    }
    await this.challenges.createMonthlyChallenges(seeds);
  }

  async joinChallenge(userId: string, challengeId: string): Promise<ChallengeContract> {
    await this.ensureChallengeOpen(challengeId);
    await this.challenges.joinChallenge(challengeId, userId);
    return this.challengeOf(userId, challengeId);
  }

  async leaveChallenge(userId: string, challengeId: string): Promise<ChallengeContract> {
    await this.ensureChallengeOpen(challengeId);
    await this.challenges.leaveChallenge(challengeId, userId);
    return this.challengeOf(userId, challengeId);
  }

  private async ensureChallengeOpen(challengeId: string): Promise<void> {
    const challenge = await this.challenges.findChallengeById(challengeId);
    if (challenge === null || challenge.endsAt < new Date()) {
      throw new NotFoundException('Défi introuvable ou terminé.');
    }
  }

  private async challengeOf(userId: string, challengeId: string): Promise<ChallengeContract> {
    const challenge = await this.challenges.challengeStats(challengeId);
    if (challenge === null) {
      throw new NotFoundException('Défi introuvable.');
    }
    return presentChallenge(challenge, userId);
  }

  /**
   * Contribution des défis SPORT à la clôture d'une séance. Ne fait JAMAIS
   * échouer la clôture : un échec est journalisé, le compte se rattrape à la
   * prochaine séance (la barre est collective, pas comptable).
   */
  async recordWorkoutCompleted(userId: string, completedAt: Date): Promise<void> {
    try {
      await this.challenges.incrementSportContributions(userId, completedAt);
    } catch (error) {
      this.logger.error(
        { err: error, userId },
        'Contribution aux défis non enregistrée — rattrapage à la prochaine séance',
      );
    }
  }

  /**
   * Enregistre une réponse de quiz. Seule une réponse JUSTE et NOUVELLE
   * (première fois pour cette leçon ce jour-là) contribue aux défis CULTURE
   * rejoints — rejouer l'envoi ne compte jamais deux fois.
   */
  async recordQuizAnswer(
    userId: string,
    input: { lessonId: string; answeredOn: string; correct: boolean },
  ): Promise<void> {
    const created = await this.challenges.createQuizAnswer({ userId, ...input });
    if (created && input.correct) {
      await this.challenges.incrementCultureContributions(userId, new Date());
    }
  }
}
