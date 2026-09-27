import { API_GLOBAL_PREFIX, API_VERSION, MAX_JSON_BODY_SIZE } from '@carlys/shared-config';
import { ValidationPipe, VersioningType } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import express from 'express';
import helmet from 'helmet';
import { AppConfigService } from '../config/app-config.service';
import { requestIdMiddleware } from '../common/utilities/request-id';
import { validationExceptionFactory } from '../common/validation/validation-exception.factory';
import { HttpMetricsMiddleware } from '../modules/metrics/http-metrics.middleware';

/**
 * Configuration HTTP partagée entre le bootstrap réel (main.ts) et les tests
 * end-to-end, pour garantir que les tests exercent la même application.
 */
export function configureApp(app: NestExpressApplication): void {
  const config = app.get(AppConfigService);

  // ── Identifiant de corrélation, AVANT TOUT ──────────────────────────────
  // Une requête que refuse un parseur de corps, helmet ou CORS n'atteint
  // jamais pino-http (intergiciel de module, posé par Nest à l'init, donc
  // après ceux-ci) : sans ce premier intergiciel, sa réponse d'erreur portait
  // `requestId: "unknown"` et aucun en-tête x-request-id. Détail :
  // common/utilities/request-id.ts.
  app.use(requestIdMiddleware);

  // ── Mesure du trafic, EN PREMIER ────────────────────────────────────────
  //
  // POURQUOI PAS `MiddlewareConsumer.forRoutes()`. C'était la première
  // rédaction ; l'essai l'a prise en défaut sur les deux points qui comptent.
  // Nest attache les intergiciels AU ROUTEUR, une fois par liaison, et le
  // préfixe global de cette fonction (`setGlobalPrefix` avec ses exclusions)
  // en crée deux. Mesuré sur trois requêtes, avec les quatre écritures de
  // joker acceptées par Express 5 (`{*chemin}`, `*`, `/*chemin`, `(.*)`) —
  // résultat identique pour les quatre :
  //
  //   GET /health/live      → l'intergiciel passe DEUX fois (route exclue du
  //                           préfixe : elle correspond aux deux liaisons)
  //   GET /api/v1/users/me  → une fois
  //   GET /zzz-inconnu      → JAMAIS (aucune route, donc aucune liaison)
  //
  // Soit exactement les deux fautes qu'une métrique ne doit pas commettre :
  // un débit doublé sur une partie des routes, et l'aveuglement complet sur
  // les 404 — précisément le signal d'un balayage hostile ou d'un client
  // désynchronisé. Posé ici, sur l'instance Express elle-même, l'intergiciel
  // voit chaque requête une fois et une seule, routée ou non.
  //
  // Avant helmet et avant le parseur de corps brut : ce qu'ils rejettent est
  // du trafic aussi, et leur latence fait partie de celle qu'on mesure.
  const httpMetrics = app.get(HttpMetricsMiddleware);
  app.use(httpMetrics.use.bind(httpMetrics));

  // Derrière un reverse proxy, `req.ip` vaudrait l'adresse du proxy pour TOUT
  // le trafic : la limitation de débit (ThrottlerGuard) et l'audit ne
  // verraient plus qu'une seule adresse. Le verrouillage de compte, lui, n'en
  // dépend pas — il s'indexe sur l'identité, `lockout.reserveAttempt(email)`.
  //
  // On fait confiance à exactement TRUST_PROXY_HOPS sauts — jamais `true`,
  // qui accepterait un X-Forwarded-For entièrement forgé. Attention toutefois
  // à ce qu'un compteur numérique NE fait PAS : il ne retire des entrées que
  // par la DROITE, donc tout ce qu'un client PRÉFIXE à l'en-tête survit. La
  // protection vient du proxy de tête, qui doit ÉCRASER X-Forwarded-For
  // (`$remote_addr`) et non y ajouter. Mesuré : docs/security/reverse-proxy.md.
  app.set('trust proxy', config.trustProxyHops);

  app.use(helmet());
  app.enableCors({
    origin: config.corsOrigins,
    credentials: true,
  });

  // Webhooks de paiement : le corps BRUT est indispensable à la vérification
  // de signature — ce middleware doit précéder tout parseur JSON (l'ordre
  // d'enregistrement fait foi : les parseurs sont posés juste après).
  app.use(
    `/${API_GLOBAL_PREFIX}/v${API_VERSION}/webhooks`,
    express.raw({ type: () => true, limit: MAX_JSON_BODY_SIZE }),
  );

  // ── Parseurs JSON et urlencoded, APRÈS le parseur brut des webhooks ─────
  //
  // Ils vivaient dans main.ts, après l'appel à cette fonction : les tests
  // e2e, qui n'exécutent pas main.ts, tournaient donc avec le parseur par
  // défaut de Nest — limité à 100 Ko au lieu de 1 Mo, et posé ailleurs dans
  // la chaîne. Aucun e2e ne pouvait voir un défaut de limite de corps ni
  // d'ordre des intergiciels. Posés ici, ils sont les mêmes partout : Nest
  // n'ajoute pas les siens à l'init quand un `jsonParser` et un
  // `urlencodedParser` sont déjà en place (`isMiddlewareApplied`), et main.ts
  // crée de toute façon l'application avec `bodyParser: false`.
  app.useBodyParser('json', { limit: MAX_JSON_BODY_SIZE });
  app.useBodyParser('urlencoded', { extended: true, limit: MAX_JSON_BODY_SIZE });

  app.setGlobalPrefix(API_GLOBAL_PREFIX, {
    exclude: ['health', 'health/live', 'health/ready', 'metrics'],
  });
  app.enableVersioning({
    type: VersioningType.URI,
    defaultVersion: API_VERSION,
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      // Sans cette fabrique, le pipe n'aplatit que des phrases : le filtre
      // d'exceptions ne sait plus à quel CHAMP les rattacher, et
      // `details[].field` — publié au contrat, lu par le client mobile —
      // restait vide depuis l'origine.
      exceptionFactory: validationExceptionFactory,
    }),
  );

  app.enableShutdownHooks();
}
