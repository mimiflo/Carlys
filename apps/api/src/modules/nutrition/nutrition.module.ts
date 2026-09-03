import { Module } from '@nestjs/common';
import { MealsService } from './application/meals.service';
import { NutritionService } from './application/nutrition.service';
import { MealsRepository } from './infrastructure/meals.repository';
import { NutritionRepository } from './infrastructure/nutrition.repository';
import { MealsController } from './presentation/http/meals.controller';
import { NutritionController } from './presentation/http/nutrition.controller';

@Module({
  controllers: [NutritionController, MealsController],
  providers: [NutritionService, NutritionRepository, MealsService, MealsRepository],
  // Le coach lit les cibles métaboliques et le journal alimentaire par ces
  // services, jamais par Prisma.
  exports: [NutritionService, MealsService],
})
export class NutritionModule {}
