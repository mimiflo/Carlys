import {
  PROGRAM_FREE_LIMIT,
  type GeneratedProgram,
  type GenerationReport,
} from '@carlys/api-contracts';
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { UsersService } from '../../users/application/users.service';
import { EntitlementsService } from '../../subscriptions/application/entitlements.service';
import { BODYWEIGHT_SLUG, GENERATION_RULES_VERSION } from '../domain/generation/constants';
import { generateProgram } from '../domain/generation/generator';
import { GenerationRepository } from '../infrastructure/generation.repository';
import { ProgramsRepository } from '../infrastructure/programs.repository';
import { toRows } from './generation-rows';
import { presentProgramDetail } from './program.presenter';

export interface GenerateProgramInput {
  name?: string;
}

export interface GeneratedOutcome {
  /** 201 à la création, 200 au rejeu d'une génération déjà faite. */
  created: boolean;
  result: GeneratedProgram;
}

/** Les cinq entrées de profil, et la phrase qui dit ce qui manque. */
const REQUIRED_FIELDS: { field: string; message: string }[] = [
  { field: 'trainingGoal', message: 'Choisis ton objectif.' },
  { field: 'trainingExperience', message: 'Indique ton niveau.' },
  { field: 'weeklySessionsTarget', message: 'Dis combien de séances par semaine tu vises.' },
  { field: 'sessionMinutesTarget', message: 'Dis combien de temps dure une séance.' },
  {
    field: 'equipmentSlugs',
    message: 'Coche ton matériel, ou « Poids du corps » si tu n’as rien.',
  },
];

/**
 * LA GÉNÉRATION DE PROGRAMME — orchestrateur mince.
 *
 * Il ne décide rien : il rassemble (profil, droits, catalogue jouable), appelle
 * le moteur PUR de `domain/generation/`, et écrit. C'est la même couture que
 * `proposal.validator.ts` / `coach.service.ts`, le seul précédent de choix
 * d'exercices côté serveur dans ce dépôt.
 */
@Injectable()
export class ProgramGenerationService {
  constructor(
    private readonly programs: ProgramsRepository,
    private readonly generation: GenerationRepository,
    private readonly users: UsersService,
    private readonly entitlements: EntitlementsService,
    @InjectPinoLogger(ProgramGenerationService.name)
    private readonly logger: PinoLogger,
  ) {}

  async generate(
    userId: string,
    programId: string,
    input: GenerateProgramInput,
  ): Promise<GeneratedOutcome> {
    const existing = await this.programs.findById(programId);
    if (existing !== null && existing.userId !== userId) {
      throw new ConflictException('Cet identifiant appartient à un autre compte.');
    }
    if (existing !== null && existing.deletedAt !== null) {
      throw new NotFoundException('Programme supprimé.');
    }

    // REJEU : le programme existe déjà pour ce compte, on le rend TEL QUEL.
    // Deux raisons, et la seconde est la plus importante : un renvoi après
    // coupure ne doit pas créer un second programme ni consommer le plafond
    // du plan gratuit ; et si la personne a retouché son plan, régénérer
    // silencieusement effacerait son travail. « Régénérer » côté mobile, c'est
    // envoyer un NOUVEL identifiant — ce que l'écran fait déjà pour tout le
    // reste du domaine.
    if (existing !== null) {
      return {
        created: false,
        result: {
          program: presentProgramDetail(existing),
          report: this.storedReport(existing.generationReport),
        },
      };
    }

    const profile = await this.users.training(userId);
    this.assertComplete(profile);
    await this.assertQuota(userId);

    // Personne ne « possède » son corps : sans cette union, qui coche
    // {haltères, banc} perdrait les pompes et la planche. C'est aussi ce qui
    // garantit un kit NON VIDE — et c'est vital, parce que `notIn: []` est
    // vrai pour tout : sur un kit vide, le filtre d'inclusion exclurait le
    // catalogue entier au lieu de le laisser passer.
    const kit = [...new Set([...profile.equipmentSlugs, BODYWEIGHT_SLUG])].sort();
    const premium = await this.entitlements.hasEntitlement(userId, 'premium_exercises');
    const [pool, catalogue, equipmentNames] = await Promise.all([
      this.generation.playablePool(kit, profile.trainingExperience!, premium),
      this.generation.fullCatalogue(),
      this.generation.equipmentNames(),
    ]);

    const outcome = generateProgram({
      programId,
      goal: profile.trainingGoal!,
      experience: profile.trainingExperience!,
      weeklySessionsTarget: profile.weeklySessionsTarget!,
      sessionMinutesTarget: profile.sessionMinutesTarget!,
      equipmentSlugs: kit,
      // Le moteur reçoit le pool jouable pour CHOISIR et le catalogue entier
      // pour CONSEILLER : il ne peut pas prescrire ce qu'il n'a pas, et il
      // peut dire ce qui manquerait. Deux listes, jamais une.
      pool,
      catalogue,
      equipmentNames,
    });

    if (outcome.kind === 'impossible') {
      throw new ConflictException({
        message: outcome.message,
        details: [
          { field: 'equipmentSlugs', message: outcome.message },
          ...outcome.levers.map((lever) => ({
            field: 'equipmentSlugs',
            message: `« ${lever.name} » ouvrirait ${lever.unlocks} exercices (${lever.muscleGroups.join(', ')}).`,
          })),
        ],
      });
    }

    const rows = toRows(userId, programId, outcome.program, outcome.report, input.name);
    await this.generation.writeGenerated(
      rows.program,
      rows.templates,
      rows.exercises,
      rows.sets,
      rows.days,
    );
    this.logger.info(
      {
        programId,
        goal: profile.trainingGoal,
        experience: profile.trainingExperience,
        rulesVersion: GENERATION_RULES_VERSION,
        catalogueSize: catalogue.length,
        poolSize: pool.length,
        status: outcome.report.status,
        relaxations: outcome.report.relaxations.map((relaxation) => relaxation.code),
      },
      'program.generated',
    );

    const saved = await this.programs.findById(programId);
    if (saved === null) throw new NotFoundException('Programme introuvable.');
    return {
      created: true,
      result: { program: presentProgramDetail(saved), report: outcome.report },
    };
  }

