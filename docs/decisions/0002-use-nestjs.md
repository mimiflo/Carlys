# ADR 0002 — NestJS pour l'API backend

## Statut

Acceptée — 2026-08

## Contexte

L'API de Carlys doit servir l'application mobile et le tableau de bord admin,
avec des exigences fortes dès l'Étape 1 : configuration validée au démarrage,
observabilité (logs corrélés par `requestId`, métriques Prometheus), sécurité
(Helmet, rate limiting, validation stricte des entrées), documentation OpenAPI,
et une structure qui supportera les étapes suivantes (authentification, files de
tâches, webhooks Stripe) sans réécriture. Le monorepo est déjà en TypeScript
strict côté admin (`apps/admin`, Next.js) et packages partagés — le backend doit
pouvoir réutiliser cet écosystème (`@carlys/api-contracts`, `@carlys/shared-config`).

## Décision

L'API (`apps/api`) est développée avec **NestJS 11** sur Node.js ≥ 22, en
TypeScript strict, organisée en modules par domaine au sein d'un monolithe
modulaire (ADR 0004).

## Raisons

- **TypeScript partagé** : mêmes types, mêmes schémas Zod (`packages/api-contracts`),
  même configuration ESLint/TS (`packages/eslint-config`, `packages/typescript-config`)
  que l'admin Next.js — un seul langage côté serveur et web.
- **Modules et injection de dépendances** : NestJS impose des frontières nettes
  entre domaines (santé, config, redis…) et rend les services testables par
  substitution — exactement la structure requise par le monolithe modulaire.
- **Écosystème intégré** : Prisma (ORM PostgreSQL), Swagger (`@nestjs/swagger`,
  exposé sur `/api/docs` hors production), throttling (`@nestjs/throttler`),
  logs Pino (`nestjs-pino`), et BullMQ prévu pour les tâches asynchrones — tout
  s'intègre par modules officiels ou éprouvés.
- Alternatives écartées :
  - **Express nu** : aucune structure imposée ; DI, validation, versioning et
    modularité seraient à réinventer maison, au détriment de la cohérence.
  - **Fastify seul** : excellent runtime HTTP mais même problème de structure ;
    NestJS peut d'ailleurs adopter l'adaptateur Fastify plus tard si le débit
    l'exige (aujourd'hui : `@nestjs/platform-express`).
  - **Go** : performances supérieures, mais perte du partage TypeScript avec
    l'admin et les contrats, et écosystème Prisma/Swagger/validation moins
    intégré pour notre cas d'usage CRUD + temps différé.

## Avantages

- Conventions fortes : contrôleurs, services, guards, interceptors, pipes — le
  code reste homogène à mesure que les tranches verticales s'ajoutent.
- Versioning URI natif (`/api/v1`) et enveloppes de réponse uniformes
  (`{ data, meta, requestId }` / `{ error: … }`) faciles à imposer globalement.
- Testabilité : Jest unitaire + e2e déjà en place (l'e2e `/health/live` passe
  sans infrastructure).
- Validation stricte de bout en bout : Zod au démarrage (`src/config/env.schema.ts`,
  refus de démarrer si une variable essentielle manque) et class-validator en
  `whitelist` + `forbidNonWhitelisted` sur les DTO.

## Inconvénients

- Couche d'abstraction et décorateurs : courbe d'apprentissage réelle et une
  part de « magie » (metadata, `reflect-metadata`) qui peut masquer le flux
  d'exécution.
- Débit brut inférieur à Fastify nu ou Go — acceptable pour notre charge cible,
  et l'adaptateur Fastify reste une porte de sortie.
- Deux mondes de validation cohabitent (Zod pour la config et les contrats,
  class-validator pour les DTO HTTP) : discipline nécessaire pour éviter la
  divergence.

## Conséquences

- Chaque nouveau domaine (auth à l'Étape 2, exercices à l'Étape 3…) est un
  module NestJS avec ses contrôleurs, services et tests, sans dépendances
  circulaires entre domaines.
- Prisma est le point d'accès unique à PostgreSQL (ADR 0003) ; Redis (ioredis)
  sert au cache et servira à BullMQ.
- Le build de production passe par le Dockerfile multi-stage (contexte racine du
  monorepo) et la CI `api-ci.yml` (format, lint, typecheck, tests, e2e, build,
  `prisma validate`, détection de migrations manquantes).
