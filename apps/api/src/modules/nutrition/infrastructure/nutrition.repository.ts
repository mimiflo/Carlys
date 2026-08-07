import { Injectable } from '@nestjs/common';
import { BodyMetricType, type UserProfile } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

@Injectable()
export class NutritionRepository {
  constructor(private readonly prisma: PrismaService) {}

  findProfile(userId: string): Promise<UserProfile | null> {
    return this.prisma.userProfile.findUnique({ where: { userId } });
  }

  /** Dernier poids connu (mesures corporelles non supprimées). */
  latestWeightKg(userId: string): Promise<number | null> {
    return this.prisma.bodyMetric
      .findFirst({
        where: {
          userId,
          metricType: BodyMetricType.WEIGHT_KG,
          deletedAt: null,
        },
        orderBy: { measuredAt: 'desc' },
        select: { value: true },
      })
      .then((metric) => (metric === null ? null : Number(metric.value)));
  }
}
