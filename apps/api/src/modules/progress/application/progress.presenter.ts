import { type BodyMetric as BodyMetricContract } from '@carlys/api-contracts';
import { type BodyMetric } from '@prisma/client';

/**
 * Une mesure corporelle, telle que le contrat la veut.
 *
 * Extraite le jour où les mesures ont pris leur propre service : deux
 * services, une seule mise en forme — la recopier aurait laissé un `value`
 * `Decimal` partir tel quel d'un côté et converti de l'autre.
 */
export function presentBodyMetric(metric: BodyMetric): BodyMetricContract {
  return {
    id: metric.id,
    metricType: metric.metricType,
    value: Number(metric.value),
    measuredAt: metric.measuredAt.toISOString(),
  };
}
