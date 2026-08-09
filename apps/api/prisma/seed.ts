/**
 * Seed de développement Carlys — IDEMPOTENT (upsert par slug / e-mail).
 *
 * ⚠️  Les identifiants créés ici sont STRICTEMENT réservés au développement
 *     et ne doivent JAMAIS exister en production.
 *
 * Contenu : groupes musculaires, équipements, 43 exercices publiés avec les
 * photos qui les illustrent (déposées dans le stockage objet, jamais
 * embarquées dans l'application),
 * plans d'abonnement (gratuit, premium) et deux utilisateurs de
 * démonstration — le compte premium reçoit ses entitlements (droits
 * décidés côté serveur, Étape 6).
 */
import { ADMIN_PERMISSIONS, PREMIUM_ENTITLEMENT_KEYS } from '@carlys/api-contracts';
import { seedExerciseMedia } from './seed-media';
import {
  BillingPeriod,
  ExerciseDifficulty,
  ExerciseMuscleRole,
  ExerciseType,
  PaymentProvider,
  PrismaClient,
} from '@prisma/client';
import * as argon2 from 'argon2';

const prisma = new PrismaClient();

const MUSCLE_GROUPS: { slug: string; name: string }[] = [
  { slug: 'pectoraux', name: 'Pectoraux' },
  { slug: 'dos', name: 'Dos' },
  { slug: 'epaules', name: 'Épaules' },
  { slug: 'biceps', name: 'Biceps' },
  { slug: 'triceps', name: 'Triceps' },
  { slug: 'avant-bras', name: 'Avant-bras' },
  { slug: 'abdominaux', name: 'Abdominaux' },
  { slug: 'lombaires', name: 'Lombaires' },
  { slug: 'fessiers', name: 'Fessiers' },
  { slug: 'quadriceps', name: 'Quadriceps' },
  { slug: 'ischio-jambiers', name: 'Ischio-jambiers' },
  { slug: 'mollets', name: 'Mollets' },
];

const EQUIPMENT: { slug: string; name: string }[] = [
  { slug: 'poids-du-corps', name: 'Poids du corps' },
  { slug: 'barre', name: 'Barre' },
  { slug: 'halteres', name: 'Haltères' },
  { slug: 'kettlebell', name: 'Kettlebell' },
  { slug: 'machine', name: 'Machine guidée' },
  { slug: 'poulie', name: 'Poulie' },
  { slug: 'banc', name: 'Banc' },
  { slug: 'elastique', name: 'Élastique' },
  { slug: 'barre-de-traction', name: 'Barre de traction' },
  { slug: 'barre-ez', name: 'Barre EZ' },
  { slug: 'tapis', name: 'Tapis' },
];

interface SeedExercise {
  slug: string;
  name: string;
  description: string;
  instructions: string[];
  difficulty: ExerciseDifficulty;
  type: ExerciseType;
  isPremium?: boolean;
  tags: string[];
  primary: string;
  secondary: string[];
  equipment: string[];
}

const { BEGINNER, INTERMEDIATE, ADVANCED } = ExerciseDifficulty;
const { STRENGTH, CARDIO, MOBILITY, STRETCHING } = ExerciseType;

