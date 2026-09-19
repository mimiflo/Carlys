import {
  type ExerciseDifficulty,
  type ExerciseType,
  type TrainingExperience,
  type TrainingGoal,
} from '@prisma/client';
import { type GenerationReport } from '@carlys/api-contracts';

/**
 * Un exercice tel que le MOTEUR le voit.
 *
 * Volontairement pauvre : pas de description, pas de média, pas de date. Le
 * repository a déjà écarté ce qui ne se joue pas (matériel hors du kit,
 * difficulté au-dessus du plafond, exercice premium sans droit), donc tout ce
 * qui arrive ici est jouable. Le moteur n'a plus qu'à choisir et à doser.
 */
export interface PoolExercise {
  id: string;
  slug: string;
  name: string;
  /** Slug du groupe musculaire PRINCIPAL. */
  primary: string;
  /** Slugs des groupes secondaires, dans l'ordre du catalogue. */
  secondary: string[];
  difficulty: ExerciseDifficulty;
  type: ExerciseType;
  tags: string[];
  equipment: string[];
}

/** Les cinq entrées de profil, toutes obligatoires : le service les exige. */
export interface GenerationInput {
  /** Fourni par l'appareil. C'est aussi la graine de la rotation. */
  programId: string;
  goal: TrainingGoal;
  experience: TrainingExperience;
  weeklySessionsTarget: number;
  sessionMinutesTarget: number;
  /** Kit déclaré, `poids-du-corps` compris (le service l'ajoute). */
  equipmentSlugs: string[];
  /**
   * Ce que le moteur peut PRESCRIRE : déjà filtré par matériel, difficulté et
   * droits. Rien d'autre n'entre jamais dans un programme.
   */
  pool: PoolExercise[];
  /**
   * Le catalogue ENTIER, pour CONSEILLER — et pour cela seulement.
   *
   * Il faut voir ce qui n'est pas jouable pour dire ce qu'un achat
   * débloquerait. Le séparer du pool n'est pas une élégance : les mêmes
   * exercices dans une seule liste, et le moteur prescrirait un développé
   * couché à quelqu'un qui n'a pas de barre.
   */
  catalogue: PoolExercise[];
  /**
   * Les NOMS d'affichage du matériel, par slug.
   *
   * Le rapport écrit des phrases destinées à être lues telles quelles : y
   * laisser passer un slug donne « ajoute halteres », sans accent et sans
   * majuscule, c'est-à-dire un identifiant de base de données montré à
   * quelqu'un. La traduction se fait ICI, là où la phrase se compose, et non
   * dans chaque client qui l'afficherait.
   */
  equipmentNames: Record<string, string>;
}

/** Une série prescrite. `targetWeightKg` n'existe pas : voir `goal-rules.ts`. */
export interface PrescribedSet {
  position: number;
  targetReps: number | null;
  /**
   * Cible en SECONDES pour un maintien ou un bloc de cardio.
   *
   * Elle n'existait pas quand la génération a été écrite : la durée partait
   * alors dans la note de l'exercice, faute de champ où la loger. Le champ
   * existe maintenant, et la note n'a plus à porter une donnée.
   */
  targetDurationSeconds: number | null;
  restSeconds: number;
}

export interface PrescribedExercise {
  exerciseId: string;
  exerciseName: string;
  position: number;
  notes: string | null;
  sets: PrescribedSet[];
}

/** Un modèle de séance, à écrire tel quel dans `WorkoutTemplate`. */
export interface PrescribedTemplate {
  /** Dérivé de (programId, créneau, semaine) — jamais tiré au sort. */
  id: string;
  name: string;
  notes: string;
  exercises: PrescribedExercise[];
}

/** Une case du calendrier. `templateId` nul = repos ou séance à intitulé libre. */
export interface PrescribedDay {
  id: string;
  weekNumber: number;
  dayOfWeek: number;
  templateId: string | null;
  label: string;
  isRest: boolean;
}

export interface PrescribedProgram {
  name: string;
  description: string;
  weeksCount: number;
  days: PrescribedDay[];
  templates: PrescribedTemplate[];
}

/** Un matériel qui débloquerait des exercices, et combien. */
export interface EquipmentLever {
  slug: string;
  /** Nom d'affichage — c'est LUI qui part dans les phrases du rapport. */
  name: string;
  /** Exercices de force gagnés en PRINCIPAL sur les groupes qui manquent. */
  unlocks: number;
  muscleGroups: string[];
}

/**
 * Le résultat du moteur : soit un programme, soit un refus qui NOMME.
 *
 * Le refus n'est pas une panne, c'est une réponse : il dit quel groupe reste
 * introuvable et quel matériel le débloquerait — calculé sur le catalogue,
 * jamais écrit en dur. Un générateur qui se tait laisse la personne acheter
 * du matériel au hasard.
 */
export type GenerationOutcome =
  | { kind: 'program'; program: PrescribedProgram; report: GenerationReport }
  | {
      kind: 'impossible';
      blockingGroups: string[];
      levers: EquipmentLever[];
      message: string;
    };
