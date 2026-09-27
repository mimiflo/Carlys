import 'package:uuid/uuid.dart';

/// L'IDENTIFIANT D'UNE CRÉATION, stable d'un essai à l'autre du MÊME geste.
///
/// Les créations qui partent au serveur (un défi entre amis, un programme)
/// portent un identifiant né sur l'appareil, et le serveur est idempotent
/// par identifiant : un rejeu retombe sur l'objet déjà créé. Encore faut-il
/// REJOUER le même identifiant. Tiré à chaque appel, il ne servait jamais :
/// une réponse perdue après l'écriture (délai de réception dépassé, réseau
/// coupé au retour) disait « réessaie », et le nouvel essai créait un SECOND
/// défi, avec une seconde invitation à chaque ami.
///
/// La règle : le même brouillon (au sens de `==`) garde son identifiant tant
/// que son envoi n'a pas abouti ; un brouillon différent est un autre geste,
/// avec un autre identifiant. Le brouillon en attente se relit
/// ([pendingDraft]) pour rouvrir la feuille pré-remplie.
///
/// Il appartient au COMPTE : la purge locale renouvelle les providers qui en
/// tiennent un, sans quoi le compte suivant rejouerait l'identifiant, et le
/// brouillon, du précédent.
class CreationIdentity<T extends Object> {
  ({T draft, String id})? _pending;

  /// Le brouillon du dernier envoi qui n'a pas abouti, ou `null`.
  T? get pendingDraft => _pending?.draft;

  /// L'identifiant sous lequel envoyer [draft] : celui de l'envoi précédent
  /// s'il portait le MÊME brouillon, un neuf sinon.
  String idFor(T draft) {
    final pending = _pending;
    if (pending != null && pending.draft == draft) {
      return pending.id;
    }
    final id = const Uuid().v4();
    _pending = (draft: draft, id: id);
    return id;
  }

  /// L'envoi a abouti : le brouillon suivant sera un AUTRE geste.
  void settle() => _pending = null;
}
