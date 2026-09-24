process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = process.env.CARLYS_E2E_LOG ?? 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import { type ApiSuccessEnvelope, type AuthResult, type League } from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { type LeagueDivision, PrismaClient } from '@prisma/client';
import { randomInt, randomUUID } from 'node:crypto';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';
import { PrismaService } from '../src/database/prisma/prisma.service';
import { LEAGUE_GROUP_SIZE, periodKeyOf } from '../src/modules/community/domain/league-ladder';
import { LeaguesRepository } from '../src/modules/community/infrastructure/leagues.repository';

/**
 * LES GROUPES DE VINGT : on n'est classé qu'avec les membres de son groupe,
 * jamais avec toute une division mondiale.
 *
 * Ce qui se vérifie ici, contre PostgreSQL : deux ouvertures simultanées ne
 * remplissent jamais un groupe au-delà de vingt (le verrou transactionnel par
 * période et division), changer de division change de groupe (au règlement
 * comme à la lecture) sans jamais sauter une semaine déjà réglée, le
 * classement servi est celui du groupe du lecteur, et une personne bloquée en
 * est absente sans décaler les rangs.
 *
 * Les épreuves du dépôt travaillent sur des semaines de 2099 : aucune autre
 * suite n'y écrit, et aucune lecture de la semaine courante ne les voit.
 */
