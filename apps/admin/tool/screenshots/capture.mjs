#!/usr/bin/env node
// Harnais de captures d'écran du back-office Carlys.
//
// Il photographie chaque page de l'admin, en clair et en sombre, avec une
// API FACTICE : toute requête vers http://api.mock est interceptée par
// Playwright et reçoit une réponse validée par les contrats Zod partagés
// (`@carlys/api-contracts`). Aucune API, aucune base, aucun Redis à lancer.
//
// 1. Serveur de développement de l'admin, pointé vers l'API factice :
//
//      NEXT_PUBLIC_API_BASE_URL=http://api.mock pnpm --filter @carlys/admin dev
//
//    (`@carlys/api-contracts` doit être construit : `pnpm build` le fait.)
//
// 2. Playwright n'est PAS une dépendance du dépôt : `playwright-core` s'installe
//    à part, et le Chromium préinstallé sert (aucun `playwright install`) :
//
//      npm i --prefix <dossier> playwright-core@1.56.1
//      PW_MODULE_DIR=<dossier> node apps/admin/tool/screenshots/capture.mjs [sortie]
//
//    `PW_MODULE_DIR` est OBLIGATOIRE (le dossier où playwright-core est installé) ;
//    `CHROMIUM_PATH` (défaut /opt/pw-browsers/chromium) et `ADMIN_URL`
//    (défaut http://localhost:3001) se règlent de même.
//
// Sortie : `<viewport>-<thème>-<page>.png` (ex. desktop-light-users.png).
// Le script échoue (code 1) si une page affiche une erreur de contrat ou de
// chargement, si une réponse factice viole son contrat, ou si une requête
// vers l'API n'a pas de réponse prévue ; les erreurs de console sont listées.

import { mkdirSync, readFileSync } from 'node:fs';
import os from 'node:os';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as D from './donnees.mjs';

const ICI = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(ICI, '../../../..');
const PW_DIR = process.env.PW_MODULE_DIR;
if (PW_DIR === undefined || PW_DIR === '') {
  console.error(
    'PW_MODULE_DIR manque : le dossier où `npm i --prefix <dossier> playwright-core` a été lancé.',
  );
  process.exit(1);
}
const CHROMIUM = process.env.CHROMIUM_PATH ?? '/opt/pw-browsers/chromium';
const ADMIN = process.env.ADMIN_URL ?? 'http://localhost:3001';
const SORTIE = path.resolve(process.argv[2] ?? path.join(os.tmpdir(), 'carlys-admin-captures'));

const { chromium } = createRequire(path.join(PW_DIR, 'noop.js'))('playwright-core');
const C = createRequire(path.join(ICI, '../../package.json'))('@carlys/api-contracts');
const { z } = createRequire(path.join(ICI, '../../package.json'))('zod');

// ── API factice ───────────────────────────────────────────────────────────

const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, content-type',
  'access-control-allow-methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
};

const page = (items, schema) => ({
  data: items,
  meta: { nextCursor: null, hasMore: false, total: items.length },
  schema: z.array(schema),
});
const one = (data, schema) => ({ data, schema });

