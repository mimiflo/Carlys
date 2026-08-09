import { Module } from '@nestjs/common';
import { NutritionService } from './application/nutrition.service';
import { NutritionRepository } from './infrastructure/nutrition.repository';
import { NutritionController } from './presentation/http/nutrition.controller';

@Module({
  controllers: [NutritionController],
  providers: [NutritionService, NutritionRepository],
  // Le coach lit les cibles métaboliques par ce service, jamais par Prisma.
  exports: [NutritionService],
})
export class NutritionModule {}