describe('Ligues — groupes de vingt (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let leagues: LeaguesRepository;
  const prefixe = `e2e-lg-${randomUUID()}`;

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const server = () => request(app.getHttpServer());

  /** Des comptes en base, sans passer par l'inscription : ils ne lisent rien. */
  const figurants = async (nombre: number, lettre: string) =>
    Promise.all(
      Array.from({ length: nombre }, (_, index) =>
        prisma.user.create({
          data: {
            email: `${prefixe}-${lettre}-${index}@carlys.test`,
            friendCode: `${lettre}${randomUUID().slice(0, 7)}`.toUpperCase(),
          },
        }),
      ),
    );

  /** Un seul figurant. */
  const un = async (lettre: string) => {
    const [user] = await figurants(1, lettre);
    if (user === undefined) {
      throw new Error('Figurant non créé.');
    }
    return user;
  };

  const inscrire = async (nom: string) =>
    data<AuthResult>(
      (
        await server()
          .post('/api/v1/auth/register')
          .send({
            email: `${prefixe}-${nom}@carlys.test`,
            password: 'MotDePasseSolide42',
            displayName: nom,
          })
          .expect(201)
      ).body,
    );

  /** Les membres de chaque groupe de (période, division). */
  const tailles = async (periodKey: string, division: LeagueDivision) => {
    const groupes = await prisma.leagueMembership.groupBy({
      by: ['cohort'],
      where: { periodKey, division },
      _count: { _all: true },
      orderBy: { cohort: 'asc' },
    });
    return Object.fromEntries(groupes.map((groupe) => [groupe.cohort, groupe._count._all]));
  };

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();
    leagues = app.get(LeaguesRepository);
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: { startsWith: prefixe } } });
    await prisma.$disconnect();
    await app.close();
  });

  it('dix ouvertures SIMULTANÉES ne remplissent jamais un groupe au-delà de vingt', async () => {
    const periode = '2099-W01';
    const deja = await figurants(LEAGUE_GROUP_SIZE - 1, 'A');
    await prisma.leagueMembership.createMany({
      data: deja.map((user) => ({ userId: user.id, periodKey: periode, division: 'DIAMANT' })),
    });
    const arrivants = await figurants(10, 'B');

    // La course est ÉLARGIE à dessein : une transaction à part tient la table
    // en mode SHARE, qui laisse lire mais retient toute insertion. Sans le
    // verrou du code, les dix ouvertures lisent donc TOUTES « 19 membres »
    // avant que la première n'écrive, et le groupe 0 finit à 29. Avec lui,
    // une seule compte à la fois, et chacune voit l'écriture de la
    // précédente. Sans cette retenue, la course ne se produit qu'au hasard
    // de l'ordonnancement, et un test vert ne prouverait rien.
    let liberer: () => void = () => undefined;
    const barriere = new Promise<void>((resolve) => {
      liberer = resolve;
    });
    let signaler: () => void = () => undefined;
    const tenue = new Promise<void>((resolve) => {
      signaler = resolve;
    });
    const retenue = prisma.$transaction(
      async (tx) => {
        await tx.$executeRaw`LOCK TABLE "LeagueMembership" IN SHARE MODE`;
        signaler();
        await barriere;
      },
      { timeout: 15_000 },
    );
    await tenue;

    const ouvertures = Promise.all(
      arrivants.map((user) => leagues.openPeriod(user.id, periode, 'DIAMANT')),
    );
    await new Promise((resolve) => setTimeout(resolve, 400));
    liberer();
    await retenue;
    await ouvertures;

    expect(await tailles(periode, 'DIAMANT')).toEqual({ 0: LEAGUE_GROUP_SIZE, 1: 9 });
  });

  it('une ouverture DANS une transaction (réponse de quiz) prend aussi sa place', async () => {
    const periode = '2099-W02';
    const deja = await figurants(LEAGUE_GROUP_SIZE, 'C');
    await prisma.leagueMembership.createMany({
      data: deja.map((user) => ({ userId: user.id, periodKey: periode, division: 'OR' })),
    });
    const arrivant = await un('D');

    // Deux fois dans la même transaction : la seconde retombe sur la ligne
    // existante, sans violation d'unicité qui avorterait la transaction.
    await app.get(PrismaService).$transaction(async (tx) => {
      await leagues.openPeriod(arrivant.id, periode, 'OR', tx);
      await leagues.openPeriod(arrivant.id, periode, 'OR', tx);
    });

    expect(await tailles(periode, 'OR')).toEqual({ 0: LEAGUE_GROUP_SIZE, 1: 1 });
  });

  it('le règlement qui fait MONTER change aussi de groupe dans la division d’arrivée', async () => {
    const reglee = '2099-W03';
    const suivante = '2099-W04';
    // La division d'arrivée a déjà un groupe plein.
    const pleins = await figurants(LEAGUE_GROUP_SIZE, 'E');
    await prisma.leagueMembership.createMany({
      data: pleins.map((user) => ({ userId: user.id, periodKey: suivante, division: 'OR' })),
    });
    // Ma semaine suivante a été ouverte trop tôt, dans l'ancienne division.
    const moi = await un('F');
    await prisma.leagueMembership.createMany({
      data: [
        { userId: moi.id, periodKey: reglee, division: 'ARGENT', score: 900 },
        { userId: moi.id, periodKey: suivante, division: 'ARGENT', score: 50 },
      ],
    });

    await leagues.settle(reglee, [{ userId: moi.id, rank: 1, nextDivision: 'OR' }]);

    const deplacee = await prisma.leagueMembership.findUniqueOrThrow({
      where: { userId_periodKey: { userId: moi.id, periodKey: suivante } },
    });
    expect(deplacee).toMatchObject({ division: 'OR', cohort: 1, score: 50 });
    expect(await tailles(suivante, 'OR')).toEqual({ 0: LEAGUE_GROUP_SIZE, 1: 1 });
  });

  it('régler une semaine TARDIVE ne réaligne rien au-delà d’une semaine déjà réglée', async () => {
    // Une ligne ouverte après coup (séance synchronisée en retard) dans une
    // semaine plus ancienne que ma dernière semaine réglée. Sa « suivante »
    // est cette semaine réglée, qui a déjà décidé de la suite : la semaine en
    // cours suit SA décision (Or), pas celle de la ligne tardive (Argent).
    const moi = await un('P');
    await prisma.leagueMembership.createMany({
      data: [
        { userId: moi.id, periodKey: '2098-W10', division: 'BRONZE', score: 900 },
        {
          userId: moi.id,
          periodKey: '2098-W11',
          division: 'ARGENT',
          score: 400,
          finalRank: 1,
          nextDivision: 'OR',
          settledAt: new Date(),
        },
        { userId: moi.id, periodKey: '2098-W12', division: 'OR', score: 30 },
      ],
    });

    await leagues.settle('2098-W10', [{ userId: moi.id, rank: 1, nextDivision: 'ARGENT' }]);

    const enCours = await prisma.leagueMembership.findUniqueOrThrow({
      where: { userId_periodKey: { userId: moi.id, periodKey: '2098-W12' } },
    });
    expect(enCours).toMatchObject({ division: 'OR', score: 30 });
  });

  it('le rangement à la lecture change aussi de groupe', async () => {
    const periode = '2099-W05';
    const pleins = await figurants(LEAGUE_GROUP_SIZE, 'G');
    await prisma.leagueMembership.createMany({
      data: pleins.map((user) => ({ userId: user.id, periodKey: periode, division: 'PLATINE' })),
    });
    const moi = await un('H');
    await prisma.leagueMembership.create({
      data: { userId: moi.id, periodKey: periode, division: 'OR', score: 70 },
    });

    expect(await leagues.placeInPeriod(moi.id, periode, 'PLATINE')).toBe(1);

    const rangee = await prisma.leagueMembership.findUniqueOrThrow({
      where: { userId_periodKey: { userId: moi.id, periodKey: periode } },
    });
    expect(rangee).toMatchObject({ division: 'PLATINE', cohort: 1, score: 70 });
    // Déjà à sa place : relire ne la déplace plus.
    expect(await leagues.placeInPeriod(moi.id, periode, 'PLATINE')).toBe(1);
  });

  it('le classement servi est celui de MON groupe, blocages tus sans décaler les rangs', async () => {
    const moi = await inscrire('lectrice');
    const bloqueuse = await inscrire('bloqueuse');
    await prisma.communityPreference.upsert({
      where: { userId: moi.user.id },
      create: { userId: moi.user.id, joinsLeague: true },
      update: { joinsLeague: true },
    });
    const periode = periodKeyOf(new Date());
    const monGroupe = randomInt(10_000, 2_000_000_000);
    const devant = await un('J');
    const bloquee = await un('K');
    const derriere = await un('L');
    const ailleurs = await un('M');

    // Mon groupe : devant (300), bloquée par moi (250), la bloqueuse (220),
    // moi (200), derrière (100). Un AUTRE groupe de la même division, avec
    // un score plus haut que tout le monde : il n'a rien à faire ici.
    await prisma.leagueMembership.createMany({
      data: [
        { userId: devant.id, score: 300, cohort: monGroupe },
        { userId: bloquee.id, score: 250, cohort: monGroupe },
        { userId: bloqueuse.user.id, score: 220, cohort: monGroupe },
        { userId: moi.user.id, score: 200, cohort: monGroupe },
        { userId: derriere.id, score: 100, cohort: monGroupe },
        { userId: ailleurs.id, score: 999, cohort: monGroupe + 1 },
      ].map((ligne) => ({ ...ligne, periodKey: periode, division: 'BRONZE' as const })),
    });

    const avant = data<League>(
      (
        await server()
          .get('/api/v1/community/league')
          .set('Authorization', `Bearer ${moi.tokens.accessToken}`)
          .expect(200)
      ).body,
    );
    expect(avant.standings.map((ligne) => ligne.userId)).toEqual([
      devant.id,
      bloquee.id,
      bloqueuse.user.id,
      moi.user.id,
      derriere.id,
    ]);

    // Je bloque l'une ; l'autre me bloque. Principe 6 : dans les deux sens,
    // la personne est absente de la liste.
    await server()
      .post(`/api/v1/community/blocks/${bloquee.id}`)
      .set('Authorization', `Bearer ${moi.tokens.accessToken}`)
      .expect(204);
    await server()
      .post(`/api/v1/community/blocks/${moi.user.id}`)
      .set('Authorization', `Bearer ${bloqueuse.tokens.accessToken}`)
      .expect(204);

    const apres = data<League>(
      (
        await server()
          .get('/api/v1/community/league')
          .set('Authorization', `Bearer ${moi.tokens.accessToken}`)
          .expect(200)
      ).body,
    );
    expect(apres.standings.map((ligne) => [ligne.userId, ligne.rank])).toEqual([
      [devant.id, 1],
      // Rangs 2 et 3 tus : un trou, pas un décalage.
      [moi.user.id, 4],
      [derriere.id, 5],
    ]);
    // La zone se lit toujours sur le groupe entier : trois joueurs devant
    // moi, donc dans la zone, et cinq joueurs actifs.
    expect(apres.promotion).toMatchObject({ activePlayers: 5, inZone: true });
  });
});
