import { type AuthSession } from '@carlys/api-contracts';
import {
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Req,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import {
  type AuthenticatedPrincipal,
  clientContextOf,
} from '../../../../common/types/authenticated-request';
import { type RequestWithId } from '../../../../common/types/request-with-id';
import { SessionsService } from '../../application/sessions.service';

@ApiTags('auth')
@ApiBearerAuth()
@Controller('auth/sessions')
export class SessionsController {
  constructor(private readonly sessions: SessionsService) {}

  @Get()
  @ApiOperation({ summary: 'Appareils connectés (sessions actives)' })
  list(@CurrentUser() user: AuthenticatedPrincipal): Promise<AuthSession[]> {
    return this.sessions.list(user.userId, user.sessionId);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: "Déconnexion d'un appareil" })
  async revoke(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) sessionId: string,
    @Req() request: RequestWithId,
  ): Promise<void> {
    await this.sessions.revokeOne(user.userId, sessionId, clientContextOf(request));
  }

  @Delete()
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Déconnexion de tous les autres appareils' })
  async revokeOthers(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Req() request: RequestWithId,
  ): Promise<void> {
    await this.sessions.revokeOthers(user.userId, user.sessionId, clientContextOf(request));
  }
}
