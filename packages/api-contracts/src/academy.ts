/**
 * Les leçons de l'Académie, par identifiant — celles du pack embarqué dans
 * l'application (`apps/mobile/assets/academy/pack.json`, version 4).
 *
 * Le serveur n'accepte une réponse de quiz que pour l'une d'elles : un
 * identifiant inventé ouvrait autant de « bonnes réponses » qu'on voulait,
 * chacune créditant la ligue et les défis. Un test de l'API compare cette
 * liste au pack : ajouter une leçon au pack sans l'ajouter ici échoue en CI,
 * avant qu'une réponse légitime ne soit refusée.
 */
export const ACADEMY_LESSON_IDS = [
  'anatomie-pectoraux',
  'anatomie-dos',
  'anatomie-epaules',
  'anatomie-biceps',
  'anatomie-triceps',
  'anatomie-avant-bras',
  'anatomie-abdominaux',
  'anatomie-lombaires',
  'anatomie-fessiers',
  'anatomie-quadriceps',
  'anatomie-ischio-jambiers',
  'anatomie-mollets',
  'technique-progression',
  'technique-amplitude',
  'technique-repos',
  'technique-echauffement',
  'nutrition-proteines',
  'nutrition-calories',
  'nutrition-hydratation',
  'nutrition-glucides',
  'nutrition-autour-seance',
  'recuperation-sommeil',
  'recuperation-courbatures',
  'recuperation-frequence',
  'recuperation-active',
  'recuperation-decharge',
  'cardio-zones',
  'cardio-avant-apres',
  'cardio-dose',
  'cardio-choix',
  'mobilite-avant-apres',
  'mobilite-amplitude',
  'mobilite-regularite',
  'mobilite-intensite',
  'mental-discipline',
  'mental-tout-ou-rien',
  'mental-objectifs',
  'mental-comparaison',
  'blessures-progressivite',
  'blessures-douleur',
  'blessures-technique',
  'blessures-reprise',
  'mythes-localise',
  'mythes-courbatures',
  'mythes-transformation',
  'mythes-femmes-muscle',
  'hyrox-format',
  'hyrox-transitions',
  'hyrox-allure',
  'hyrox-course-chargee',
  'running-volume-facile',
  'running-mur',
  'running-sortie-longue',
  'running-renforcement',
  'calisthenics-progressions',
  'calisthenics-tirage',
  'calisthenics-jambes',
  'calisthenics-gainage',
] as const;

/**
 * Bonnes réponses qui comptent aux défis et à la ligue, par jour (le jour
 * LOCAL déclaré par l'appareil). Les suivantes sont enregistrées — la
 * progression de l'Académie les garde —, mais ne rapportent plus rien.
 */
export const QUIZ_CORRECT_CREDITED_PER_DAY = 3;