/** Une route factice : [méthode, motif du chemin, (correspondance, requête, options) => réponse]. */
const ROUTES = [
  [
    'GET',
    /^\/health$/,
    (_m, _r, o) => ({
      raw: D.health(o.degrade),
      status: o.degrade ? 503 : 200,
      schema: C.healthReportSchema,
    }),
  ],
  ['GET', /^\/api\/v1\/admin\/auth\/me$/, () => one(D.ADMIN_ME, C.adminMeSchema)],
  [
    'POST',
    /^\/api\/v1\/admin\/auth\/login$/,
    () => one({ challengeToken: 'defi-factice' }, C.adminLoginChallengeSchema),
  ],
  ['GET', /^\/api\/v1\/admin\/overview$/, () => one(D.OVERVIEW, C.adminOverviewSchema)],
  [
    'POST',
    /^\/api\/v1\/admin\/users\/search$/,
    (_m, req, o) => {
      const corps = req.postDataJSON() ?? {};
      const terme = (corps.search ?? '').toLowerCase();
      // Comme l'API : les comptes supprimés n'y sont que sur demande.
      const trouves = D.USERS.filter(
        (u) =>
          (corps.includeDeleted === true || u.status !== 'DELETED') &&
          `${u.email} ${u.displayName ?? ''}`.toLowerCase().includes(terme),
      );
      return page(o.usersEmpty ? [] : trouves, C.managedUserSummarySchema);
    },
  ],
  [
    'GET',
    /^\/api\/v1\/admin\/users\/([^/]+)$/,
    (m) => one(D.userDetail(m[1]), C.managedUserDetailSchema),
  ],
  [
    'GET',
    /^\/api\/v1\/admin\/community\/reports$/,
    (_m, req) => {
      const status = new URL(req.url()).searchParams.get('status');
      return page(
        D.REPORTS.filter((r) => status === null || r.status === status),
        C.adminCommunityReportSchema,
      );
    },
  ],
  [
    'GET',
    /^\/api\/v1\/admin\/exercises$/,
    (_m, req) => {
      const avecSupprimes = new URL(req.url()).searchParams.get('includeDeleted') === 'true';
      return page(
        D.EXERCISES.filter((e) => avecSupprimes || e.deletedAt === null),
        C.adminExerciseSummarySchema,
      );
    },
  ],
  [
    'GET',
    /^\/api\/v1\/admin\/muscle-groups$/,
    () => one(D.MUSCLE_GROUPS, z.array(C.adminMuscleGroupSchema)),
  ],
  ['GET', /^\/api\/v1\/admin\/equipment$/, () => one(D.EQUIPMENT, z.array(C.equipmentSchema))],
  [
    'GET',
    /^\/api\/v1\/admin\/media$/,
    (_m, req) => {
      const kind = new URL(req.url()).searchParams.get('kind');
      return one(
        D.MEDIA.filter((a) => kind === null || a.kind === kind),
        z.array(C.adminMediaAssetSchema),
      );
    },
  ],
  ['GET', /^\/api\/v1\/admin\/audit-logs$/, () => page(D.AUDIT_LOGS, C.adminAuditLogSchema)],
  ['POST', /^\/api\/v1\/auth\/verify-email$/, () => ({ status: 204 })],
  ['POST', /^\/api\/v1\/auth\/reset-password$/, () => ({ status: 204 })],
];

const problemes = [];

async function repondre(route, options) {
  const req = route.request();
  const url = new URL(req.url());
  if (req.method() === 'OPTIONS') {
    return route.fulfill({ status: 204, headers: CORS });
  }
  const image = url.pathname.match(/^\/media\/(anatomie-[a-z-]+\.webp)$/);
  if (image !== null) {
    const body = readFileSync(path.join(REPO, 'apps/mobile/assets/academy', image[1]));
    return route.fulfill({ status: 200, headers: CORS, contentType: 'image/webp', body });
  }
  for (const [methode, motif, faire] of ROUTES) {
    const m = url.pathname.match(motif);
    if (req.method() !== methode || m === null) continue;
    const r = faire(m, req, options);
    if (r.status === 204) return route.fulfill({ status: 204, headers: CORS });
    const valide = r.schema.safeParse(r.raw ?? r.data);
    if (!valide.success) {
      problemes.push(
        `contrat violé par la réponse factice ${methode} ${url.pathname} : ${valide.error.message}`,
      );
    }
    const json = r.raw ?? { data: r.data, meta: r.meta ?? {}, requestId: 'req-capture' };
    return route.fulfill({
      status: r.status ?? 200,
      headers: CORS,
      contentType: 'application/json',
      body: JSON.stringify(json),
    });
  }
  problemes.push(`requête sans réponse factice : ${req.method()} ${url.pathname}${url.search}`);
  return route.fulfill({
    status: 404,
    headers: CORS,
    contentType: 'application/json',
    body: JSON.stringify({
      error: {
        code: 'NOT_FOUND',
        message: 'Route non simulée',
        details: [],
        requestId: 'req-capture',
      },
    }),
  });
}

// ── Pages à photographier ─────────────────────────────────────────────────

