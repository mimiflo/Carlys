process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = process.env.CARLYS_E2E_LOG ?? 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import { type ApiSuccessEnvelope, type AuthResult, type League } from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
import { randomInt, randomUUID } from 'node:crypto';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';
import { LeaguesService } from '../src/modules/community/application/leagues.service';
import {
  periodKeyOf,
  periodWindow,
  previousPeriodKey,
  settleDivision,
} from '../src/modules/community/domain/league-ladder';
import { LeaguesRepository } from '../src/modules/community/infrastructure/leagues.repository';

/**
 * La semaine qui précède celle d'aujourd'hui : c'est la seule dont le
 * résultat est annoncé (`lastResult`).
 */
const semainePassee = () => previousPeriodKey(periodKeyOf(new Date()));

/**
 * Un groupe à part pour chaque épreuve qui pose ses propres lignes : le
 * classement et le règlement se font PAR GROUPE, donc des lignes laissées par
 * une autre suite dans la même semaine ne s'y mêlent jamais.
 */
const groupeAPart = () => randomInt(10_000, 2_000_000_000);

/**
 * LES LIGUES : un classement hebdomadaire, CHOISI, qui ne rend rien au profil.
 *
 * Ce qui se vérifie ici : rien n'est compté tant qu'on n'a pas rejoint (le
 * « périmètre choisi » du principe 5), l'effort se convertit selon le barème
 * au lieu de s'additionner brut, et une période échue se règle À LA LECTURE,
 * sans tâche planifiée.
 */
