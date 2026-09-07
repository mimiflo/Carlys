import { type INestApplication } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

/** Une route telle que le document OpenAPI la décrit : `GET /api/v1/…`. */
export type RouteSignature = string;

/**
 * Toutes les routes DÉCLARÉES par l'API, lues sur le document OpenAPI —
 * la même source que `/api/docs`, produite comme dans `main.ts`.
 *
 * Aucune initialisation d'application n'est nécessaire : `createDocument`
 * inspecte le conteneur de modules, il ne parle ni à PostgreSQL ni à Redis.
 */
export function declaredRoutes(app: INestApplication): RouteSignature[] {
  const document = SwaggerModule.createDocument(
    app,
    new DocumentBuilder().setTitle('Carlys API').setVersion('1.0').addBearerAuth().build(),
  );

  const routes: RouteSignature[] = [];
  for (const [path, item] of Object.entries(document.paths)) {
    for (const method of Object.keys(item ?? {})) {
      routes.push(`${method.toUpperCase()} ${path}`);
    }
  }
  return routes.sort();
}
