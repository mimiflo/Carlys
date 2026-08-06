import { Body, Controller, Delete, HttpCode, HttpStatus, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiProperty, ApiTags } from '@nestjs/swagger';
import { IsNotEmpty, IsString, MaxLength } from 'class-validator';
import { PASSWORD_MAX_LENGTH } from '@carlys/api-contracts';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import {
  type AuthenticatedPrincipal,
  clientContextOf,
} from '../../../../common/types/authenticated-request';
import { type RequestWithId } from '../../../../common/types/request-with-id';
import { AccountService } from '../../application/account.service';

export class DeleteAccountDto {
  @ApiProperty({ description: 'Mot de passe actuel, exigé pour confirmer.' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(PASSWORD_MAX_LENGTH)
  password!: string;
}

@ApiTags('users')
@ApiBearerAuth()
@Controller('users')
export class AccountController {
  constructor(private readonly account: AccountService) {}

  @Delete('me')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Suppression du compte (mot de passe requis, sessions révoquées)' })
  async deleteAccount(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Body() dto: DeleteAccountDto,
    @Req() request: RequestWithId,
  ): Promise<void> {
    await this.account.deleteAccount(user.userId, dto.password, clientContextOf(request));
  }
}
