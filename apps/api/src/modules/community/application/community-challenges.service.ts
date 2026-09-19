import {
  type CommunityChallenge as ChallengeContract,
  type QuizAnswerRecord,
} from '@carlys/api-contracts';
import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { METRIC_UNITS, buildMonthlyChallenges } from '../domain/challenge-catalog';
import {
  type ChallengeWithStats,
  CommunityChallengesRepository,
} from '../infrastructure/community-challenges.repository';
import { dayKeyToInstant } from '../../../common/validators/is-recent-day-key';

function presentChallenge(challenge: ChallengeWithStats): ChallengeContract {
  return {
    id: challenge.id,
    kind: challenge.kind,
    metric: challenge.metric,
    unit: METRIC_UNITS[challenge.metric],
    title: challenge.title,
    description: challenge.description,
    target: challenge.target,
    // Le total BRUT part avec le ratio : la barre seule ne sait pas écrire
    // « 127 / 500 séances », et le client qui voulait le faire n'avait que
    // le pourcentage. Non borné, lui — un groupe qui dépasse son objectif
    // mérite de le voir.
    totalContribution: challenge.totalContribution,
    progress:
      challenge.target <= 0 ? 0 : Math.min(1, challenge.totalContribution / challenge.target),
    participants: challenge.participants,
    joined: challenge.joined,
    endsAt: challenge.endsAt.toISOString(),
  };
}

/**
 * Ce qu'une séance a coûté, dans les unités que les défis savent compter.
 *
 * Nommé plutôt qu'écrit en clair à chaque signature : trois endroits le
 * traversent (le service des séances qui le calcule, la façade communauté
 * qui le relaie, ce service qui le verse), et un objet anonyme recopié trois
 * fois est trois occasions de le faire diverger.
 */
export interface SessionEffort {
  /** Secondes réellement chronométrées série par série, pauses exclues. */
  activeSeconds: number;
  distanceMeters: number;
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
    const challenges = await this.challenges.listOpenChallenges(now, userId);
    return challenges.map(presentChallenge);
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
    const challenge = await this.challenges.challengeStats(challengeId, userId);
    if (challenge === null) {
      throw new NotFoundException('Défi introuvable.');
    }
    return presentChallenge(challenge);
  }

  /**
   * Ce qu'une séance terminée verse aux défis : une séance, ses secondes
   * d'effort, ses mètres parcourus.
   *
   * TROIS métriques pour une clôture, et c'est le but de la généralisation :
   * le même fait alimente les défis qui comptent des séances ET ceux qui
   * comptent des kilomètres, sans que personne n'ait à choisir. Les deux
   * dernières valent zéro sur une séance de fonte, et zéro ne s'écrit pas.
   *
   * Ne fait JAMAIS échouer la clôture : un échec est journalisé, le compte se
   * rattrape à la prochaine séance (la barre est collective, pas comptable).
   */
  async recordWorkoutCompleted(
    userId: string,
    completedAt: Date,
    effort: SessionEffort,
  ): Promise<void> {
    try {
      await this.challenges.contribute(userId, 'WORKOUTS', 1, completedAt);
      await this.challenges.contribute(userId, 'ACTIVE_SECONDS', effort.activeSeconds, completedAt);
      await this.challenges.contribute(
        userId,
        'DISTANCE_METERS',
        effort.distanceMeters,
        completedAt,
      );
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
    input: { lessonId: string; answeredOn: string; correct: boolean; choiceIndex?: number },
  ): Promise<void> {
    // Les deux écritures partent ENSEMBLE, dans une transaction du dépôt.
    // Séparées, l'échec de la seconde laissait la première : au rejeu,
    // l'unicité rendait « déjà comptée », l'incrément n'était jamais retenté,
    // et la contribution était perdue définitivement — une leçon ne se répond
    // qu'une fois par jour, il n'y a pas de rattrapage possible.
    //
    // L'instant de référence vient du JOUR DÉCLARÉ, pas de l'horloge
    // serveur : l'unicité porte sur `answeredOn`, donc compter sur
    // `new Date()` laissait une seule leçon renvoyée avec des dates
    // fabriquées créditer autant de fois le défi EN COURS. Les deux faits
    // parlent désormais du même jour, et une réponse hors de la fenêtre
    // d'un défi ne lui apporte rien (la borne `startsAt <= at <= endsAt`
    // s'en charge). Le DTO borne en amont ce jour à celui du serveur, à un
    // fuseau près.
    await this.challenges.recordQuizAnswer({
      userId,
      ...input,
      at: dayKeyToInstant(input.answeredOn),
    });
  }

  /**
   * Les leçons déjà répondues, une entrée par leçon (la première fait foi).
   * C'est la lecture qui manquait : les réponses partaient au serveur sans
   * jamais se relire, et la progression mourait avec l'appareil.
   */
  listQuizAnswers(userId: string): Promise<QuizAnswerRecord[]> {
    return this.challenges.listQuizAnswers(userId);
  }
}
