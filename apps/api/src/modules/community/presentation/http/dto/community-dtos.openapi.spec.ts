import { Body, Controller, type INestApplication, Post } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { Test } from '@nestjs/testing';
import { CreateFriendChallengeDto } from './community.dto';
import { CreateCommunityReportDto } from './community-moderation.dto';

/**
 * CE QUE CE FICHIER PROTÈGE : Swagger décrit les champs `string | null`
 * comme des CHAÎNES.
 *
 * Sans plugin Swagger, le type d'une propriété vient de `design:type`, que
 * TypeScript émet… `Object` pour toute union avec `null` sous
 * `strictNullChecks`. `encouragementId`, élargi à `string | null`, était
 * ainsi passé de `string` à `object` dans `/api/docs`, entraînant avec lui
 * les deux champs neufs. Rien ne le voyait : aucun test ne lisait le
 * document produit. Celui-ci le produit comme `main.ts`, sur une sonde qui
 * reçoit les deux corps — sans base ni Redis.
 */

/** Ce que le test lit d'un schéma : le reste du document ne le concerne pas. */
interface SchemaLu {
  properties?: Record<string, Record<string, unknown>>;
  required?: string[];
}

@Controller('sonde')
class SondeController {
  @Post('defi')
  defi(@Body() body: CreateFriendChallengeDto): CreateFriendChallengeDto {
    return body;
  }

  @Post('signalement')
  signalement(@Body() body: CreateCommunityReportDto): CreateCommunityReportDto {
    return body;
  }
}

describe('DTO de la communauté — le document OpenAPI', () => {
  let app: INestApplication;
  let schemas: Record<string, SchemaLu>;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ controllers: [SondeController] }).compile();
    app = moduleRef.createNestApplication();
    const document = SwaggerModule.createDocument(
      app,
      new DocumentBuilder().setTitle('Carlys API').build(),
    );
    schemas = (document.components?.schemas ?? {}) as Record<string, SchemaLu>;
  });

  afterAll(async () => {
    await app.close();
  });

  const propriete = (dto: string, champ: string): Record<string, unknown> | undefined =>
    schemas[dto]?.properties?.[champ];

  it.each([['encouragementId'], ['friendChallengeId']])(
    'signalement : %s est un uuid facultatif, nullable — pas un objet',
    (champ) => {
      expect(propriete('CreateCommunityReportDto', champ)).toMatchObject({
        type: 'string',
        format: 'uuid',
        nullable: true,
      });
      expect(schemas.CreateCommunityReportDto?.required ?? []).not.toContain(champ);
    },
  );

  it('défi : message est une chaîne facultative, nullable, bornée', () => {
    expect(propriete('CreateFriendChallengeDto', 'message')).toMatchObject({
      type: 'string',
      nullable: true,
      maxLength: 280,
    });
    expect(schemas.CreateFriendChallengeDto?.required ?? []).not.toContain('message');
  });
});