describe('Ligues (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let token: string;
  let userId: string;
  const email = `e2e-league-${randomUUID()}@carlys.test`;

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const server = () => request(app.getHttpServer());
  const as = (bearer: string) => ({
    get: (url: string) => server().get(url).set('Authorization', `Bearer ${bearer}`),
    post: (url: string) => server().post(url).set('Authorization', `Bearer ${bearer}`),
    delete: (url: string) => server().delete(url).set('Authorization', `Bearer ${bearer}`),
  });

  /** Une séance de course de `metres`, du début à la clôture. */
  const courir = async (metres: number) => {
    const sessionId = randomUUID();
    await as(token)
      .post('/api/v1/workout-sessions')
      .send({ id: sessionId, startedAt: new Date().toISOString() })
      .expect(201);
    await as(token)
      .post(`/api/v1/workout-sessions/${sessionId}/sets`)
      .send({
        id: randomUUID(),
        exerciseName: 'Course',
        position: 0,
        distanceMeters: metres,
        completedAt: new Date().toISOString(),
      })
      .expect(201);
    await as(token).post(`/api/v1/workout-sessions/${sessionId}/complete`).send({}).expect(200);
  };

  const ligue = async () =>
    data<League>((await as(token).get('/api/v1/community/league').expect(200)).body);

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();

    const inscrite = data<AuthResult>(
      (
        await server()
          .post('/api/v1/auth/register')
          .send({ email, password: 'MotDePasseSolide42', displayName: 'Ligueuse' })
          .expect(201)
      ).body,
    );
    token = inscrite.tokens.accessToken;
    userId = inscrite.user.id;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email } });
    await prisma.$disconnect();
    await app.close();
  });

  it('sans adhésion, rien n’est compté et le classement est VIDE', async () => {
    const avant = await ligue();
    expect(avant.joined).toBe(false);
    expect(avant.division).toBe('BRONZE');
    expect(avant.standings).toEqual([]);
    // Ni zone de montée : elle se lit sur un classement qu'on ne voit pas.
    expect(avant.promotion).toBeNull();

    // Une séance faite AVANT d'avoir rejoint ne crée aucune ligne : c'est le
    // « périmètre CHOISI » — on n'est classé qu'après avoir dit oui.
    await courir(5_000);
    expect(await prisma.leagueMembership.count({ where: { userId } })).toBe(0);
  });

  it('rejoindre ouvre la période, et l’effort s’y convertit en POINTS', async () => {
    const entree = data<League>(
      (await as(token).post('/api/v1/community/league/join').expect(201)).body,
    );
    expect(entree.joined).toBe(true);
    expect(entree.score).toBe(0);
    expect(entree.periodKey).toMatch(/^\d{4}-W\d{2}$/);
    // Le barème voyage avec la réponse, et un score nul n'est jamais dans
    // la zone : il lui manque au moins un point.
    expect(entree.promotion).toMatchObject({
      promotedCount: 5,
      minPlayers: 10,
      topDivision: false,
      inZone: false,
    });
    expect(entree.promotion?.pointsToZone).toBeGreaterThanOrEqual(1);

    // Une séance de 5 km : 50 points pour la séance, 50 pour les 5 000 m
    // (un point par tranche de 100). Les mètres bruts écraseraient les
    // séances de deux ordres de grandeur — c'est tout l'objet du barème.
    await courir(5_000);
    const apres = await ligue();
    expect(apres.score).toBe(100);
    expect(apres.standings.find((ligne) => ligne.isMe)?.score).toBe(100);
    expect(apres.standings.find((ligne) => ligne.isMe)?.rank).toBe(1);
    // Première de sa division : dans la zone, au sens du RANG — seule, la
    // semaine ne comptera pas encore, et c'est `activePlayers` qui le dit.
    expect(apres.promotion).toMatchObject({ inZone: true, pointsToZone: 0 });
    expect(apres.promotion?.activePlayers).toBeGreaterThanOrEqual(1);
  });

  it('le reste d’une conversion n’est JAMAIS reporté', async () => {
    const avant = (await ligue()).score;
    // 149 mètres : un point, pas 1,49. Le reste n'est pas gardé pour la
    // prochaine séance — le reporter rendrait le score dépendant de l'ordre
    // des écritures.
    await courir(149);
    expect((await ligue()).score).toBe(avant + 51);
  });

  it('une période échue se règle À LA LECTURE, et la montée survit', async () => {
    // La semaine passée, seule au classement : moins de dix joueurs, donc
    // personne ne bouge — un classement à une personne ne décide de rien.
    const semaineEchue = semainePassee();
    await prisma.leagueMembership.create({
      data: {
        userId,
        periodKey: semaineEchue,
        division: 'ARGENT',
        cohort: groupeAPart(),
        score: 320,
      },
    });

    const vue = await ligue();

    const reglee = await prisma.leagueMembership.findUniqueOrThrow({
      where: { userId_periodKey: { userId, periodKey: semaineEchue } },
    });
    expect(reglee.settledAt).not.toBeNull();
    expect(reglee.finalRank).toBe(1);
    expect(reglee.nextDivision).toBe('ARGENT');
    expect(vue.lastResult).toEqual({
      periodKey: semaineEchue,
      rank: 1,
      from: 'ARGENT',
      to: 'ARGENT',
    });

    // Relire ne règle pas deux fois (l'écriture est conditionnée à
    // `settledAt: null`), mais le résultat reste servi : la phrase dit « la
    // semaine passée », elle est vraie toute la semaine.
    expect((await ligue()).lastResult).toEqual(vue.lastResult);
    const relue = await prisma.leagueMembership.findUniqueOrThrow({
      where: { userId_periodKey: { userId, periodKey: semaineEchue } },
    });
    expect(relue.settledAt).toEqual(reglee.settledAt);
  });

  it('une semaine plus ancienne se règle aussi, mais n’est PAS annoncée', async () => {
    // Six semaines d'absence : la dernière semaine jouée n'est pas « la
    // semaine passée ». Elle se règle (rien ne reste en suspens), sans
    // qu'aucune phrase ne l'annonce.
    const prefixe = `e2e-league-ancienne-${randomUUID()}`;
    const revenante = data<AuthResult>(
      (
        await server()
          .post('/api/v1/auth/register')
          .send({
            email: `${prefixe}@carlys.test`,
            password: 'MotDePasseSolide42',
            displayName: 'Revenante',
          })
          .expect(201)
      ).body,
    );
    try {
      const ancienne = periodKeyOf(new Date(Date.now() - 6 * 7 * 86_400_000));
      await prisma.communityPreference.create({
        data: { userId: revenante.user.id, joinsLeague: true },
      });
      await prisma.leagueMembership.create({
        data: {
          userId: revenante.user.id,
          periodKey: ancienne,
          division: 'OR',
          cohort: groupeAPart(),
          score: 200,
        },
      });

      const vue = data<League>(
        (await as(revenante.tokens.accessToken).get('/api/v1/community/league').expect(200)).body,
      );

      expect(vue.lastResult).toBeNull();
      expect(vue.division).toBe('OR');
      const reglee = await prisma.leagueMembership.findUniqueOrThrow({
        where: { userId_periodKey: { userId: revenante.user.id, periodKey: ancienne } },
      });
      expect(reglee.settledAt).not.toBeNull();
    } finally {
      await prisma.user.deleteMany({ where: { email: { startsWith: prefixe } } });
    }
  });

  it('un effort arrivé APRÈS le règlement ne fait plus bouger le classement', async () => {
    const figee = await prisma.leagueMembership.findFirstOrThrow({
      where: { userId, settledAt: { not: null } },
    });
    const avant = figee.score;

    // Le dépôt refuse d'écrire sur une période réglée : un classement déjà
    // annoncé ne se corrige pas parce qu'une séance se synchronise en retard.
    await prisma.leagueMembership.updateMany({
      where: { userId, periodKey: figee.periodKey, settledAt: null },
      data: { score: { increment: 500 } },
    });
    const apres = await prisma.leagueMembership.findUniqueOrThrow({
      where: { userId_periodKey: { userId, periodKey: figee.periodKey } },
    });
    expect(apres.score).toBe(avant);
  });

  it(
    'une séance qui ouvre la semaine AVANT le règlement ne fait pas perdre la ' + 'montée',
    async () => {
      // Le cas de chaque lundi : première place la semaine passée, douze
      // joueurs actifs, et la première séance de la semaine arrive AVANT que
      // quiconque ait relu la ligue. La séance ouvrait alors la semaine dans
      // l'ancienne division (la semaine passée, pas encore réglée, n'avait
      // pas de division suivante), puis le règlement décidait la montée…
      // qu'aucune ligne n'appliquait plus.
      const prefixe = `e2e-league-montee-${randomUUID()}`;
      const precedente = semainePassee();
      const groupe = groupeAPart();
      const moi = data<AuthResult>(
        (
          await server()
            .post('/api/v1/auth/register')
            .send({
              email: `${prefixe}-moi@carlys.test`,
              password: 'MotDePasseSolide42',
              displayName: 'Première',
            })
            .expect(201)
        ).body,
      );
      try {
        // Adhérente SANS lecture : rejoindre par l'API lirait la ligue, et
        // réglerait la semaine passée avant la séance — pas le cas testé.
        await prisma.communityPreference.upsert({
          where: { userId: moi.user.id },
          create: { userId: moi.user.id, joinsLeague: true },
          update: { joinsLeague: true },
        });
        const autres = await Promise.all(
          Array.from({ length: 11 }, (_, index) =>
            prisma.user.create({
              data: {
                email: `${prefixe}-${index}@carlys.test`,
                friendCode: `M${randomUUID().slice(0, 7)}`.toUpperCase(),
              },
            }),
          ),
        );
        await prisma.leagueMembership.createMany({
          data: [
            {
              userId: moi.user.id,
              periodKey: precedente,
              division: 'OR',
              cohort: groupe,
              score: 900,
            },
            ...autres.map((autre, index) => ({
              userId: autre.id,
              periodKey: precedente,
              division: 'OR' as const,
              cohort: groupe,
              score: 100 + index,
            })),
          ],
        });

        // La séance d'abord…
        const sessionId = randomUUID();
        await as(moi.tokens.accessToken)
          .post('/api/v1/workout-sessions')
          .send({ id: sessionId, startedAt: new Date().toISOString() })
          .expect(201);
        await as(moi.tokens.accessToken)
          .post(`/api/v1/workout-sessions/${sessionId}/complete`)
          .send({})
          .expect(200);

        // … puis la lecture, qui règle la semaine passée.
        const vue = data<League>(
          (await as(moi.tokens.accessToken).get('/api/v1/community/league').expect(200)).body,
        );

        expect(vue.lastResult).toEqual({
          periodKey: precedente,
          rank: 1,
          from: 'OR',
          to: 'PLATINE',
        });
        expect(vue.division).toBe('PLATINE');
        const courante = await prisma.leagueMembership.findUniqueOrThrow({
          where: { userId_periodKey: { userId: moi.user.id, periodKey: vue.periodKey } },
        });
        expect(courante.division).toBe('PLATINE');
        // Et la séance déjà versée reste comptée, dans la bonne division.
        expect(courante.score).toBeGreaterThan(0);
      } finally {
        await prisma.user.deleteMany({ where: { email: { startsWith: prefixe } } });
      }
    },
  );

  it('le règlement fait par UN AUTRE réaligne aussi ma semaine ouverte trop tôt', async () => {
    // Le règlement d'une division vient de la première lecture, quelle
    // qu'elle soit. Si c'est un autre membre qui relit la ligue, ma semaine
    // déjà ouverte (dans l'ancienne division) doit suivre la décision sans
    // attendre que je relise la mienne.
    const prefixe = `e2e-league-realign-${randomUUID()}`;
    const precedente = semainePassee();
    const groupe = groupeAPart();
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
    const moi = await inscrire('moi');
    const temoin = await inscrire('temoin');
    try {
      const autres = await Promise.all(
        Array.from({ length: 10 }, (_, index) =>
          prisma.user.create({
            data: {
              email: `${prefixe}-${index}@carlys.test`,
              friendCode: `R${randomUUID().slice(0, 7)}`.toUpperCase(),
            },
          }),
        ),
      );
      await prisma.communityPreference.createMany({
        data: [moi.user.id, temoin.user.id].map((userId) => ({ userId, joinsLeague: true })),
      });
      await prisma.leagueMembership.createMany({
        data: [
          {
            userId: moi.user.id,
            periodKey: precedente,
            division: 'ARGENT',
            cohort: groupe,
            score: 900,
          },
          {
            userId: temoin.user.id,
            periodKey: precedente,
            division: 'ARGENT',
            cohort: groupe,
            score: 50,
          },
          ...autres.map((autre, index) => ({
            userId: autre.id,
            periodKey: precedente,
            division: 'ARGENT' as const,
            cohort: groupe,
            score: 100 + index,
          })),
        ],
      });

      const sessionId = randomUUID();
      await as(moi.tokens.accessToken)
        .post('/api/v1/workout-sessions')
        .send({ id: sessionId, startedAt: new Date().toISOString() })
        .expect(201);
      await as(moi.tokens.accessToken)
        .post(`/api/v1/workout-sessions/${sessionId}/complete`)
        .send({})
        .expect(200);

      // C'est le TÉMOIN qui relit : son règlement couvre toute la division.
      const vueTemoin = data<League>(
        (await as(temoin.tokens.accessToken).get('/api/v1/community/league').expect(200)).body,
      );

      const maSemaine = await prisma.leagueMembership.findUniqueOrThrow({
        where: { userId_periodKey: { userId: moi.user.id, periodKey: vueTemoin.periodKey } },
      });
      expect(maSemaine.division).toBe('OR');
      expect(maSemaine.score).toBeGreaterThan(0);

      // Le témoin, dernier des joueurs, lit SON résultat : il descend.
      expect(vueTemoin.lastResult).toEqual({
        periodKey: precedente,
        rank: 12,
        from: 'ARGENT',
        to: 'BRONZE',
      });
      // Et moi, qui n'ai rien réglé du tout, je lis ENSUITE le mien : le
      // règlement d'un autre ne me prive plus de « te voilà en Or ».
      const maVue = data<League>(
        (await as(moi.tokens.accessToken).get('/api/v1/community/league').expect(200)).body,
      );
      expect(maVue.lastResult).toEqual({
        periodKey: precedente,
        rank: 1,
        from: 'ARGENT',
        to: 'OR',
      });
      expect(maVue.division).toBe('OR');
    } finally {
      await prisma.user.deleteMany({ where: { email: { startsWith: prefixe } } });
    }
  });

  it(
    'deux semaines échues : la montée de l’avant-dernière déplace la dernière, et UNE ' +
      'lecture règle et annonce la dernière',
    async () => {
      // Personne n'a relu la ligue pendant la semaine passée, ouverte trop
      // tôt (par une séance) dans l'ancienne division. Régler l'avant-dernière
      // fait monter et réaligne la semaine passée : autre division, autre
      // groupe. La lecture réglait ensuite la semaine passée avec la ligne lue
      // AVANT ce réalignement — l'ancien groupe, sans moi : ma semaine passée
      // restait en suspens, et aucun résultat n'était annoncé.
      const prefixe = `e2e-league-deux-${randomUUID()}`;
      const passee = semainePassee();
      const avantDerniere = previousPeriodKey(passee);
      const groupe = groupeAPart();
      const moi = data<AuthResult>(
        (
          await server()
            .post('/api/v1/auth/register')
            .send({
              email: `${prefixe}-moi@carlys.test`,
              password: 'MotDePasseSolide42',
              displayName: 'Grimpeuse',
            })
            .expect(201)
        ).body,
      );
      try {
        await prisma.communityPreference.create({
          data: { userId: moi.user.id, joinsLeague: true },
        });
        const autres = await Promise.all(
          Array.from({ length: 11 }, (_, index) =>
            prisma.user.create({
              data: {
                email: `${prefixe}-${index}@carlys.test`,
                friendCode: `D${randomUUID().slice(0, 7)}`.toUpperCase(),
              },
            }),
          ),
        );
        await prisma.leagueMembership.createMany({
          data: [
            {
              userId: moi.user.id,
              periodKey: avantDerniere,
              division: 'ARGENT',
              cohort: groupe,
              score: 900,
            },
            ...autres.map((autre, index) => ({
              userId: autre.id,
              periodKey: avantDerniere,
              division: 'ARGENT' as const,
              cohort: groupe,
              score: 100 + index,
            })),
            // Ouverte trop tôt, dans l'ancienne division.
            {
              userId: moi.user.id,
              periodKey: passee,
              division: 'ARGENT',
              cohort: groupeAPart(),
              score: 50,
            },
          ],
        });

        const vue = data<League>(
          (await as(moi.tokens.accessToken).get('/api/v1/community/league').expect(200)).body,
        );

        const montee = await prisma.leagueMembership.findUniqueOrThrow({
          where: { userId_periodKey: { userId: moi.user.id, periodKey: avantDerniere } },
        });
        expect(montee.nextDivision).toBe('OR');
        // La semaine passée a suivi la montée, ET elle est réglée par cette
        // seule lecture : son résultat est annoncé tout de suite.
        const derniere = await prisma.leagueMembership.findUniqueOrThrow({
          where: { userId_periodKey: { userId: moi.user.id, periodKey: passee } },
        });
        expect(derniere.division).toBe('OR');
        expect(derniere.settledAt).not.toBeNull();
        expect(vue.lastResult).toEqual({
          periodKey: passee,
          rank: derniere.finalRank,
          from: 'OR',
          to: derniere.nextDivision,
        });
        // Et la semaine en cours s'ouvre dans la division RÉGLÉE.
        expect(vue.division).toBe(derniere.nextDivision);
      } finally {
        await prisma.user.deleteMany({ where: { email: { startsWith: prefixe } } });
      }
    },
  );

  it('une ligne TARDIVE dans une semaine réglée ne réécrit rien des autres', async () => {
    // Une séance synchronisée après coup ouvre la semaine close d'un nouveau
    // membre, dans un groupe DÉJÀ réglé. La régler ne doit toucher qu'elle :
    // le règlement réécrivait les rangs et les divisions suivantes du groupe
    // entier, et annulait après coup une montée déjà annoncée.
    const prefixe = `e2e-league-tardive-${randomUUID()}`;
    // Une semaine lointaine où aucune autre suite n'écrit : la ligne tardive
    // y entre dans le groupe 0, le premier qui a de la place.
    const semaine = '2001-W10';
    const autres = await Promise.all(
      Array.from({ length: 12 }, (_, index) =>
        prisma.user.create({
          data: {
            email: `${prefixe}-${index}@carlys.test`,
            friendCode: `T${randomUUID().slice(0, 7)}`.toUpperCase(),
          },
        }),
      ),
    );
    const tardive = data<AuthResult>(
      (
        await server()
          .post('/api/v1/auth/register')
          .send({
            email: `${prefixe}-tardive@carlys.test`,
            password: 'MotDePasseSolide42',
            displayName: 'Tardive',
          })
          .expect(201)
      ).body,
    );
    try {
      await prisma.leagueMembership.createMany({
        data: autres.map((autre, index) => ({
          userId: autre.id,
          periodKey: semaine,
          division: 'BRONZE' as const,
          score: 300 - 20 * index,
        })),
      });
      const repository = app.get(LeaguesRepository);
      await repository.settle(
        semaine,
        settleDivision('BRONZE', await repository.standings(semaine, 'BRONZE', 0)),
      );
      const annonces = await prisma.leagueMembership.findMany({
        where: { periodKey: semaine, userId: { in: autres.map((autre) => autre.id) } },
        select: { userId: true, finalRank: true, nextDivision: true, settledAt: true },
        orderBy: { userId: 'asc' },
      });
      // Le cinquième, à 220 points, monte : c'est ce qui est annoncé.
      expect(annonces.filter((ligne) => ligne.nextDivision === 'ARGENT')).toHaveLength(5);

      // 5 séances, 250 points : la tardive passerait QUATRIÈME du groupe, et
      // le cinquième annoncé (220) serait sixième, donc plus promu.
      await prisma.communityPreference.create({
        data: { userId: tardive.user.id, joinsLeague: true },
      });
      await app
        .get(LeaguesService)
        .contribute(
          tardive.user.id,
          'WORKOUTS',
          5,
          new Date(periodWindow(semaine).startsAt.getTime() + 86_400_000),
        );
      await as(tardive.tokens.accessToken).get('/api/v1/community/league').expect(200);

      // Les résultats déjà annoncés n'ont pas bougé d'un cran.
      expect(
        await prisma.leagueMembership.findMany({
          where: { periodKey: semaine, userId: { in: autres.map((autre) => autre.id) } },
          select: { userId: true, finalRank: true, nextDivision: true, settledAt: true },
          orderBy: { userId: 'asc' },
        }),
      ).toEqual(annonces);
      // La tardive, elle, est réglée sur le groupe tel qu'il est.
      expect(
        await prisma.leagueMembership.findUniqueOrThrow({
          where: { userId_periodKey: { userId: tardive.user.id, periodKey: semaine } },
        }),
      ).toMatchObject({ cohort: 0, score: 250, finalRank: 4, nextDivision: 'ARGENT' });
    } finally {
      await prisma.user.deleteMany({ where: { email: { startsWith: prefixe } } });
    }
  });

  it('sortir arrête le compte, sans effacer la semaine en cours', async () => {
    const avant = (await ligue()).score;
    const sortie = data<League>(
      (await as(token).delete('/api/v1/community/league/join').expect(200)).body,
    );
    expect(sortie.joined).toBe(false);
    expect(sortie.standings).toEqual([]);
    expect(sortie.promotion).toBeNull();

    await courir(5_000);
    // La ligne de la semaine existe toujours, avec son score d'avant : la
    // sortie arrête le compte, elle ne réécrit pas le passé.
    const courante = await prisma.leagueMembership.findFirstOrThrow({
      where: { userId, settledAt: null },
      orderBy: { periodKey: 'desc' },
    });
    expect(courante.score).toBe(avant);
  });
});
