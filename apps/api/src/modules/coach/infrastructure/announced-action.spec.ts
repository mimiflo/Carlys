import { asksForPlan, mayAnnounceAction, probeFor } from './announced-action';

/**
 * Le premier étage, large : la fin du message parle-t-elle d'une suite ?
 * Les phrases ci-dessous viennent de Qwen3-4B (1er octobre 2026). Le second
 * étage (l'occasion d'agir, dans le client) tranche ensuite par un FAIT :
 * le modèle appelle un outil, ou répond « FIN ».
 */
describe('mayAnnounceAction', () => {
  it('reconnaît les promesses constatées, où qu’elles se cachent dans la fin', () => {
    for (const promise of [
      // La capture du propriétaire : trois paragraphes, puis cette promesse.
      'On commence par des mouvements de fond. Je vais t’adapter une séance à partir de ton profil.',
      // Une dernière phrase anodine cache la promesse : les DEUX dernières comptent.
      'T’as déjà un profil d’entraînement, je vais te le montrer. C’est là que je commence.',
      'Je cherche des exercices pour les pecs dans le catalogue. Une minute.',
      'Vérifions d’abord ce que tu as déjà enregistré récemment.',
      'Je regarde ça tout de suite et je reviens vers toi avec les chiffres.',
      'Un programme de trois séances te correspondra bien. Je m’occupe de le mettre en place.',
      'Je te prépare une séance tout de suite.',
      'Je t’adapte un programme à partir de tes séances.',
      'Laisse-moi te préparer un programme.',
      'Voici ce que je te propose :',
      'On va regarder tes dernières séances ensemble.',
      // Constaté : un émoji final masquait la promesse.
      'Je t’explique tout ça dans une séance que je t’envoie. Tu pourras la suivre pas à pas. ✅',
    ]) {
      expect(mayAnnounceAction(promise)).toBe(true);
    }
  });

  it('laisse passer les fins ordinaires, sans même une occasion d’agir', () => {
    for (const ordinary of [
      'Garde tes trois séries de 8 à 70 kg. Si elles passent proprement, monte à 72,5 kg.',
      'Bois bien, dors suffisamment. Si la douleur dure, consulte un médecin.',
      'Avec plaisir ! Bonne séance, et dis-moi comment ça s’est passé.',
      'Prépare-toi à des courbatures les premiers jours.',
      'D’abord, échauffe-toi 10 minutes.',
      'Repose-toi 2 à 3 minutes entre les séries.',
      // Une question rend la main à la personne : ce n'est pas une promesse.
      'Tu veux que je t’ajoute une séance complète avec ces exercices ?',
      'Il me faut ton objectif. Tu veux que je consulte ton profil ?',
      '',
    ]) {
      expect(mayAnnounceAction(ordinary)).toBe(false);
    }
  });
});

