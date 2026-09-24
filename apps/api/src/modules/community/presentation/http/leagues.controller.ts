import { type League } from '@carlys/api-contracts';
import { Controller, Delete, Get, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import { type AuthenticatedPrincipal } from '../../../../common/types/authenticated-request';
import { LeaguesService } from '../../application/leagues.service';

/**
 * La ligue — un contrôleur à part, et pas trois routes de plus chez les
 * défis : ce sont deux domaines qui ne partagent qu'une couture d'écriture,
 * et le contrôleur des défis porte déjà deux familles.
 */
@ApiTags('community')
@ApiBearerAuth()
@Controller('community/league')
export class LeaguesController {
  constructor(private readonly leagues: LeaguesService) {}

  @Get()
  @ApiOperation({
    summary: 'Ma ligue de la semaine, classement compris',
    description:
      'Sans adhésion, rend l’échelle et un classement VIDE : la ligue est un ' +
      'opt-in. Le classement est celui du GROUPE de 20 de l’appelant dans sa ' +
      'division, sans les personnes qu’un blocage sépare de lui (rangs ' +
      'inchangés). La période échue est RÉGLÉE à la lecture (rangs figés, ' +
      'division suivante décidée), sans tâche planifiée ; `lastResult` rend ' +
      'le résultat de la semaine passée toute la semaine, quel que soit le ' +
      'lecteur qui l’a réglée. `promotion` situe l’appelant face à la zone ' +
      'de montée de son groupe, calculé par le serveur avec la règle du ' +
      'règlement (`null` sans adhésion).',
  })
  read(@CurrentUser() user: AuthenticatedPrincipal): Promise<League> {
    return this.leagues.read(user.userId);
  }

  @Post('join')
  @ApiOperation({
    summary: 'Entrer dans la ligue — le geste EST le consentement',
    description:
      'Réglage distinct de `sharesProgress`, qui ne décide que de ce qu’un ' +
      'AMI voit de ta progression.',
  })
  join(@CurrentUser() user: AuthenticatedPrincipal): Promise<League> {
    return this.leagues.setJoined(user.userId, true);
  }

  @Delete('join')
  @ApiOperation({
    summary: 'Sortir de la ligue : le compte s’arrête',
    description:
      'La semaine en cours se règle normalement ; aucune période n’est ' + 'ouverte ensuite.',
  })
  leave(@CurrentUser() user: AuthenticatedPrincipal): Promise<League> {
    return this.leagues.setJoined(user.userId, false);
  }
}
