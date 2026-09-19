import { Module } from '@nestjs/common';
import { UsersService } from './application/users.service';
import { UsersRepository } from './infrastructure/users.repository';
import { UsersController } from './presentation/http/users.controller';

@Module({
  controllers: [UsersController],
  providers: [UsersService, UsersRepository],
  // `UsersService` sort d'ici depuis que la génération de programme lit le
  // profil d'entraînement : elle a besoin de `training()`, qui assemble les
  // cinq entrées en UN instantané cohérent. Passer par le repository
  // obligerait à recopier cet assemblage, et deux copies finissent par
  // diverger — c'est exactement ce que le dépôt interdit.
  exports: [UsersRepository, UsersService],
})
export class UsersModule {}
