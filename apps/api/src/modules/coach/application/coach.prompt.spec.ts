import { CarlysProfile, MentorStyle } from '@prisma/client';
import {
  COACH_SYSTEM_PROMPT,
  carlysProfileBriefing,
  looksVolatile,
  mentorStyleBriefing,
  mentorVoiceBriefing,
  volatileContext,
} from './coach.prompt';
import { COACH_TOOLS, PROPOSE_SESSION_TOOL } from './coach.tools';

/**
 * Préfixe mis en cache et périmètre du coach.
 *
 * Deux pièges silencieux sont gardés ici : une donnée volatile glissée dans le
 * préfixe (rien n'échoue, la facture double), et un prompt qui oublierait de
 * dire ce que le coach ne sait pas (il inventerait pour combler).
 */
describe('Prompt du coach', () => {
  it('le préfixe mis en cache ne contient aucune donnée volatile', () => {
    // Le fournisseur met en cache outils + prompt système. Une date, une heure
    // ou un identifiant dans ce bloc invalide la relecture à chaque appel.
    const prefix = COACH_SYSTEM_PROMPT + JSON.stringify(COACH_TOOLS);

    expect(looksVolatile(prefix)).toBe(false);
  });

  it('le rappel de date vit APRÈS la césure, dans le message', () => {
    const context = volatileContext(new Date('2026-08-09T10:00:00.000Z'));

    expect(context).toContain('2026-08-09');
    // Il est volatile par nature : sa place est dans le message, pas au-dessus.
    expect(looksVolatile(context)).toBe(true);
  });

  it('le prompt énonce ce que le coach IGNORE', () => {
    // Sans ces bornes, le modèle comble les vides avec du plausible.
    expect(COACH_SYSTEM_PROMPT).toContain('journal alimentaire');
    // Le journal alimentaire EXISTE (module nutrition) : le prompt ne doit
    // plus affirmer le contraire, et doit nommer l'outil qui le lit.
    expect(COACH_SYSTEM_PROMPT).not.toContain("n'a pas de journal alimentaire");
    expect(COACH_SYSTEM_PROMPT).toContain('get_recent_meals');
    expect(COACH_SYSTEM_PROMPT).toContain('sommeil');
    expect(COACH_SYSTEM_PROMPT).toContain('professionnel de santé');
    expect(COACH_SYSTEM_PROMPT).toContain("N'invente jamais");
  });

  it('le prompt interdit les identifiants d’exercice inventés', () => {
    expect(COACH_SYSTEM_PROMPT).toContain('exerciseId');
  });

  it('le prompt proscrit le tiret long, et prêche par l’exemple', () => {
    // Le tic d'écriture qui trahit la machine : la consigne doit exister,
    // et le prompt lui-même ne doit pas contenir ce qu'il interdit.
    expect(COACH_SYSTEM_PROMPT).toContain('tiret long');
    expect(COACH_SYSTEM_PROMPT).not.toContain('—');
    for (const profile of Object.values(CarlysProfile)) {
      expect(carlysProfileBriefing(profile)).not.toContain('—');
    }
  });

  it('chaque outil dit QUAND l’appeler, pas seulement ce qu’il fait', () => {
    for (const tool of COACH_TOOLS) {
      expect(tool.description.length).toBeGreaterThan(60);
      expect(tool.description).toMatch(/Appelle-le|ATTENTION|N’écrit RIEN/);
    }
  });

  it('un seul outil produit une sortie structurée, et il n’écrit rien', () => {
    const names = COACH_TOOLS.map((tool) => tool.name);

    expect(names).toContain(PROPOSE_SESSION_TOOL);
    // Aucun autre outil ne porte un verbe d'écriture : le coach ne mute rien.
    const writers = names.filter((name) => /^(create|update|delete|save|add|set)_/.test(name));
    expect(writers).toEqual([]);
  });

  it('looksVolatile repère les trois formes qui cassent le cache', () => {
    expect(looksVolatile('nous sommes le 2026-08-09')).toBe(true);
    expect(looksVolatile('il est 14:32')).toBe(true);
    expect(looksVolatile('requête 3f2504e0-4f89-41d3-9a0c-0305e82c3301')).toBe(true);
    expect(looksVolatile('Tu es le coach de Carlys.')).toBe(false);
  });
});

/**
 * Briefing de profil Carlys — le bloc système PAR UTILISATEUR.
 *
 * Le piège gardé ici est le même que pour la date : un nom de profil glissé
 * dans le préfixe partagé le fragmenterait en quatre variantes de cache,
 * sans qu'aucun test ne rougisse — `looksVolatile` ne voit que dates, heures
 * et UUID.
 */
