/**
 * `node dist/cli/coach-bench [--url <api>] [--levels 1,5,10,25,50,100] [--question <texte>]
 *   [--timeout-ms 300000] [--keep] [--confirm]`
 *
 * Banc de charge du coach (ADR 0013) : combien de personnes le serveur
 * sert-il VRAIMENT en même temps ? Pas d'estimation — des demandes réelles,
 * par le chemin du téléphone (HTTP, SSE, file, modèle), palier par palier.
 *
 * Les comptes du banc (`coach-bench-<exécution>-<n>@carlys-bench.invalid`)
 * sont CRÉÉS à chaque exécution, jamais repris : une personne qui aurait
 * inscrit une telle adresse ne reçoit rien. Ils reçoivent le droit au coach
 * et une session, puis sont SUPPRIMÉS par identifiant à la fin, Ctrl-C
 * compris (sauf `--keep`) ; une exécution tuée net laisse des comptes sans
 * mot de passe, que la suivante retire. Aucun e-mail n'est envoyé. Le banc
 * OCCUPE le coach pendant la mesure : hors développement, il exige `--confirm`.
 *
 * 100 personnes au plus par palier : toutes les demandes partent de la même
 * adresse IP, et la limite générale de l'API (par IP et par route) fausserait
 * au-delà la colonne « Rythme ».
 */
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { AppConfigService } from '../config/app-config.service';
import { type Env, validateEnv } from '../config/env.schema';
import { TokenService } from '../modules/auth/application/token.service';
import { generateFriendCode } from '../modules/users/domain/friend-code';
import { type BenchSample, renderTable, summarize, type LevelReport } from './coach-bench.stats';
import { runCli } from './run-cli';

const EMAIL_PREFIX = 'coach-bench-';
const EMAIL_SUFFIX = '@carlys-bench.invalid';
const MAX_LEVEL = 100;

export interface BenchArgs {
  url: string;
  levels: number[];
  question: string;
  timeoutMs: number;
  keep: boolean;
  confirm: boolean;
}

export function parseBenchArgs(argv: readonly string[]): BenchArgs {
  const value = (flag: string) => {
    const index = argv.indexOf(flag);
    return index === -1 ? undefined : argv[index + 1];
  };
  const levels = (value('--levels') ?? '1,5,10,25,50,100')
    .split(',')
    .map((entry) => Number.parseInt(entry, 10))
    .filter((n) => Number.isInteger(n) && n > 0 && n <= MAX_LEVEL);
  if (levels.length === 0) {
    throw new Error(`--levels : des entiers de 1 à ${MAX_LEVEL}, séparés par des virgules`);
  }
  return {
    url: (value('--url') ?? 'http://localhost:3000').replace(/\/+$/, ''),
    levels,
    question:
      value('--question') ??
      'Donne-moi un conseil court pour mieux récupérer après une séance de jambes.',
    timeoutMs: Number.parseInt(value('--timeout-ms') ?? '300000', 10),
    keep: argv.includes('--keep'),
    confirm: argv.includes('--confirm'),
  };
}

interface BenchUser {
  userId: string;
  sessionId: string;
}

/** Un compte de banc NEUF, avec le droit au coach et une session d'un jour. */
async function benchUser(prisma: PrismaClient, runId: string, n: number): Promise<BenchUser> {
  const expiresAt = new Date(Date.now() + 86_400_000);
  const user = await prisma.user.create({
    data: {
      email: `${EMAIL_PREFIX}${runId}-${n}${EMAIL_SUFFIX}`,
      friendCode: generateFriendCode(),
      entitlements: { create: { entitlementKey: 'ai_coaching', isActive: true, expiresAt } },
    },
  });
  const session = await prisma.userSession.create({
    data: { userId: user.id, deviceName: 'coach-bench', expiresAt },
  });
  return { userId: user.id, sessionId: session.id };
}

/**
 * Les restes d'une exécution tuée net : comptes du domaine réservé SANS mot
 * de passe ni identité externe, donc jamais ceux d'une vraie personne, qui
 * s'inscrit toujours par l'un ou l'autre.
 */
function removeLeftovers(prisma: PrismaClient) {
  return prisma.user.deleteMany({
    where: {
      email: { startsWith: EMAIL_PREFIX, endsWith: EMAIL_SUFFIX },
      credential: null,
      externalIdentities: { none: {} },
    },
  });
}

