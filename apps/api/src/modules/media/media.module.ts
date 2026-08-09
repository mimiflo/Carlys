import { Module } from '@nestjs/common';
import { StorageService } from '../../infrastructure/storage/storage.service';
import { AdminModule } from '../admin/admin.module';
import { ExercisesModule } from '../exercises/exercises.module';
import { MediaService } from './application/media.service';
import { MediaRepository } from './infrastructure/media.repository';
import {
  AdminExerciseMediaController,
  MediaController,
} from './presentation/http/media.controller';

/**
 * Bibliothèque de médias.
 *
 * Importe `AdminModule` pour ses gardes : le dépôt de fichiers est une action
 * d'administration, soumise au même RBAC et au même audit que le reste.
 * Importe `ExercisesModule` pour invalider le cache du catalogue dès qu'une
 * illustration change — sinon la nouvelle photo attendrait une heure.
 */
@Module({
  imports: [AdminModule, ExercisesModule],
  controllers: [MediaController, AdminExerciseMediaController],
  providers: [MediaService, MediaRepository, StorageService],
  exports: [StorageService],
})
export class MediaModule {}
