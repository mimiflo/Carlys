import { Module } from '@nestjs/common';
import { CommunityService } from './application/community.service';
import { CommunityRepository } from './infrastructure/community.repository';
import { CommunityController } from './presentation/http/community.controller';

@Module({
  controllers: [CommunityController],
  providers: [CommunityService, CommunityRepository],
  // Exporté pour la clôture de séance (contribution aux défis SPORT).
  exports: [CommunityService],
})
export class CommunityModule {}