  /**
   * 400 qui liste TOUT ce qui manque, en une seule réponse.
   *
   * Une entrée par requête obligerait l'écran de profil à découvrir les
   * manques un par un. Et aucun défaut n'est inventé : le contrat le dit déjà,
   * « la génération liste ce qui manque, elle n'invente rien ». Un niveau par
   * défaut serait le pire des deux mondes — un pratiquant avancé recevrait
   * huit semaines de machines guidées et conclurait que l'application est
   * inutile, sans jamais savoir qu'une case n'était pas cochée.
   */
  private assertComplete(profile: {
    trainingGoal: unknown;
    trainingExperience: unknown;
    weeklySessionsTarget: unknown;
    sessionMinutesTarget: unknown;
    equipmentSlugs: string[];
  }): void {
    const values: Record<string, unknown> = {
      trainingGoal: profile.trainingGoal,
      trainingExperience: profile.trainingExperience,
      weeklySessionsTarget: profile.weeklySessionsTarget,
      sessionMinutesTarget: profile.sessionMinutesTarget,
      // Une liste VIDE est indistinguable de « je n'ai pas répondu ». La vraie
      // réponse « je n'ai rien » est `['poids-du-corps']`, et le message le dit.
      equipmentSlugs: profile.equipmentSlugs.length > 0 ? profile.equipmentSlugs : null,
    };
    const missing = REQUIRED_FIELDS.filter(
      (entry) => values[entry.field] === null || values[entry.field] === undefined,
    );
    if (missing.length > 0) {
      throw new BadRequestException({
        message: 'Complète ton profil d’entraînement avant de générer.',
        details: missing,
      });
    }
  }

  /** Même plafond que l'écriture manuelle, et seulement à la création. */
  private async assertQuota(userId: string): Promise<void> {
    const unlimited = await this.entitlements.hasEntitlement(userId, 'unlimited_programs');
    if (unlimited) return;
    const count = await this.programs.countLive(userId);
    if (count >= PROGRAM_FREE_LIMIT) {
      throw new ForbiddenException(
        `Le plan gratuit garde ${PROGRAM_FREE_LIMIT} programmes. Passe Premium pour en créer davantage.`,
      );
    }
  }

  /** Un programme écrit à la main n'a pas de rapport : on le dit plutôt que de mentir. */
  private storedReport(stored: unknown): GenerationReport {
    if (stored !== null && typeof stored === 'object') return stored as GenerationReport;
    return {
      status: 'relaxed',
      rulesVersion: 0,
      goal: '',
      experience: '',
      sessionsPerWeek: 0,
      split: [],
      templatedDays: 0,
      freeLabelDays: 0,
      restDays: 0,
      templatesCreated: 0,
      weeklyVolume: [],
      uncoveredGroups: [],
      relaxations: [],
      notes: ['Ce programme n’a pas été engendré : il a été composé à la main.'],
    };
  }
}
