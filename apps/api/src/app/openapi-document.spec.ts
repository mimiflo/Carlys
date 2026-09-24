// Valeurs factices : ce test n'ouvre aucune connexion (pas d'`init()`), il
// lit le document que `main.ts` publierait.
process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-de-test-uniquement-32-caracteres-min';

import { type INestApplication } from '@nestjs/common';
import { DocumentBuilder, type OpenAPIObject, SwaggerModule } from '@nestjs/swagger';
import { Test } from '@nestjs/testing';
import { AppModule } from './app.module';

/**
 * CE QUE CE FICHIER PROTÈGE : aucun champ d'un corps ou d'une requête n'est
 * annoncé comme un OBJET VIDE dans `/api/docs`.
 *
 * Sans plugin Swagger, le type d'une propriété vient de `design:type`, que
 * TypeScript émet `Object` pour toute union avec `null` sous
 * `strictNullChecks` : `string | null` sortait en `"type": "object"`, sans
 * propriétés. La relecture en a trouvé dans les programmes, les modèles de
 * séance et les repas, après en avoir corrigé dans la communauté : une
 * correction DTO par DTO ne tient pas, il faut lire le document ENTIER.
 *
 * Même assemblage que `app.module.spec.ts` : le module racine compilé, sans
 * `init()`, donc sans PostgreSQL, Redis ni stockage objet.
 */

/** Ce que le test lit d'un schéma : le reste du document ne le concerne pas. */
interface Schema {
  type?: string;
  $ref?: string;
  properties?: Record<string, Schema>;
  items?: Schema;
  allOf?: Schema[];
  oneOf?: Schema[];
  anyOf?: Schema[];
  additionalProperties?: boolean | Schema;
}

/** Un objet VIDE : `type: object` sans rien qui en dise la forme. */
function isShapelessObject(schema: Schema): boolean {
  return (
    schema.type === 'object' &&
    schema.properties === undefined &&
    schema.$ref === undefined &&
    schema.additionalProperties === undefined
  );
}

/**
 * Les chemins (`Dto.champ`, `GET /route ?param`) des propriétés de requête
 * annoncées comme un objet vide, en suivant les `$ref` jusqu'au bout.
 */
function shapelessRequestProperties(document: OpenAPIObject): string[] {
  const schemas = (document.components?.schemas ?? {}) as Record<string, Schema>;
  const found = new Set<string>();
  const visited = new Set<string>();

  const visit = (schema: Schema | undefined, where: string): void => {
    if (schema === undefined) {
      return;
    }
    if (schema.$ref !== undefined) {
      const name = schema.$ref.split('/').pop() ?? schema.$ref;
      if (!visited.has(name)) {
        visited.add(name);
        visit(schemas[name], name);
      }
      return;
    }
    for (const [field, property] of Object.entries(schema.properties ?? {})) {
      if (isShapelessObject(property)) {
        found.add(`${where}.${field}`);
      }
      visit(property, `${where}.${field}`);
    }
    if (schema.items !== undefined) {
      if (isShapelessObject(schema.items)) {
        found.add(`${where}[]`);
      }
      visit(schema.items, `${where}[]`);
    }
    for (const member of [
      ...(schema.allOf ?? []),
      ...(schema.oneOf ?? []),
      ...(schema.anyOf ?? []),
    ]) {
      visit(member, where);
    }
  };

  for (const [path, operations] of Object.entries(document.paths)) {
    for (const [verb, operation] of Object.entries(operations as Record<string, unknown>)) {
      const op = operation as {
        requestBody?: { content?: Record<string, { schema?: Schema }> };
        parameters?: Array<{ name?: string; schema?: Schema }>;
      };
      const route = `${verb.toUpperCase()} ${path}`;
      for (const content of Object.values(op.requestBody?.content ?? {})) {
        visit(content.schema, route);
      }
      for (const parameter of op.parameters ?? []) {
        if (parameter.schema !== undefined && isShapelessObject(parameter.schema)) {
          found.add(`${route} ?${parameter.name ?? ''}`);
        }
        visit(parameter.schema, `${route} ?${parameter.name ?? ''}`);
      }
    }
  }
  return [...found].sort();
}

describe('Document OpenAPI de l’application entière', () => {
  let app: INestApplication;
  let document: OpenAPIObject;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    document = SwaggerModule.createDocument(
      app,
      new DocumentBuilder().setTitle('Carlys API').addBearerAuth().build(),
    );
  });

  afterAll(async () => {
    await app.close();
  });

  it('couvre bien les corps de requête (le test lit quelque chose)', () => {
    // Garde du garde : un document vide passerait le test suivant sans rien
    // prouver.
    expect(Object.keys(document.components?.schemas ?? {}).length).toBeGreaterThan(50);
  });

  it('aucune propriété de requête n’est un objet vide', () => {
    expect(shapelessRequestProperties(document)).toEqual([]);
  });

  it('le détecteur voit un `string | null` sans type explicite', () => {
    // La sonde du détecteur lui-même : sans elle, un parcours qui ne suivrait
    // plus les `$ref` rendrait une liste vide pour de mauvaises raisons.
    const sonde: OpenAPIObject = {
      openapi: '3.0.0',
      info: { title: 'sonde', version: '1' },
      paths: {
        '/sonde': {
          post: {
            responses: {},
            requestBody: {
              content: { 'application/json': { schema: { $ref: '#/components/schemas/Sonde' } } },
            },
          },
        },
      },
      components: {
        schemas: {
          Sonde: {
            type: 'object',
            properties: {
              nom: { type: 'object' },
              lignes: { type: 'array', items: { $ref: '#/components/schemas/Ligne' } },
            },
          },
          Ligne: { type: 'object', properties: { note: { type: 'object' } } },
        },
      },
    };
    expect(shapelessRequestProperties(sonde)).toEqual(['Ligne.note', 'Sonde.nom']);
  });
});