const EXERCISES: SeedExercise[] = [
  {
    slug: 'developpe-couche',
    name: 'Développé couché',
    description:
      'Le mouvement de référence pour la force du haut du corps, barre en mains sur un banc horizontal.',
    instructions: [
      'Allongez-vous sur le banc, pieds ancrés au sol, omoplates serrées.',
      'Saisissez la barre avec une prise légèrement plus large que les épaules.',
      'Descendez la barre avec contrôle jusqu’au bas des pectoraux.',
      'Poussez vers le haut jusqu’à l’extension complète des bras, sans verrouiller brutalement.',
    ],
    difficulty: INTERMEDIATE,
    type: STRENGTH,
    tags: ['force', 'polyarticulaire', 'barre'],
    primary: 'pectoraux',
    secondary: ['triceps', 'epaules'],
    equipment: ['barre', 'banc'],
  },
  {
    slug: 'developpe-incline-halteres',
    name: 'Développé incliné haltères',
    description:
      'Cible la portion haute des pectoraux avec une plus grande amplitude que la barre.',
    instructions: [
      'Réglez le banc entre 30 et 45 degrés.',
      'Montez les haltères au-dessus des épaules, paumes vers l’avant.',
      'Descendez avec contrôle jusqu’à un léger étirement des pectoraux.',
      'Poussez en rapprochant légèrement les haltères en haut.',
    ],
    difficulty: INTERMEDIATE,
    type: STRENGTH,
    tags: ['haut-des-pectoraux', 'halteres'],
    primary: 'pectoraux',
    secondary: ['epaules', 'triceps'],
    equipment: ['halteres', 'banc'],
  },
  {
    slug: 'pompes',
    name: 'Pompes',
    description: 'Le classique au poids du corps pour pectoraux, triceps et gainage.',
    instructions: [
      'Placez les mains au sol, écartées de la largeur des épaules.',
      'Gardez le corps parfaitement gainé, des talons à la tête.',
      'Descendez la poitrine près du sol en gardant les coudes à ~45°.',
      'Repoussez jusqu’à l’extension complète des bras.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['poids-du-corps', 'maison', 'gainage'],
    primary: 'pectoraux',
    secondary: ['triceps', 'epaules', 'abdominaux'],
    equipment: ['poids-du-corps'],
  },
  {
    slug: 'ecarte-poulie-vis-a-vis',
    name: 'Écarté à la poulie vis-à-vis',
    description: 'Isolation des pectoraux sous tension continue, idéale en fin de séance.',
    instructions: [
      'Réglez les poulies à hauteur d’épaules, un pas en avant du vis-à-vis.',
      'Bras semi-fléchis, ramenez les poignées devant vous en arc de cercle.',
      'Serrez les pectoraux une seconde au point de contraction.',
      'Revenez lentement sans laisser les charges vous tirer en arrière.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['isolation', 'poulie'],
    primary: 'pectoraux',
    secondary: ['epaules'],
    equipment: ['poulie'],
  },
  {
    slug: 'developpe-incline',
    name: 'Développé incliné',
    description:
      'La version barre du développé incliné : plus lourd que les haltères, cible le haut des pectoraux.',
    instructions: [
      'Réglez le banc entre 30 et 45 degrés — au-delà, ce sont les épaules qui travaillent.',
      'Prise légèrement plus large que les épaules, omoplates serrées.',
      'Descendez la barre vers le haut de la poitrine, coudes à 45 degrés du buste.',
      'Poussez jusqu’à l’extension sans verrouiller brutalement les coudes.',
    ],
    difficulty: INTERMEDIATE,
    type: STRENGTH,
    tags: ['force', 'polyarticulaire', 'haut-des-pectoraux', 'barre'],
    primary: 'pectoraux',
    secondary: ['epaules', 'triceps'],
    equipment: ['barre', 'banc'],
  },
  {
    slug: 'developpe-decline',
    name: 'Développé décliné',
    description:
      'Banc en pente négative : l’angle recrute davantage la portion basse des pectoraux.',
    instructions: [
      'Calez les jambes sous les boudins avant de vous allonger.',
      'Prise un peu plus large que les épaules, barre au-dessus du bas de la poitrine.',
      'Descendez avec contrôle jusqu’à effleurer le bas des pectoraux.',
      'Poussez à la verticale ; faites-vous assister pour reposer la barre.',
    ],
    difficulty: INTERMEDIATE,
    type: STRENGTH,
    tags: ['force', 'polyarticulaire', 'bas-des-pectoraux', 'barre'],
    primary: 'pectoraux',
    secondary: ['triceps'],
    equipment: ['barre', 'banc'],
  },
  {
    slug: 'developpe-couche-halteres',
    name: 'Développé couché haltères',
    description:
      'Le développé couché avec deux charges libres : amplitude plus grande, chaque bras travaille seul.',
    instructions: [
      'Assis sur le banc, haltères sur les cuisses, basculez en arrière en les accompagnant.',
      'Descendez jusqu’à ce que les coudes passent légèrement sous la ligne du buste.',
      'Poussez en rapprochant les haltères sans les entrechoquer.',
      'Reposez les haltères sur les cuisses avant de vous relever.',
    ],
    difficulty: INTERMEDIATE,
    type: STRENGTH,
    tags: ['force', 'polyarticulaire', 'halteres'],
    primary: 'pectoraux',
    secondary: ['triceps', 'epaules'],
    equipment: ['halteres', 'banc'],
  },
  {
    slug: 'developpe-decline-halteres',
    name: 'Développé décliné haltères',
    description:
      'Bas des pectoraux avec charges libres : l’amplitude des haltères sur l’angle du décliné.',
    instructions: [
      'Calez les jambes, haltères en mains, basculez en arrière avec contrôle.',
      'Descendez jusqu’à un étirement franc, coudes légèrement rentrés.',
      'Poussez vers le haut en resserrant les pectoraux.',
      'Faites-vous aider pour reposer les haltères si la charge est lourde.',
    ],
    difficulty: INTERMEDIATE,
    type: STRENGTH,
    tags: ['bas-des-pectoraux', 'halteres'],
    primary: 'pectoraux',
    secondary: ['triceps'],
    equipment: ['halteres', 'banc'],
  },
  {
    slug: 'chest-press-machine',
    name: 'Chest press machine',
    description:
      'La poussée guidée : trajectoire imposée, donc peu de technique à maîtriser — idéale pour débuter.',
    instructions: [
      'Réglez le siège pour que les poignées arrivent à mi-poitrine.',
      'Dos plaqué au dossier, pieds au sol.',
      'Poussez jusqu’à l’extension sans verrouiller les coudes.',
      'Revenez lentement jusqu’à sentir l’étirement, sans laisser les plaques claquer.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['machine', 'debutant'],
    primary: 'pectoraux',
    secondary: ['triceps', 'epaules'],
    equipment: ['machine'],
  },
  {
    slug: 'chest-press-incline-machine',
    name: 'Chest press incliné machine',
    description: 'Le chest press sur un angle incliné : haut des pectoraux, trajectoire guidée.',
    instructions: [
      'Réglez le siège pour que les poignées arrivent au niveau des clavicules.',
      'Dos plaqué, omoplates serrées.',
      'Poussez vers le haut et l’avant jusqu’à l’extension.',
      'Contrôlez le retour sur toute l’amplitude.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['machine', 'haut-des-pectoraux'],
    primary: 'pectoraux',
    secondary: ['epaules', 'triceps'],
    equipment: ['machine'],
  },
  {
    slug: 'ecarte-poulie-incline',
    name: 'Écarté à la poulie incliné',
    description:
      'Écarté à la poulie sur banc incliné : l’angle du buste reporte la tension sur le haut des pectoraux.',
    instructions: [
      'Placez un banc incliné entre deux poulies, réglées en position haute.',
      'Assis, dos plaqué, bras semi-fléchis et FIXES pendant tout le mouvement.',
      'Ramenez les poignées devant la poitrine et serrez une seconde.',
      'Ouvrez lentement jusqu’à l’étirement, sans laisser les charges vous tirer.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['isolation', 'poulie', 'haut-des-pectoraux'],
    primary: 'pectoraux',
    secondary: ['epaules'],
    equipment: ['poulie', 'banc'],
  },
  {
    slug: 'ecarte-poulie-decline',
    name: 'Écarté à la poulie décliné',
    description:
      'Écarté à la poulie sur banc décliné : l’angle recrute la portion basse des pectoraux.',
    instructions: [
      'Placez un banc décliné entre deux poulies et calez vos jambes.',
      'Bras semi-fléchis et fixes, ramenez les poignées au-dessus de la poitrine.',
      'Serrez une seconde au point de contraction.',
      'Ouvrez lentement jusqu’à l’étirement, épaules basses.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['isolation', 'poulie', 'bas-des-pectoraux'],
    primary: 'pectoraux',
    secondary: ['epaules'],
    equipment: ['poulie', 'banc'],
  },
  {
    slug: 'pec-deck',
    name: 'Pec deck',
    description:
      'L’isolation guidée des pectoraux : le buste est calé, seuls les bras se referment.',
    instructions: [
      'Réglez le siège pour que les poignées soient à hauteur d’épaules.',
      'Dos plaqué, avant-bras contre les coussinets.',
      'Refermez les bras devant vous et tenez la contraction une seconde.',
      'Ouvrez lentement jusqu’à l’étirement, sans forcer au-delà.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['isolation', 'machine', 'debutant'],
    primary: 'pectoraux',
    secondary: ['epaules'],
    equipment: ['machine'],
  },
  {
    slug: 'ecarte-couche-halteres',
    name: 'Écarté couché haltères',
    description:
      'L’isolation en charge libre : l’étirement le plus complet des pectoraux, à charge modérée.',
    instructions: [
      'Allongé sur le banc, haltères au-dessus de la poitrine, paumes face à face.',
      'Gardez les coudes légèrement fléchis et FIXES pendant tout le mouvement.',
      'Ouvrez les bras en arc de cercle jusqu’à sentir l’étirement.',
      'Refermez en pensant à rapprocher les coudes, pas les mains.',
    ],
    difficulty: INTERMEDIATE,
    type: STRENGTH,
    tags: ['isolation', 'halteres'],
    primary: 'pectoraux',
    secondary: ['epaules'],
    equipment: ['halteres', 'banc'],
  },
  {
    slug: 'tractions',
    name: 'Tractions',
    description: 'Le meilleur exercice au poids du corps pour l’épaisseur et la largeur du dos.',
    instructions: [
      'Suspendez-vous à la barre, prise pronation légèrement plus large que les épaules.',
      'Tirez en amenant la poitrine vers la barre, coudes vers le bas.',
      'Passez le menton au-dessus de la barre sans élan.',
      'Redescendez avec contrôle jusqu’à l’extension complète.',
    ],
    difficulty: ADVANCED,
    type: STRENGTH,
    tags: ['poids-du-corps', 'polyarticulaire'],
    primary: 'dos',
    secondary: ['biceps', 'avant-bras'],
    equipment: ['barre-de-traction'],
  },
  {
    slug: 'rowing-barre',
    name: 'Rowing barre buste penché',
    description: 'Développe l’épaisseur du dos et renforce toute la chaîne postérieure.',
    instructions: [
      'Penchez le buste à ~45°, dos plat, genoux souples.',
      'Saisissez la barre en pronation, bras tendus.',
      'Tirez la barre vers le nombril en serrant les omoplates.',
      'Redescendez avec contrôle sans arrondir le dos.',
    ],
    difficulty: INTERMEDIATE,
    type: STRENGTH,
    tags: ['barre', 'polyarticulaire'],
    primary: 'dos',
    secondary: ['biceps', 'lombaires'],
    equipment: ['barre'],
  },
  {
    slug: 'tirage-vertical-poulie',
    name: 'Tirage vertical à la poulie',
    description: 'Alternative guidée aux tractions pour construire la largeur du dos.',
    instructions: [
      'Asseyez-vous cuisses calées, prise large en pronation.',
      'Tirez la barre vers le haut des pectoraux en sortant la poitrine.',
      'Contrôlez la remontée jusqu’à l’étirement complet des dorsaux.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['poulie', 'machine'],
    primary: 'dos',
    secondary: ['biceps'],
    equipment: ['poulie', 'machine'],
  },
  {
    slug: 'rowing-halteres-unilateral',
    name: 'Rowing haltère unilatéral',
    description: 'Travail du dos un côté à la fois, corrige les déséquilibres.',
    instructions: [
      'Posez un genou et une main sur le banc, dos plat.',
      'Tirez l’haltère vers la hanche, coude près du corps.',
      'Redescendez lentement jusqu’à l’étirement complet.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['halteres', 'unilateral'],
    primary: 'dos',
    secondary: ['biceps'],
    equipment: ['halteres', 'banc'],
  },
  {
    slug: 'souleve-de-terre',
    name: 'Soulevé de terre',
    description: 'Le mouvement de force le plus complet : toute la chaîne postérieure y participe.',
    instructions: [
      'Barre au sol contre les tibias, pieds sous les hanches.',
      'Dos plat, saisissez la barre en dehors des jambes.',
      'Poussez le sol avec les jambes puis tendez les hanches, barre au contact du corps.',
      'Verrouillez debout, puis redescendez la barre en gardant le dos neutre.',
    ],
    difficulty: ADVANCED,
    type: STRENGTH,
    tags: ['barre', 'polyarticulaire', 'force'],
    primary: 'lombaires',
    secondary: ['fessiers', 'ischio-jambiers', 'dos', 'avant-bras'],
    equipment: ['barre'],
  },
  {
    slug: 'developpe-militaire',
    name: 'Développé militaire',
    description: 'Presse verticale debout, référence pour la force des épaules.',
    instructions: [
      'Barre au niveau des clavicules, prise à la largeur des épaules.',
      'Gainez le tronc et poussez la barre au-dessus de la tête.',
      'Terminez bras tendus, la barre alignée avec les oreilles.',
      'Redescendez sous contrôle jusqu’aux clavicules.',
    ],
    difficulty: INTERMEDIATE,
    type: STRENGTH,
    tags: ['barre', 'polyarticulaire'],
    primary: 'epaules',
    secondary: ['triceps', 'abdominaux'],
    equipment: ['barre'],
  },
  {
    slug: 'elevations-laterales',
    name: 'Élévations latérales',
    description: 'Isolation du deltoïde moyen pour élargir les épaules.',
    instructions: [
      'Debout, un haltère dans chaque main le long du corps.',
      'Montez les bras sur les côtés jusqu’à l’horizontale, coudes souples.',
      'Redescendez lentement sans balancer le buste.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['halteres', 'isolation'],
    primary: 'epaules',
    secondary: [],
    equipment: ['halteres'],
  },
  {
    slug: 'oiseau-halteres',
    name: 'Oiseau (élévations buste penché)',
    description: 'Cible l’arrière d’épaule, souvent négligé, essentiel à l’équilibre articulaire.',
    instructions: [
      'Buste penché à l’horizontale, haltères sous la poitrine.',
      'Écartez les bras sur les côtés en serrant les omoplates.',
      'Redescendez sans à-coups.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['halteres', 'isolation', 'posture'],
    primary: 'epaules',
    secondary: ['dos'],
    equipment: ['halteres'],
  },
  {
    slug: 'curl-biceps-halteres',
    name: 'Curl biceps haltères',
    description: 'Flexion de coude stricte pour le volume des biceps.',
    instructions: [
      'Debout, haltères en supination le long du corps.',
      'Fléchissez les coudes sans bouger les épaules.',
      'Serrez en haut puis redescendez lentement.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['halteres', 'isolation'],
    primary: 'biceps',
    secondary: ['avant-bras'],
    equipment: ['halteres'],
  },
  {
    slug: 'curl-barre',
    name: 'Curl barre',
    description:
      'Le curl de référence : une barre, les deux bras ensemble, la charge la plus lourde du groupe.',
    instructions: [
      'Debout, pieds à largeur de bassin, barre en supination à largeur d’épaules.',
      'Coudes collés au buste, fléchissez sans balancer le dos.',
      'Montez jusqu’à la contraction, sans amener la barre trop haut.',
      'Redescendez lentement jusqu’à l’extension complète.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['barre', 'isolation'],
    primary: 'biceps',
    secondary: ['avant-bras'],
    equipment: ['barre'],
  },
  {
    slug: 'curl-ez-barre',
    name: 'Curl à la barre EZ',
    description: 'Même mouvement que le curl barre, avec une barre coudée qui ménage les poignets.',
    instructions: [
      'Saisissez la barre EZ par ses cambrures, paumes vers le haut.',
      'Coudes fixes le long du buste, fléchissez sans reculer les épaules.',
      'Serrez une seconde en haut.',
      'Contrôlez toute la descente.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['barre-ez', 'isolation', 'poignets'],
    primary: 'biceps',
    secondary: ['avant-bras'],
    equipment: ['barre-ez'],
  },
  {
    slug: 'curl-alterne',
    name: 'Curl alterné',
    description:
      'Un bras après l’autre : plus de concentration sur chaque côté, et un déséquilibre qui se corrige.',
    instructions: [
      'Debout, un haltère dans chaque main, bras le long du corps.',
      'Montez un haltère en tournant la paume vers le haut pendant la montée.',
      'Redescendez ce bras avant de commencer l’autre.',
      'Gardez le buste immobile : pas d’élan des hanches.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['halteres', 'isolation', 'unilateral'],
    primary: 'biceps',
    secondary: ['avant-bras'],
    equipment: ['halteres'],
  },
  {
    slug: 'curl-incline-halteres',
    name: 'Curl incliné haltères',
    description:
      'Assis en arrière, les bras pendent derrière le buste : c’est l’étirement le plus fort du biceps.',
    instructions: [
      'Réglez le banc autour de 45 à 60 degrés et calez le dos.',
      'Laissez les bras pendre à la verticale, paumes vers l’avant.',
      'Fléchissez sans avancer les coudes — c’est ce qui garde l’étirement.',
      'Redescendez jusqu’à l’extension complète.',
    ],
    difficulty: INTERMEDIATE,
    type: STRENGTH,
    tags: ['halteres', 'isolation', 'etirement'],
    primary: 'biceps',
    secondary: ['avant-bras'],
    equipment: ['halteres', 'banc'],
  },
  {
    slug: 'curl-concentration',
    name: 'Curl concentration',
    description:
      'Assis, le coude calé contre la cuisse : impossible de tricher, tout passe par le biceps.',
    instructions: [
      'Assis, jambes écartées, calez l’arrière du bras contre l’intérieur de la cuisse.',
      'Laissez le bras pendre, haltère en supination.',
      'Fléchissez lentement jusqu’à la contraction complète.',
      'Redescendez sans à-coup, puis changez de bras.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['halteres', 'isolation', 'unilateral'],
    primary: 'biceps',
    secondary: [],
    equipment: ['halteres', 'banc'],
  },
  {
    slug: 'curl-pupitre',
    name: 'Curl au pupitre',
    description:
      'Bras posés sur le pupitre (banc Scott) : l’appui supprime l’élan et isole la flexion.',
    instructions: [
      'Réglez le siège pour que l’aisselle repose sur le haut du pupitre.',
      'Barre EZ en supination, bras allongés sur le coussin.',
      'Fléchissez jusqu’à la contraction, sans décoller les triceps du pupitre.',
      'Redescendez LENTEMENT : c’est en bas que le biceps est le plus vulnérable.',
    ],
    difficulty: INTERMEDIATE,
    type: STRENGTH,
    tags: ['barre-ez', 'isolation', 'pupitre'],
    primary: 'biceps',
    secondary: ['avant-bras'],
    equipment: ['barre-ez', 'banc'],
  },
  {
    slug: 'curl-pupitre-halteres',
    name: 'Curl au pupitre haltère',
    description:
      'La version un bras du curl au pupitre : chaque côté travaille seul, sur toute l’amplitude.',
    instructions: [
      'Calez un seul bras sur le pupitre, haltère en supination.',
      'Fléchissez jusqu’en haut sans décoller le triceps du coussin.',
      'Contrôlez la descente jusqu’à l’extension.',
      'Terminez la série avant de changer de bras.',
    ],
    difficulty: INTERMEDIATE,
    type: STRENGTH,
    tags: ['halteres', 'isolation', 'pupitre', 'unilateral'],
    primary: 'biceps',
    secondary: ['avant-bras'],
    equipment: ['halteres', 'banc'],
  },
  {
    slug: 'curl-spider',
    name: 'Curl spider',
    description:
      'Buste posé sur un banc incliné, bras à la verticale : la tension ne retombe jamais.',
    instructions: [
      'Allongez le buste face contre un banc incliné, bras pendants.',
      'Haltères en supination, coudes immobiles.',
      'Fléchissez jusqu’à la contraction maximale.',
      'Redescendez lentement sans laisser les bras se balancer.',
    ],
    difficulty: INTERMEDIATE,
    type: STRENGTH,
    tags: ['halteres', 'isolation', 'tension-continue'],
    primary: 'biceps',
    secondary: [],
    equipment: ['halteres', 'banc'],
  },
  {
    slug: 'curl-inverse',
    name: 'Curl inversé',
    description:
      'Prise pronation : le biceps travaille en position défavorable, les avant-bras prennent le relais.',
    instructions: [
      'Barre en pronation (paumes vers le bas), mains à largeur d’épaules.',
      'Coudes au corps, fléchissez sans casser les poignets.',
      'Montez jusqu’à hauteur de poitrine.',
      'Redescendez lentement — la charge sera plus légère qu’en supination, c’est normal.',
    ],
    difficulty: INTERMEDIATE,
    type: STRENGTH,
    tags: ['barre', 'avant-bras'],
    primary: 'biceps',
    secondary: ['avant-bras'],
    equipment: ['barre'],
  },
  {
    slug: 'curl-poulie-barre-droite',
    name: 'Curl à la poulie barre droite',
    description:
      'À la poulie basse, la tension reste constante du début à la fin — ce que la barre libre ne fait pas.',
    instructions: [
      'Accrochez une barre droite à la poulie basse, un pas en arrière.',
      'Coudes au corps, fléchissez en gardant le buste droit.',
      'Serrez en haut sans hausser les épaules.',
      'Laissez redescendre en résistant à la charge.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['poulie', 'isolation', 'tension-continue'],
    primary: 'biceps',
    secondary: ['avant-bras'],
    equipment: ['poulie'],
  },
  {
    slug: 'curl-poulie-corde',
    name: 'Curl à la poulie corde',
    description:
      'La corde laisse les poignets libres de tourner : la supination se fait au moment de la contraction.',
    instructions: [
      'Accrochez une corde à la poulie basse, prise neutre.',
      'Fléchissez les coudes en écartant les extrémités de la corde en haut.',
      'Tenez la contraction une seconde.',
      'Redescendez en contrôlant, coudes immobiles.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['poulie', 'isolation', 'avant-bras'],
    primary: 'biceps',
    secondary: ['avant-bras'],
    equipment: ['poulie'],
  },
  {
    slug: 'tractions-supinees',
    name: 'Tractions supinées',
    description:
      'Le seul exercice de biceps au poids du corps qui charge lourd — le dos travaille avec.',
    instructions: [
      'Suspendez-vous en supination, mains à largeur d’épaules.',
      'Tirez en amenant la poitrine vers la barre, coudes vers le bas.',
      'Passez le menton au-dessus de la barre sans élan.',
      'Redescendez avec contrôle jusqu’à l’extension complète.',
    ],
    difficulty: INTERMEDIATE,
    type: STRENGTH,
    tags: ['poids-du-corps', 'polyarticulaire'],
    primary: 'biceps',
    secondary: ['dos', 'avant-bras'],
    equipment: ['barre-de-traction'],
  },
  {
    slug: 'curl-marteau',
    name: 'Curl marteau',
    description: 'Variante en prise neutre qui sollicite biceps et avant-bras.',
    instructions: [
      'Haltères en prise neutre (paumes face à face).',
      'Fléchissez les coudes en gardant les poignets fixes.',
      'Contrôlez la descente complète.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['halteres', 'isolation'],
    primary: 'biceps',
    secondary: ['avant-bras'],
    equipment: ['halteres'],
  },
  {
    slug: 'dips',
    name: 'Dips',
    description:
      'Poussée verticale au poids du corps, très efficace pour les triceps et les pectoraux.',
    instructions: [
      'Suspendez-vous entre les barres, bras tendus.',
      'Descendez en fléchissant les coudes jusqu’à ~90°.',
      'Remontez en poussant fort, buste légèrement penché.',
    ],
    difficulty: INTERMEDIATE,
    type: STRENGTH,
    tags: ['poids-du-corps', 'polyarticulaire'],
    primary: 'triceps',
    secondary: ['pectoraux', 'epaules'],
    equipment: ['poids-du-corps'],
  },
  {
    slug: 'extension-triceps-poulie',
    name: 'Extension triceps à la poulie',
    description: 'Isolation des triceps à la corde, tension continue et coudes fixes.',
    instructions: [
      'Face à la poulie haute, saisissez la corde coudes au corps.',
      'Tendez les bras vers le bas en écartant la corde en fin de mouvement.',
      'Remontez lentement sans décoller les coudes.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['poulie', 'isolation'],
    primary: 'triceps',
    secondary: [],
    equipment: ['poulie'],
  },
  {
    slug: 'squat-barre',
    name: 'Squat barre',
    description: 'Le roi des exercices de jambes : quadriceps, fessiers et gainage.',
    instructions: [
      'Barre sur les trapèzes, pieds à la largeur des épaules.',
      'Descendez en poussant les hanches en arrière, genoux dans l’axe des pieds.',
      'Passez sous la parallèle si votre mobilité le permet.',
      'Remontez en poussant le sol, buste gainé.',
    ],
    difficulty: INTERMEDIATE,
    type: STRENGTH,
    tags: ['barre', 'polyarticulaire', 'force'],
    primary: 'quadriceps',
    secondary: ['fessiers', 'lombaires', 'abdominaux'],
    equipment: ['barre'],
  },
  {
    slug: 'squat-gobelet',
    name: 'Squat gobelet',
    description: 'Squat avec un haltère contre la poitrine — parfait pour apprendre le mouvement.',
    instructions: [
      'Tenez un haltère verticalement contre la poitrine.',
      'Descendez entre vos jambes, buste droit.',
      'Remontez en gardant les talons au sol.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['halteres', 'technique', 'maison'],
    primary: 'quadriceps',
    secondary: ['fessiers', 'abdominaux'],
    equipment: ['halteres'],
  },
  {
    slug: 'fentes-marchees',
    name: 'Fentes marchées',
    description: 'Travail unilatéral des jambes avec un fort transfert athlétique.',
    instructions: [
      'Faites un grand pas en avant, buste droit.',
      'Descendez le genou arrière près du sol.',
      'Poussez sur la jambe avant pour enchaîner le pas suivant.',
    ],
    difficulty: INTERMEDIATE,
    type: STRENGTH,
    tags: ['unilateral', 'halteres', 'maison'],
    primary: 'quadriceps',
    secondary: ['fessiers', 'ischio-jambiers'],
    equipment: ['poids-du-corps', 'halteres'],
  },
  {
    slug: 'presse-a-cuisses',
    name: 'Presse à cuisses',
    description: 'Poussée de jambes guidée qui charge lourd en sécurité.',
    instructions: [
      'Pieds à plat sur le plateau, largeur d’épaules.',
      'Descendez le plateau jusqu’à ~90° de flexion de genoux.',
      'Poussez sans verrouiller brutalement les genoux.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['machine'],
    primary: 'quadriceps',
    secondary: ['fessiers'],
    equipment: ['machine'],
  },
  {
    slug: 'souleve-de-terre-roumain',
    name: 'Soulevé de terre roumain',
    description: 'Charnière de hanche jambes semi-tendues, référence pour les ischio-jambiers.',
    instructions: [
      'Barre en mains, jambes presque tendues.',
      'Poussez les hanches en arrière, barre au contact des cuisses.',
      'Descendez jusqu’à l’étirement des ischio-jambiers, dos plat.',
      'Remontez en contractant les fessiers.',
    ],
    difficulty: INTERMEDIATE,
    type: STRENGTH,
    tags: ['barre', 'charniere-de-hanche'],
    primary: 'ischio-jambiers',
    secondary: ['fessiers', 'lombaires'],
    equipment: ['barre'],
  },
  {
    slug: 'leg-curl-machine',
    name: 'Leg curl à la machine',
    description: 'Isolation des ischio-jambiers en flexion de genou.',
    instructions: [
      'Réglez la machine pour aligner le genou avec l’axe de rotation.',
      'Fléchissez les jambes en amenant les talons vers les fessiers.',
      'Retenez le retour sur toute l’amplitude.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['machine', 'isolation'],
    primary: 'ischio-jambiers',
    secondary: [],
    equipment: ['machine'],
  },
  {
    slug: 'hip-thrust',
    name: 'Hip thrust',
    description: 'Extension de hanche dos sur banc — l’exercice le plus direct pour les fessiers.',
    instructions: [
      'Haut du dos sur le banc, barre sur les hanches.',
      'Poussez les hanches vers le plafond jusqu’à l’alignement épaules-genoux.',
      'Serrez fort les fessiers une seconde puis redescendez.',
    ],
    difficulty: INTERMEDIATE,
    type: STRENGTH,
    tags: ['barre', 'banc'],
    primary: 'fessiers',
    secondary: ['ischio-jambiers'],
    equipment: ['barre', 'banc'],
  },
  {
    slug: 'pont-fessier',
    name: 'Pont fessier',
    description: 'Version au sol du hip thrust, idéale à la maison et en échauffement.',
    instructions: [
      'Allongé sur le dos, pieds à plat près des fessiers.',
      'Poussez les hanches vers le haut en serrant les fessiers.',
      'Redescendez sans reposer complètement entre les répétitions.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['poids-du-corps', 'maison', 'echauffement'],
    primary: 'fessiers',
    secondary: ['ischio-jambiers', 'lombaires'],
    equipment: ['tapis'],
  },
  {
    slug: 'mollets-debout',
    name: 'Extensions mollets debout',
    description: 'Montées sur pointes pour développer les mollets.',
    instructions: [
      'Avant-pieds sur une marche, talons dans le vide.',
      'Montez sur les pointes le plus haut possible.',
      'Descendez lentement sous l’horizontale pour étirer.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['poids-du-corps', 'isolation', 'maison'],
    primary: 'mollets',
    secondary: [],
    equipment: ['poids-du-corps'],
  },
  {
    slug: 'planche',
    name: 'Planche',
    description: 'Gainage isométrique de référence pour un tronc solide.',
    instructions: [
      'Appui sur les avant-bras et les pointes de pieds.',
      'Alignez tête, dos et bassin — ni cambré ni voûté.',
      'Respirez normalement en maintenant la position.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['gainage', 'isometrique', 'maison'],
    primary: 'abdominaux',
    secondary: ['lombaires', 'epaules'],
    equipment: ['tapis'],
  },
  {
    slug: 'crunch',
    name: 'Crunch',
    description: 'Flexion de buste ciblée sur le grand droit de l’abdomen.',
    instructions: [
      'Allongé, genoux fléchis, mains aux tempes.',
      'Enroulez le buste en décollant les omoplates.',
      'Redescendez lentement sans tirer sur la nuque.',
    ],
    difficulty: BEGINNER,
    type: STRENGTH,
    tags: ['maison', 'isolation'],
    primary: 'abdominaux',
    secondary: [],
    equipment: ['tapis'],
  },
  {
    slug: 'releve-de-jambes-suspendu',
    name: 'Relevé de jambes suspendu',
    description: 'Exercice avancé d’abdominaux, jambes tendues depuis la barre de traction.',
    instructions: [
      'Suspendu à la barre, épaules actives.',
      'Montez les jambes tendues au-dessus de l’horizontale.',
      'Contrôlez la descente sans balancement.',
    ],
    difficulty: ADVANCED,
    type: STRENGTH,
    tags: ['poids-du-corps', 'gainage'],
    primary: 'abdominaux',
    secondary: ['avant-bras'],
    equipment: ['barre-de-traction'],
  },
  {
    slug: 'burpees',
    name: 'Burpees',
    description: 'Enchaînement complet cardio et renforcement, redoutable en intervalles.',
    instructions: [
      'Depuis la position debout, posez les mains et jetez les pieds en arrière.',
      'Faites une pompe, ramenez les pieds sous vous.',
      'Sautez en tendant les bras au-dessus de la tête.',
    ],
    difficulty: INTERMEDIATE,
    type: CARDIO,
    tags: ['hiit', 'maison', 'poids-du-corps'],
    primary: 'quadriceps',
    secondary: ['pectoraux', 'abdominaux', 'epaules'],
    equipment: ['poids-du-corps'],
  },
  {
    slug: 'mountain-climbers',
    name: 'Mountain climbers',
    description: 'Course en planche : cardio et gainage dynamique.',
    instructions: [
      'En position de planche haute, bras tendus.',
      'Ramenez alternativement les genoux vers la poitrine, à un rythme soutenu.',
      'Gardez le bassin stable pendant tout l’exercice.',
    ],
    difficulty: BEGINNER,
    type: CARDIO,
    tags: ['hiit', 'maison', 'gainage'],
    primary: 'abdominaux',
    secondary: ['quadriceps', 'epaules'],
    equipment: ['poids-du-corps'],
  },
  {
    slug: 'balancier-kettlebell',
    name: 'Balancier kettlebell (swing)',
    description: 'Extension de hanche explosive — puissance, cardio et chaîne postérieure.',
    instructions: [
      'Kettlebell à deux mains, charnière de hanche marquée.',
      'Projetez la cloche vers l’avant en claquant l’extension de hanches.',
      'Laissez-la redescendre entre les jambes et enchaînez.',
    ],
    difficulty: INTERMEDIATE,
    type: CARDIO,
    isPremium: true,
    tags: ['kettlebell', 'explosif', 'hiit'],
    primary: 'fessiers',
    secondary: ['ischio-jambiers', 'lombaires', 'epaules'],
    equipment: ['kettlebell'],
  },
  {
    slug: 'etirement-chat-vache',
    name: 'Étirement chat-vache',
    description:
      'Mobilisation douce de la colonne, parfaite en échauffement ou en retour au calme.',
    instructions: [
      'À quatre pattes, mains sous les épaules.',
      'Inspirez en creusant le dos, regard vers l’avant.',
      'Expirez en arrondissant le dos, menton vers la poitrine.',
      'Alternez lentement au rythme de la respiration.',
    ],
    difficulty: BEGINNER,
    type: MOBILITY,
    tags: ['mobilite', 'echauffement', 'maison'],
    primary: 'lombaires',
    secondary: ['abdominaux'],
    equipment: ['tapis'],
  },
  {
    slug: 'etirement-ischio-debout',
    name: 'Étirement des ischio-jambiers debout',
    description: 'Étirement statique de l’arrière de cuisse, à tenir sans à-coups.',
    instructions: [
      'Posez un talon devant vous, jambe tendue.',
      'Penchez le buste vers l’avant, dos plat.',
      'Maintenez 20 à 30 secondes par jambe en respirant profondément.',
    ],
    difficulty: BEGINNER,
    type: STRETCHING,
    tags: ['etirement', 'maison', 'recuperation'],
    primary: 'ischio-jambiers',
    secondary: ['mollets', 'lombaires'],
    equipment: ['poids-du-corps'],
  },
];

const DEV_USERS = [
  { email: 'dev.gratuit@carlys.local', displayName: 'Dev Gratuit' },
  { email: 'dev.premium@carlys.local', displayName: 'Dev Premium' },
];
const DEV_PASSWORD = 'Carlys-Dev-2026!';

async function seedCatalog(): Promise<void> {
  for (const [index, group] of MUSCLE_GROUPS.entries()) {
    await prisma.muscleGroup.upsert({
      where: { slug: group.slug },
      update: { name: group.name, sortOrder: index },
      create: { slug: group.slug, name: group.name, sortOrder: index },
    });
  }

  for (const equipment of EQUIPMENT) {
    await prisma.equipment.upsert({
      where: { slug: equipment.slug },
      update: { name: equipment.name },
      create: equipment,
    });
  }

  const groups = new Map(
    (await prisma.muscleGroup.findMany()).map((group) => [group.slug, group.id]),
  );
  const equipmentIds = new Map(
    (await prisma.equipment.findMany()).map((equipment) => [equipment.slug, equipment.id]),
  );

  for (const exercise of EXERCISES) {
    const data = {
      name: exercise.name,
      description: exercise.description,
      instructions: exercise.instructions,
      difficulty: exercise.difficulty,
      type: exercise.type,
      isPremium: exercise.isPremium ?? false,
      isPublished: true,
      tags: exercise.tags,
    };
    const { id } = await prisma.exercise.upsert({
      where: { slug: exercise.slug },
      update: data,
      create: { slug: exercise.slug, ...data },
    });

    // Liens muscles/équipements reconstruits à chaque seed (idempotent).
    await prisma.exerciseMuscle.deleteMany({ where: { exerciseId: id } });
    await prisma.exerciseMuscle.createMany({
      data: [
        {
          exerciseId: id,
          muscleGroupId: mustGet(groups, exercise.primary),
          role: ExerciseMuscleRole.PRIMARY,
        },
        ...exercise.secondary.map((slug) => ({
          exerciseId: id,
          muscleGroupId: mustGet(groups, slug),
          role: ExerciseMuscleRole.SECONDARY,
        })),
      ],
    });

    await prisma.exerciseEquipment.deleteMany({ where: { exerciseId: id } });
    await prisma.exerciseEquipment.createMany({
      data: exercise.equipment.map((slug) => ({
        exerciseId: id,
        equipmentId: mustGet(equipmentIds, slug),
      })),
    });
  }
}

/**
 * Plans d'abonnement et correspondances produit chez les fournisseurs.
 * Identifiants produits FACTICES (remplacés par la vraie configuration
 * Stripe/RevenueCat via le tableau de bord de chaque fournisseur).
 */
const SUBSCRIPTION_PLANS = [
  { slug: 'free', name: 'Gratuit' },
  { slug: 'premium', name: 'Premium' },
];

const SUBSCRIPTION_PRODUCTS = [
  {
    plan: 'premium',
    provider: PaymentProvider.STRIPE,
    externalProductId: 'price_carlys_premium_monthly',
    billingPeriod: BillingPeriod.MONTHLY,
  },
  {
    plan: 'premium',
    provider: PaymentProvider.STRIPE,
    externalProductId: 'price_carlys_premium_yearly',
    billingPeriod: BillingPeriod.YEARLY,
  },
  {
    plan: 'premium',
    provider: PaymentProvider.REVENUECAT,
    externalProductId: 'carlys_premium_monthly',
    billingPeriod: BillingPeriod.MONTHLY,
  },
  {
    plan: 'premium',
    provider: PaymentProvider.REVENUECAT,
    externalProductId: 'carlys_premium_yearly',
    billingPeriod: BillingPeriod.YEARLY,
  },
];

async function seedSubscriptionPlans(): Promise<void> {
  for (const plan of SUBSCRIPTION_PLANS) {
    await prisma.subscriptionPlan.upsert({
      where: { slug: plan.slug },
      update: { name: plan.name },
      create: plan,
    });
  }

  const plans = new Map(
    (await prisma.subscriptionPlan.findMany()).map((plan) => [plan.slug, plan.id]),
  );
  for (const product of SUBSCRIPTION_PRODUCTS) {
    await prisma.subscriptionProduct.upsert({
      where: {
        provider_externalProductId: {
          provider: product.provider,
          externalProductId: product.externalProductId,
        },
      },
      update: { billingPeriod: product.billingPeriod },
      create: {
        planId: mustGet(plans, product.plan),
        provider: product.provider,
        externalProductId: product.externalProductId,
        billingPeriod: product.billingPeriod,
      },
    });
  }
}

/**
 * RBAC de l'administration. Le code est la SOURCE DE VÉRITÉ de la liste
 * des permissions (`ADMIN_PERMISSIONS` dans packages/api-contracts).
 */
const ADMIN_ROLES: { slug: string; name: string; permissions: readonly string[] }[] = [
  { slug: 'superadmin', name: 'Super-administrateur', permissions: ADMIN_PERMISSIONS },
  { slug: 'support', name: 'Support', permissions: ['user:read', 'audit:read'] },
  {
    // Le contenu, c'est aussi les médias : sans `media:write`, ce rôle ne
    // pourrait pas déposer la photo d'un exercice qu'il a le droit de publier.
    slug: 'content-manager',
    name: 'Gestion du contenu',
    permissions: [
      'exercise:read',
      'exercise:publish',
      'exercise:write',
      'media:read',
      'media:write',
    ],
  },
];

const DEV_ADMIN = { email: 'dev.admin@carlys.local', displayName: 'Dev Admin' };
const DEV_ADMIN_PASSWORD = 'Carlys-Admin-2026!';

async function seedAdministration(): Promise<void> {
  for (const permission of ADMIN_PERMISSIONS) {
    const [resource, action] = permission.split(':') as [string, string];
    await prisma.adminPermission.upsert({
      where: { resource_action: { resource, action } },
      update: {},
      create: { resource, action },
    });
  }
  const permissionIds = new Map(
    (await prisma.adminPermission.findMany()).map((permission) => [
      `${permission.resource}:${permission.action}`,
      permission.id,
    ]),
  );

  for (const role of ADMIN_ROLES) {
    const { id } = await prisma.adminRole.upsert({
      where: { slug: role.slug },
      update: { name: role.name },
      create: { slug: role.slug, name: role.name },
    });
    // Liens reconstruits à chaque seed (idempotent).
    await prisma.adminRolePermission.deleteMany({ where: { roleId: id } });
    await prisma.adminRolePermission.createMany({
      data: role.permissions.map((permission) => ({
        roleId: id,
        permissionId: mustGet(permissionIds, permission),
      })),
    });
  }

  const passwordHash = await argon2.hash(DEV_ADMIN_PASSWORD, { type: argon2.argon2id });
  const admin = await prisma.adminUser.upsert({
    where: { email: DEV_ADMIN.email },
    update: {},
    create: { email: DEV_ADMIN.email, displayName: DEV_ADMIN.displayName, passwordHash },
  });
  const superadmin = await prisma.adminRole.findUniqueOrThrow({
    where: { slug: 'superadmin' },
  });
  await prisma.adminUserRole.upsert({
    where: { adminUserId_roleId: { adminUserId: admin.id, roleId: superadmin.id } },
    update: {},
    create: { adminUserId: admin.id, roleId: superadmin.id },
  });
}

async function seedDevUsers(): Promise<void> {
  const passwordHash = await argon2.hash(DEV_PASSWORD, { type: argon2.argon2id });
  for (const user of DEV_USERS) {
    const { id } = await prisma.user.upsert({
      where: { email: user.email },
      update: {},
      create: {
        email: user.email,
        emailVerifiedAt: new Date(),
        profile: { create: { displayName: user.displayName } },
        credential: { create: { passwordHash } },
      },
    });

    // Le compte « premium » reçoit ses droits (attribution manuelle de dev).
    if (user.email === 'dev.premium@carlys.local') {
      for (const key of PREMIUM_ENTITLEMENT_KEYS) {
        await prisma.userEntitlement.upsert({
          where: { userId_entitlementKey: { userId: id, entitlementKey: key } },
          update: { isActive: true, expiresAt: null },
          create: { userId: id, entitlementKey: key, isActive: true },
        });
      }
    }
  }
}

function mustGet(map: Map<string, string>, key: string): string {
  const value = map.get(key);
  if (value === undefined) {
    throw new Error(`Seed incohérent : slug inconnu « ${key} »`);
  }
  return value;
}

async function main(): Promise<void> {
  await seedCatalog();
  await seedExerciseMedia(prisma);
  await seedSubscriptionPlans();
  await seedAdministration();
  await seedDevUsers();

  const [exercises, groups, equipment] = await Promise.all([
    prisma.exercise.count(),
    prisma.muscleGroup.count(),
    prisma.equipment.count(),
  ]);
  process.stdout.write(
    `Seed terminé : ${exercises} exercices, ${groups} groupes musculaires, ` +
      `${equipment} équipements.\n` +
      `Comptes de DÉVELOPPEMENT (jamais en production) :\n` +
      DEV_USERS.map((user) => `  - ${user.email} / ${DEV_PASSWORD}\n`).join('') +
      `  - ${DEV_ADMIN.email} / ${DEV_ADMIN_PASSWORD} (admin)\n`,
  );
}

main()
  .catch((error: unknown) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