const FICHE = D.USERS[0].id;
const SUPPRIME = D.USERS.find((u) => u.status === 'DELETED').id;
/** `attendu` : un mot d'erreur que la variante DOIT montrer (il n'est alors pas une faute). */
const PAGES = [
  { nom: 'home', chemin: '/' },
  { nom: 'home-degraded', chemin: '/', options: { degrade: true }, attendu: 'Service dégradé' },
  { nom: 'login', chemin: '/login' },
  { nom: 'overview', chemin: '/overview', auth: true },
  { nom: 'users', chemin: '/users', auth: true },
  { nom: 'users-empty', chemin: '/users', auth: true, options: { usersEmpty: true } },
  { nom: 'user-detail', chemin: `/users/${FICHE}`, auth: true },
  { nom: 'user-deleted', chemin: `/users/${SUPPRIME}`, auth: true },
  { nom: 'reports', chemin: '/reports', auth: true },
  { nom: 'exercises', chemin: '/exercises', auth: true },
  { nom: 'categories', chemin: '/categories', auth: true },
  { nom: 'media', chemin: '/media', auth: true },
  { nom: 'audit', chemin: '/audit', auth: true },
  // Les fiches latérales, ouvertes d'un clic sur la page (`clics`, dans l'ordre).
  { nom: 'exercise-sheet', chemin: '/exercises', auth: true, clics: [/^Ouvrir la fiche de/] },
  { nom: 'media-sheet', chemin: '/media', auth: true, clics: [/^Ouvrir anatomie/] },
  { nom: 'report-sheet', chemin: '/reports', auth: true, clics: ['Examiner'] },
  {
    nom: 'report-decided',
    chemin: '/reports',
    auth: true,
    clics: [{ radio: 'Résolus' }, 'Voir la décision'],
  },
  { nom: 'privacy', chemin: '/privacy' },
  { nom: 'terms', chemin: '/terms' },
  { nom: 'abonnement', chemin: '/abonnement' },
  { nom: 'abonnement-merci', chemin: '/abonnement/merci' },
  { nom: 'reset-password', chemin: '/reset-password?token=jeton-de-demo' },
  { nom: 'verify-email', chemin: '/verify-email?token=jeton-de-demo' },
];

/**
 * Ce qu'un message d'état (`role="alert"` ou `"status"`) ne doit jamais dire
 * quand l'API factice répond bien. Cherché dans ces messages seulement : les
 * pages légales parlent, elles, de « permission » et de serveur qui « ne
 * répond pas ». Les deux dernières se cherchent dans toute la page.
 */
const FAUTES = [
  'indisponible',
  'injoignable',
  'Impossible de joindre',
  'ne répond pas',
  'permission',
  'session a expiré',
];
const FAUTES_PARTOUT = ['Réponse inattendue du serveur', 'Unhandled Runtime Error'];

const VUES = [
  {
    nom: 'desktop',
    viewport: { width: 1440, height: 900 },
    themes: ['light', 'dark'],
    filtre: () => true,
  },
  {
    nom: 'mobile',
    viewport: { width: 390, height: 844 },
    themes: ['light'],
    // Toutes les pages, fiches comprises : l'admin se tient aussi au téléphone.
    filtre: () => true,
  },
];

