import {
  BODY_METRIC_BOUNDS,
  type BodyMetric as BodyMetricContract,
  type BodyMetricType,
} from '@carlys/api-contracts';
import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ProgressRepository } from '../infrastructure/progress.repository';
import { presentBodyMetric } from './progress.presenter';

/**
 * LES MESURES CORPORELLES : poids, taux de masse grasse et mensurations.
 *
 * Un service à part de `ProgressService` — qui porte les records, les
 * statistiques et la frise — parce que c'est le seul bloc de ce module qui
 * ÉCRIT ce que la personne saisit à la main, avec ses règles propres : id
 * venu de l'appareil, correction, suppression logique. Il a d'ailleurs déjà
 * son contrôleur (`body-metrics.controller.ts`).
 */
@Injectable()
export class BodyMetricsService {
  constructor(private readonly progress: ProgressRepository) {}

  /** Création idempotente (id généré côté client). */
  async addBodyMetric(
    userId: string,
    input: { id: string; metricType: BodyMetricType; value: number; measuredAt: Date },
  ): Promise<BodyMetricContract> {
    assertPlausible(input.metricType, input.value);
    const created = await this.progress.createBodyMetric({ userId, ...input });
    const stored = await this.progress.findBodyMetricById(input.id);
    if (stored === null || stored.userId !== userId) {
      if (!created && stored !== null) {
        throw new ConflictException('Identifiant de mesure déjà utilisé.');
      }
      throw new NotFoundException('Mesure introuvable.');
    }
    return presentBodyMetric(stored);
  }

  async listBodyMetrics(
    userId: string,
    metricType: BodyMetricType,
    limit: number,
  ): Promise<BodyMetricContract[]> {
    const metrics = await this.progress.listBodyMetrics(userId, metricType, limit);
    // Servies du plus ancien au plus récent (prêt pour les graphiques).
    return metrics.reverse().map(presentBodyMetric);
  }

  /**
   * Corrige une mesure existante.
   *
   * CE QUE CETTE CORRECTION DÉPLACE, ET QU'IL FAUT SAVOIR : le rapport
   * métabolique (métabolisme de base, dépense, cible calorique, protéines,
   * eau, IMC) est calculé à partir du DERNIER poids non supprimé, choisi par
   * `measuredAt` décroissant. Corriger une valeur change donc les objectifs
   * nutritionnels ; corriger une DATE peut changer QUELLE mesure fait foi,
   * même si aucune valeur ne bouge. C'est voulu — une mesure fausse doit
   * cesser de peser —, mais ce n'est pas anodin, et un test e2e le tient.
   *
   * Contrairement à la suppression, la correction n'est PAS idempotente au
   * sens « aboutit toujours » : corriger une mesure inconnue ou déjà
   * supprimée est une erreur, pas un succès silencieux. Le client viserait
   * une ligne qui n'existe plus et croirait sa correction enregistrée.
   */
  async updateBodyMetric(
    userId: string,
    id: string,
    input: { value?: number; measuredAt?: Date },
  ): Promise<BodyMetricContract> {
    if (input.value === undefined && input.measuredAt === undefined) {
      throw new BadRequestException('Rien à corriger : donne au moins la valeur ou la date.');
    }
    const metric = await this.progress.findBodyMetricById(id);
    // Une mesure qui appartient à quelqu'un d'autre est INTROUVABLE, jamais
    // « interdite » : un 403 confirmerait que cet identifiant existe.
    if (metric === null || metric.userId !== userId || metric.deletedAt !== null) {
      throw new NotFoundException('Mesure introuvable.');
    }
    if (input.value !== undefined) {
      // Les bornes de la zone STOCKÉE : le corps ne porte pas le type.
      assertPlausible(metric.metricType, input.value);
    }
    const updated = await this.progress.updateBodyMetric(id, input);
    return presentBodyMetric(updated);
  }

  /** Idempotent : supprimer une mesure déjà supprimée ou inconnue aboutit. */
  async deleteBodyMetric(userId: string, id: string): Promise<void> {
    const metric = await this.progress.findBodyMetricById(id);
    if (metric === null) {
      return;
    }
    if (metric.userId !== userId) {
      throw new NotFoundException('Mesure introuvable.');
    }
    if (metric.deletedAt !== null) {
      return;
    }
    await this.progress.softDeleteBodyMetric(id);
  }
}

/**
 * Les bornes de `BODY_METRIC_BOUNDS`, que le DTO ne peut pas appliquer : il
 * valide le corps seul, et une correction ne porte pas le type. Le refus a
 * la forme d'une erreur de validation (`VALIDATION_ERROR`, champ `value`),
 * comme celles du DTO, pour que le client le place sous le même champ.
 */
function assertPlausible(metricType: BodyMetricType, value: number): void {
  const { min, max, decimals } = BODY_METRIC_BOUNDS[metricType];
  const scaled = value * 10 ** decimals;
  // Tolérance flottante : 38.4 * 10 vaut 383.99999999999994.
  const precise = Math.abs(scaled - Math.round(scaled)) < 1e-6;
  if (value >= min && value <= max && precise) {
    return;
  }
  const unit = metricType.endsWith('_CM') ? ' cm' : '';
  const places = decimals > 1 ? `${decimals} décimales` : 'une décimale';
  const message = `La valeur doit être comprise entre ${min} et ${max}${unit}, à ${places} au plus.`;
  throw new BadRequestException({ message, details: [{ field: 'value', message }] });
}
