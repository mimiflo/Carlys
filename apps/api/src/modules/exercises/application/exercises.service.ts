import {
  type Equipment,
  type ExerciseDetail,
  type ExerciseSummary,
  type MuscleGroup,
} from '@carlys/api-contracts';
import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { AppConfigService } from '../../../config/app-config.service';
import { CacheService } from '../../../infrastructure/cache/cache.service';
import { EntitlementsService } from '../../subscriptions/application/entitlements.service';
import {
  ExercisesRepository,
  type ListExercisesFilters,
} from '../infrastructure/exercises.repository';
import {
  presentEquipment,
  presentExerciseDetail,
  presentExerciseSummary,
  presentMuscleGroup,
} from './exercise.presenter';

export interface ExercisesPage {
  items: ExerciseSummary[];
  nextCursor: string | null;
  hasMore: boolean;
}

/** Préfixe commun : l'invalidation du catalogue purge tout d'un coup. */
const CACHE_PREFIX = 'catalog:';
const LIST_TTL_SECONDS = 300;
const DETAIL_TTL_SECONDS = 3_600;
const REFERENCE_TTL_SECONDS = 3_600;

@Injectable()
export class ExercisesService {
  constructor(
    private readonly exercises: ExercisesRepository,
    private readonly cache: CacheService,
    private readonly entitlements: EntitlementsService,
    private readonly config: AppConfigService,
  ) {}

  async list(
    filters: ListExercisesFilters,
    limit: number,
    cursor?: string,
  ): Promise<ExercisesPage> {
    const cacheKey = this.listCacheKey(filters, limit, cursor);
    const cached = await this.cache.getJson<ExercisesPage>(cacheKey);
    if (cached !== null) {
      return cached;
    }

    const rows = await this.exercises.listPage(filters, limit, cursor);
    const hasMore = rows.length > limit;
    const items = rows
      .slice(0, limit)
      .map((row) => presentExerciseSummary(row, this.config.s3PublicBaseUrl));
    const page: ExercisesPage = {
      items,
      hasMore,
      nextCursor: hasMore ? (items.at(-1)?.id ?? null) : null,
    };

    await this.cache.setJson(cacheKey, page, LIST_TTL_SECONDS);
    return page;
  }

  /**
   * Fiche complète. Le cache est PARTAGÉ (clé par exercice) : la décision
   * d'accès premium — décidée côté serveur, par utilisateur — est prise
   * APRÈS la lecture du cache, jamais mise en cache.
   */
  async detail(idOrSlug: string, userId: string): Promise<ExerciseDetail> {
    const cacheKey = `${CACHE_PREFIX}exercise:${idOrSlug.toLowerCase()}`;
    let detail = await this.cache.getJson<ExerciseDetail>(cacheKey);

    if (detail === null) {
      const exercise = await this.exercises.findPublishedByIdOrSlug(idOrSlug);
      if (exercise === null) {
        throw new NotFoundException('Exercice introuvable.');
      }
      detail = presentExerciseDetail(exercise, this.config.s3PublicBaseUrl);
      await this.cache.setJson(cacheKey, detail, DETAIL_TTL_SECONDS);
    }

    if (detail.isPremium) {
      const allowed = await this.entitlements.hasEntitlement(userId, 'premium_exercises');
      if (!allowed) {
        throw new ForbiddenException('Exercice réservé aux membres Premium.');
      }
    }
    return detail;
  }

  async muscleGroups(): Promise<MuscleGroup[]> {
    const cacheKey = `${CACHE_PREFIX}muscle-groups`;
    const cached = await this.cache.getJson<MuscleGroup[]>(cacheKey);
    if (cached !== null) {
      return cached;
    }
    const groups = (await this.exercises.listMuscleGroups()).map(presentMuscleGroup);
    await this.cache.setJson(cacheKey, groups, REFERENCE_TTL_SECONDS);
    return groups;
  }

  async equipment(): Promise<Equipment[]> {
    const cacheKey = `${CACHE_PREFIX}equipment`;
    const cached = await this.cache.getJson<Equipment[]>(cacheKey);
    if (cached !== null) {
      return cached;
    }
    const equipment = (await this.exercises.listEquipment()).map(presentEquipment);
    await this.cache.setJson(cacheKey, equipment, REFERENCE_TTL_SECONDS);
    return equipment;
  }

  /** À appeler après toute mutation du catalogue (seed, admin — Étape 7). */
  invalidateCache(): Promise<void> {
    return this.cache.invalidatePrefix(CACHE_PREFIX);
  }

  private listCacheKey(filters: ListExercisesFilters, limit: number, cursor?: string): string {
    const normalized = JSON.stringify({
      search: filters.search?.trim().toLowerCase() ?? null,
      muscleGroup: filters.muscleGroupSlug ?? null,
      equipment: filters.equipmentSlug ?? null,
      difficulty: filters.difficulty ?? null,
      type: filters.type ?? null,
      limit,
      cursor: cursor ?? null,
    });
    return `${CACHE_PREFIX}exercises:${Buffer.from(normalized).toString('base64url')}`;
  }
}