describe('probeFor', () => {
  // Constaté : la séance écrite en texte, puis « j'ai fait une séance de
  // base » — aucune carte, rien à lancer.
  const claimed =
    'Voici une séance haut du corps :\n\n1. Développé couché haltères\n2. Pompes\n\n' +
    "Je t'explique pourquoi : j'ai fait une séance de base avec des haltères. Ce choix est concret.";

  it('une séance donnée pour faite reçoit un ORDRE : lire les identifiants, puis proposer', () => {
    for (const answer of [
      claimed,
      "J'ai préparé un programme de trois séances par semaine. Bon courage !",
    ]) {
      const probe = probeFor(answer, 'Salut', false)?.text;
      expect(probe).toContain('propose_session');
      expect(probe).toContain('search_exercises');
      expect(probe).not.toContain('FIN');
    }
  });

  it('une séance DEMANDÉE et pas proposée reçoit l’ordre, quoi que dise la réponse', () => {
    // Constaté : « L'adaptation est faite pour t'offrir une séance réaliste »,
    // sans carte — aucune tournure à reconnaître, la demande suffit.
    const answer = 'L’adaptation est faite pour t’offrir une séance réaliste, sans excès.';
    expect(
      probeFor(answer, 'Je veux une séance haut du corps avec haltères', false)?.text,
    ).toContain('propose_session');
    // Une question posée en retour rend la main : pas d'ordre.
    expect(probeFor('Combien de temps as-tu ?', 'Fais-moi une séance', false)).toBeNull();
  });

  it('une fin qui parle d’une suite reçoit une question qui CITE cette fin', () => {
    const probe = probeFor(
      'Premier paragraphe. Deuxième. On commence par le squat. Je vais t’adapter les charges.',
      'Comment progresser ?',
      false,
    )?.text;
    expect(probe).toContain('« On commence par le squat. Je vais t’adapter les charges. »');
    expect(probe).not.toContain('Premier paragraphe');
    expect(probe).toContain('FIN');
  });

  it('ses données citées sans lecture : l’ordre de les lire, et la réponse sera REMPLACÉE', () => {
    // Constaté : « Tu as déjà des records de soulevé de terre », rien lu.
    const answer = 'Tu as déjà des records de soulevé de terre, j’ajuste le volume.';
    const probe = probeFor(answer, 'Par quoi je commence ?', false);
    expect(probe?.keep).toBe(false);
    expect(probe?.text).toContain('sans les avoir lues');
    // Lues dans le tour (avant lui ou par lui) : rien à redire sur ce point.
    expect(probeFor('Ton record au squat est de 80 kg. Bravo.', 'Mon record ?', true)).toBeNull();
    // Des conseils, pas des données inventées : l'objectif et le niveau lui sont donnés.
    for (const advice of [
      'Selon ton objectif, vise 3 séries de 10.',
      'D’après ton niveau, commence léger.',
      'Pour ton volume, fais 3 séances par semaine.',
      'Augmente ton max de 2,5 kg par semaine.',
      'Si tu as fait 3 séances, repose-toi.',
      'Basée sur ce que tu as déjà soulevé, la charge monte doucement.',
    ]) {
      expect(probeFor(advice, 'Des conseils ?', false)?.keep).not.toBe(false);
    }
  });

  it('une séance annoncée au présent, ou PRESCRITE en texte, reçoit l’ordre (constaté)', () => {
    for (const answer of [
      // Le cas signalé : « Par où je commence ? », la séance en texte, sans carte.
      'Pour travailler les pecs, tu peux commencer avec des pompes. J’adapte une séance avec ' +
        'les pompes, idéales pour débuter. Tu peux faire 3 séries de 10 répétitions. C’est doux.',
      'Je t’adapte une séance avec des mouvements que tu as récemment faits.',
      'Commence par le squat gobelet en 4×8, puis les fentes. Bon courage !',
    ]) {
      expect(probeFor(answer, 'Des idées ?', true)?.text).toContain('propose_session');
    }
    // Des chiffres qui ne prescrivent rien.
    for (const answer of [
      'Ton record au squat est de 80 kg pour 5 répétitions.',
      'Tu as fait 7 séances ce mois-ci, bravo.',
      'Vise entre 6 et 12 répétitions pour l’hypertrophie.',
      // Une offre posée en question rend la main.
      'Tu veux que je te prépare une séance ?',
    ]) {
      expect(probeFor(answer, 'Des chiffres ?', true)).toBeNull();
    }
  });

  it('une réponse complète, sans demande de séance : rien', () => {
    expect(probeFor('Bois de l’eau et dors bien.', 'Des conseils de récup ?', false)).toBeNull();
  });
});

describe('asksForPlan', () => {
  it('reconnaît une demande de séance ou de programme', () => {
    for (const request of [
      'Je veux une séance haut du corps avec haltères',
      'Fais-moi une séance pour ce soir, j’ai 30 minutes',
      'Propose-moi un programme pour prendre du muscle',
      'Quelle séance je fais demain ?',
      'Une séance pour les jambes ?',
      'J’aimerais un programme de remise en forme',
      // Sans verbe : constaté, la séance arrivait écrite, sans carte.
      'Une séance full body rapide au poids du corps ?',
      'Un programme force sur 4 semaines ?',
      // Débuter : il attend un plan (constaté, sans carte).
      'Par où je commence ?',
      'Par quoi je commence pour me muscler ?',
      'Je débute, tu me conseilles quoi ?',
    ]) {
      expect(asksForPlan(request)).toBe(true);
    }
  });

  it('pas une question sur les séances : « combien de séries », « mes records »', () => {
    for (const request of [
      'Combien de séries par muscle et par semaine ?',
      'Quel est mon record au squat ?',
      'Explique-moi la surcharge progressive',
      'Merci beaucoup !',
      'Mes dernières séances étaient bien ?',
      'C’est quoi une bonne séance ?',
      'Mon programme me fatigue, normal ?',
      'Ma séance d’hier était dure, j’ai soulevé combien ?',
    ]) {
      expect(asksForPlan(request)).toBe(false);
    }
  });
});
