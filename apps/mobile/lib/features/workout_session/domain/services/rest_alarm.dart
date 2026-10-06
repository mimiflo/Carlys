/// Le signal de FIN DE REPOS, qui doit sonner même écran éteint.
///
/// Écran noir, le téléphone suspend l'application : son minuteur ne peut
/// plus rien annoncer. Seul le système le peut, si on le lui demande à
/// l'avance. Ce port est la frontière avec lui : le minuteur se teste contre
/// un faux, et aucun test ne touche un greffon de plateforme.
abstract class RestAlarm {
  /// Programme le signal dans [after] ; remplace celui d'un repos précédent.
  Future<void> schedule(Duration after);

  /// Retire le signal programmé (repos passé, séance close).
  Future<void> cancel();
}