/** Une question envoyée comme le téléphone l'envoie, mesurée de bout en bout. */
async function ask(args: BenchArgs, token: string): Promise<BenchSample> {
  const started = Date.now();
  const headers = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
  const conversationId = randomUUID();
  const signal = AbortSignal.timeout(args.timeoutMs);
  let firstTokenMs: number | null = null;
  let maxAhead: number | null = null;
  const sample = (outcome: BenchSample['outcome']): BenchSample => ({
    outcome,
    firstTokenMs,
    totalMs: Date.now() - started,
    maxAhead,
  });
  try {
    const created = await fetch(`${args.url}/api/v1/coach/conversations`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ id: conversationId }),
      signal,
    });
    if (!created.ok) return sample(outcomeOf(created.status, await errorCode(created)));
    const response = await fetch(
      `${args.url}/api/v1/coach/conversations/${conversationId}/messages/stream`,
      {
        method: 'POST',
        headers,
        body: JSON.stringify({ id: randomUUID(), content: args.question }),
        signal,
      },
    );
    if (!response.ok) return sample(outcomeOf(response.status, await errorCode(response)));
    const decoder = new TextDecoder();
    let buffer = '';
    for await (const chunk of response.body as unknown as AsyncIterable<Uint8Array>) {
      buffer += decoder.decode(chunk, { stream: true });
      let end: number;
      while ((end = buffer.indexOf('\n\n')) !== -1) {
        const block = buffer.slice(0, end);
        buffer = buffer.slice(end + 2);
        const event = /^event: (.*)$/m.exec(block)?.[1];
        const data = /^data: (.*)$/m.exec(block)?.[1] ?? 'null';
        if (event === 'queued') {
          const ahead = (JSON.parse(data) as { ahead: number }).ahead;
          maxAhead = Math.max(maxAhead ?? 0, ahead);
        } else if (event === 'delta' && firstTokenMs === null) {
          firstTokenMs = Date.now() - started;
        } else if (event === 'done') {
          return sample('ok');
        } else if (event === 'error') {
          const code = (JSON.parse(data) as { error?: { code?: string } }).error?.code;
          return sample(outcomeOf(code === 'SERVICE_BUSY' ? 503 : 500, code));
        }
      }
    }
    return sample('error');
  } catch {
    return sample(signal.aborted ? 'timeout' : 'error');
  }
}

async function errorCode(response: Response): Promise<string | undefined> {
  const body = (await response.json().catch(() => null)) as {
    error?: { code?: string };
  } | null;
  return body?.error?.code;
}

function outcomeOf(status: number, code: string | undefined): BenchSample['outcome'] {
  if (code === 'SERVICE_BUSY') return 'busy';
  if (status === 429 || code === 'RATE_LIMITED') return 'rate_limited';
  return 'error';
}

async function run(args: BenchArgs): Promise<number> {
  const env: Env = validateEnv(process.env);
  if (env.NODE_ENV === 'production' && !args.confirm) {
    process.stderr.write(
      'Le banc occupe le coach pendant toute la mesure. Sur un serveur, ajoute --confirm.\n',
    );
    return 2;
  }
  const config = new AppConfigService(new ConfigService<Env, true>(env));
  const prisma = new PrismaClient({ datasourceUrl: config.databaseUrl });
  const tokens = new TokenService(new JwtService(), config);
  const gateway = config.coachGateway;
  process.stdout.write(
    `Banc du coach sur ${args.url} — ${gateway.maxConcurrent} génération(s) à la fois, ` +
      `file de ${gateway.queueMaxSize}, attente max ${gateway.queueTimeoutMs / 1000} s.\n`,
  );
  const created: string[] = [];
  const cleanup = async () => {
    if (!args.keep) await prisma.user.deleteMany({ where: { id: { in: created } } });
  };
  // Ctrl-C ou `docker stop` : les comptes du banc partent quand même.
  const interrupted = (signal: NodeJS.Signals) => {
    process.stderr.write(`\n${signal} : suppression des comptes du banc…\n`);
    void cleanup()
      .catch((error: unknown) => {
        process.stderr.write(`Nettoyage raté : ${(error as Error).message}\n`);
      })
      .finally(() => process.exit(130));
  };
  process.once('SIGINT', interrupted);
  process.once('SIGTERM', interrupted);
  try {
    const { count } = await removeLeftovers(prisma);
    if (count > 0) process.stdout.write(`${count} compte(s) d'un banc interrompu retiré(s).\n`);
    const runId = randomUUID().slice(0, 8);
    const users: BenchUser[] = [];
    for (let n = 0; n < Math.max(...args.levels); n++) {
      const user = await benchUser(prisma, runId, n);
      created.push(user.userId);
      users.push(user);
    }
    const reports: LevelReport[] = [];
    for (const level of args.levels) {
      // Signés à chaque palier : un jeton d'accès vit 15 min, le banc davantage.
      const signed = await Promise.all(
        users.slice(0, level).map((u) => tokens.signAccessToken(u.userId, u.sessionId)),
      );
      const started = Date.now();
      const samples = await Promise.all(signed.map((token) => ask(args, token)));
      const report = summarize(level, samples, Date.now() - started);
      reports.push(report);
      process.stdout.write(`${renderTable([report]).split('\n')[2]}\n`);
    }
    process.stdout.write(`\n${renderTable(reports)}\n`);
    process.stdout.write(`\n${JSON.stringify(reports)}\n`);
    return 0;
  } finally {
    process.off('SIGINT', interrupted);
    process.off('SIGTERM', interrupted);
    await cleanup();
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  runCli(async (argv) => run(parseBenchArgs(argv)));
}
