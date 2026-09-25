import { Module } from '@nestjs/common';
import { PrivateStorageModule } from '../../infrastructure/storage/private-storage.module';
import { FoodsService } from './application/foods.service';
import { MealComposer } from './application/meal-composer';
import { MealPhotoObjects } from './application/meal-photo-objects';
import { MealPhotosService } from './application/meal-photos.service';
import { MealsService } from './application/meals.service';
import { NutritionService } from './application/nutrition.service';
import { FoodsRepository } from './infrastructure/foods.repository';
import { MealPhotosRepository } from './infrastructure/meal-photos.repository';
import { MealsRepository } from './infrastructure/meals.repository';
import { NutritionRepository } from './infrastructure/nutrition.repository';
import { FoodsController } from './presentation/http/foods.controller';
import { MealPhotosController } from './presentation/http/meal-photos.controller';
import { MealsController } from './presentation/http/meals.controller';
import { NutritionController } from './presentation/http/nutrition.controller';

/**
 * Importe `PrivateStorageModule` pour la photo d'un repas : bucket PRIVÉ,
 * jamais celui des médias publics (`MediaModule`).
 */
@Module({
  imports: [PrivateStorageModule],
  controllers: [NutritionController, MealsController, MealPhotosController, FoodsController],
  providers: [
    NutritionService,
    NutritionRepository,
    MealsService,
    MealsRepository,
    MealComposer,
    MealPhotosService,
    MealPhotosRepository,
    MealPhotoObjects,
    FoodsService,
    FoodsRepository,
  ],
  // Le coach lit les cibles métaboliques et le journal alimentaire par ces
  // services, jamais par Prisma. La suppression de compte efface les photos
  // de repas par `MealPhotosService`.
  exports: [NutritionService, MealsService, MealPhotosService],
})
export class NutritionModule {}