describe('Briefing de profil Carlys', () => {
  it('le préfixe partagé ne cite AUCUN profil : il resterait identique pour tous', () => {
    for (const profile of Object.values(CarlysProfile)) {
      expect(COACH_SYSTEM_PROMPT).not.toContain(profile);
    }
  });

  it('chaque profil a un briefing court, nommé, et sans donnée volatile', () => {
    for (const profile of Object.values(CarlysProfile)) {
      const briefing = carlysProfileBriefing(profile);

      expect(briefing).not.toBe('');
      // Le modèle doit savoir DE QUELLE identité on parle.
      expect(briefing).toContain('profil Carlys');
      // La même discipline que le reste du prompt : court.
      expect(briefing.length).toBeLessThan(400);
      // Sûr à placer n'importe où par rapport à la césure.
      expect(looksVolatile(briefing)).toBe(false);
    }
  });

  it('sans profil choisi, aucun briefing — jamais un profil deviné', () => {
    expect(carlysProfileBriefing(null)).toBe('');
  });

  it('le briefing parle d’angle, pas de chiffres', () => {
    // Les chiffres viennent des outils : un briefing qui prescrirait des
    // charges ou des pourcentages contournerait toute la doctrine du prompt.
    for (const profile of Object.values(CarlysProfile)) {
      expect(carlysProfileBriefing(profile)).not.toMatch(/\d/);
    }
  });
});

/**
 * Voix du Mentor — le second axe du bloc système par utilisateur.
 *
 * La règle gardée ici est celle de la COMPOSITION : 4 briefings de profil
 * plus 4 de style, jamais 16 croisements écrits à la main. Et la même
 * discipline de cache que le profil : aucun style dans le préfixe partagé.
 */
describe('Voix du Mentor', () => {
  it('le préfixe partagé ne cite AUCUN style : il reste identique pour tous', () => {
    for (const style of Object.values(MentorStyle)) {
      expect(COACH_SYSTEM_PROMPT).not.toContain(style);
    }
  });

  it('chaque style a un briefing court, nommé, sans chiffre ni volatile', () => {
    for (const style of Object.values(MentorStyle)) {
      const briefing = mentorStyleBriefing(style);

      expect(briefing).not.toBe('');
      expect(briefing).toContain('Mentor');
      expect(briefing.length).toBeLessThan(400);
      expect(looksVolatile(briefing)).toBe(false);
      expect(briefing).not.toMatch(/\d/);
      expect(briefing).not.toContain('—');
    }
  });

  it('les quatre voix disent des choses DIFFÉRENTES : le contenu change vraiment', () => {
    const briefings = Object.values(MentorStyle).map(mentorStyleBriefing);
    expect(new Set(briefings).size).toBe(briefings.length);
  });

  it('sans style choisi, aucun briefing — jamais une voix devinée', () => {
    expect(mentorStyleBriefing(null)).toBe('');
  });

  it('profil et style se COMPOSENT : les deux, un seul, ou rien', () => {
    const deux = mentorVoiceBriefing({
      carlysProfile: CarlysProfile.STRATEGE,
      mentorStyle: MentorStyle.EXIGEANT,
    });
    expect(deux).toContain(carlysProfileBriefing(CarlysProfile.STRATEGE));
    expect(deux).toContain(mentorStyleBriefing(MentorStyle.EXIGEANT));
    // Deux blocs séparés, pas une phrase fusionnée : chacun reste relisible.
    expect(deux).toContain('\n\n');

    const profilSeul = mentorVoiceBriefing({
      carlysProfile: CarlysProfile.ATHLETE,
      mentorStyle: null,
    });
    expect(profilSeul).toBe(carlysProfileBriefing(CarlysProfile.ATHLETE));

    const styleSeul = mentorVoiceBriefing({
      carlysProfile: null,
      mentorStyle: MentorStyle.PHILOSOPHE,
    });
    expect(styleSeul).toBe(mentorStyleBriefing(MentorStyle.PHILOSOPHE));

    expect(mentorVoiceBriefing({ carlysProfile: null, mentorStyle: null })).toBe('');
  });

  it('les DEUX axes ATHLETE composés restent lisibles, sans redite mot à mot', () => {
    // Le seul nom partagé par les deux énumérations : la composition doit
    // rester deux blocs distincts, pas un doublon.
    const voix = mentorVoiceBriefing({
      carlysProfile: CarlysProfile.ATHLETE,
      mentorStyle: MentorStyle.ATHLETE,
    });
    const [profil, style] = voix.split('\n\n');
    expect(profil).not.toBe(style);
  });
});