async function photographier(context, vue, theme, cible) {
  const onglet = await context.newPage();
  const etiquette = `${vue.nom}-${theme}-${cible.nom}`;
  onglet.on('console', (msg) => {
    if (msg.type() === 'error') console.warn(`  [console ${etiquette}] ${msg.text()}`);
  });
  onglet.on('pageerror', (err) => problemes.push(`${etiquette} : exception ${err.message}`));
  onglet.on('request', (req) => {
    const origine = new URL(req.url()).origin;
    if (origine !== ADMIN && origine !== D.API && !req.url().startsWith('data:')) {
      problemes.push(`${etiquette} : requête externe non simulée ${req.url()}`);
    }
  });
  await onglet.route(`${D.API}/**`, (route) => repondre(route, cible.options ?? {}));
  if (cible.auth) {
    await onglet.addInitScript((permissions) => {
      sessionStorage.setItem('carlys-admin-token', 'jeton-de-capture');
      sessionStorage.setItem('carlys-admin-permissions', JSON.stringify(permissions));
    }, D.ADMIN_ME.permissions);
  }
  const reponse = await onglet.goto(`${ADMIN}${cible.chemin}`, { waitUntil: 'networkidle' });
  if (reponse === null || !reponse.ok()) {
    problemes.push(`${etiquette} : ${cible.chemin} a répondu ${reponse?.status() ?? 'rien'}`);
  }
  // Le badge « N » et la pastille d'erreurs de `next dev` n'ont rien à faire sur une capture.
  await onglet.addStyleTag({ content: 'nextjs-portal { display: none !important; }' });
  await onglet.evaluate(() => document.fonts.ready);
  await onglet.waitForTimeout(400);
  for (const clic of cible.clics ?? []) {
    // Les boutons radio des segments sont masqués à l'œil : on les coche.
    if (typeof clic === 'object' && 'radio' in clic) {
      await onglet.getByRole('radio', { name: clic.radio }).check({ force: true });
    } else {
      await onglet.getByRole('button', { name: clic }).first().click();
    }
    await onglet.waitForLoadState('networkidle');
    await onglet.waitForTimeout(500);
  }

  // Comparaison sans casse : « Indisponible » en pastille vaut « indisponible » en phrase.
  const corps = (await onglet.innerText('body')).toLowerCase();
  const texte = (await onglet.locator('[role=alert], [role=status]').allInnerTexts())
    .join('\n')
    .toLowerCase();
  if (cible.auth && new URL(onglet.url()).pathname === '/login') {
    problemes.push(`${etiquette} : renvoyé vers /login (jeton refusé ?)`);
  }
  for (const faute of FAUTES) {
    if (faute !== cible.attendu && texte.includes(faute.toLowerCase())) {
      problemes.push(`${etiquette} : la page affiche « ${faute} »`);
    }
  }
  for (const faute of FAUTES_PARTOUT) {
    if (corps.includes(faute.toLowerCase()))
      problemes.push(`${etiquette} : la page affiche « ${faute} »`);
  }
  if (cible.attendu !== undefined && !texte.includes(cible.attendu.toLowerCase())) {
    problemes.push(`${etiquette} : « ${cible.attendu} » attendu, absent`);
  }
  const fichier = path.join(SORTIE, `${etiquette}.png`);
  // Pas de `fullPage` : Chromium y redimensionne la fenêtre au vol et repeint
  // mal les éléments fixes (la barre latérale sortait vide, une fois sur
  // trois). On agrandit donc la fenêtre à la hauteur de la page, on laisse la
  // mise en page se refaire, puis on capture la fenêtre.
  const largeur = onglet.viewportSize()?.width ?? 1440;
  const hauteur = await onglet.evaluate(() => document.documentElement.scrollHeight);
  await onglet.setViewportSize({ width: largeur, height: hauteur });
  await onglet.waitForTimeout(300);
  await onglet.screenshot({ path: fichier });
  await onglet.close();
  return fichier;
}

mkdirSync(SORTIE, { recursive: true });
const navigateur = await chromium.launch({ executablePath: CHROMIUM });
const produits = [];
try {
  for (const vue of VUES) {
    for (const theme of vue.themes) {
      const context = await navigateur.newContext({
        viewport: vue.viewport,
        deviceScaleFactor: vue.nom === 'mobile' ? 2 : 1,
        colorScheme: theme,
        reducedMotion: 'reduce',
        locale: 'fr-FR',
        timezoneId: 'Europe/Paris',
      });
      for (const cible of PAGES.filter(vue.filtre)) {
        produits.push(await photographier(context, vue, theme, cible));
        console.log(`✓ ${path.basename(produits.at(-1))}`);
      }
      await context.close();
    }
  }
} finally {
  await navigateur.close();
}

console.log(`\n${produits.length} captures dans ${SORTIE}`);
if (problemes.length > 0) {
  console.error(`\n${problemes.length} problème(s) :\n- ${[...new Set(problemes)].join('\n- ')}`);
  process.exit(1);
}
