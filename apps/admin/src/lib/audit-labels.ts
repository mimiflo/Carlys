import type { StatusTone } from './status-labels';

/**
 * Les actions du journal d'audit, en français.
 *
 * L'API écrit des identifiants (`admin.user_suspended`) : stables, pensés pour
 * la recherche, illisibles d'un coup d'œil. L'écran montre la phrase ; une
 * action absente de cette table garde son identifiant, jamais une ligne vide.
 */
const ACTIONS: Record<string, string> = {
  'account.delete_failed': 'Suppression de compte échouée',
  'account.delete_without_password': 'Suppression de compte sans mot de passe',
  'account.deleted': 'Compte supprimé par son titulaire',
  'account.deleted_by_operator': 'Compte supprimé par l’exploitation',
  'admin.community_report_reopened': 'Signalement rouvert',
  'admin.community_report_resolved': 'Signalement résolu',
  'admin.entitlement_granted': 'Droit premium offert',
  'admin.entitlement_released': 'Droit premium rendu aux paiements',
  'admin.entitlement_revoked': 'Droit premium coupé',
  'admin.exercise_categories_updated': 'Catégories d’un exercice modifiées',
  'admin.exercise_deleted': 'Exercice supprimé',
  'admin.exercise_media_attached': 'Photo d’exercice ajoutée',
  'admin.exercise_media_detached': 'Photo d’exercice retirée',
  'admin.exercise_published': 'Exercice publié',
  'admin.exercise_restored': 'Exercice restauré',
  'admin.exercise_unpublished': 'Exercice masqué',
  'admin.login': 'Connexion administrateur',
  'admin.login_blocked_lockout': 'Connexion admin bloquée (verrou)',
  'admin.login_failed': 'Connexion admin refusée',
  'admin.media_deleted': 'Média supprimé',
  'admin.media_uploaded': 'Média téléversé',
  'admin.muscle_group_created': 'Catégorie créée',
  'admin.muscle_group_deleted': 'Catégorie supprimée',
  'admin.muscle_group_updated': 'Catégorie modifiée',
  'admin.totp_blocked_lockout': 'Code de vérification bloqué (verrou)',
  'admin.totp_enrolled': 'Double authentification activée',
  'admin.totp_failed': 'Code de vérification refusé',
  'admin.totp_frozen': 'Double authentification gelée',
  'admin.totp_issued': 'Double authentification émise',
  'admin.totp_not_issued': 'Double authentification non émise',
  'admin.user_reactivated': 'Compte réactivé',
  'admin.user_suspended': 'Compte suspendu',
  'auth.email_verification_resend_throttled': 'Renvoi de vérification freiné',
  'auth.email_verification_resent': 'E-mail de vérification renvoyé',
  'auth.email_verified': 'Adresse e-mail vérifiée',
  'auth.login': 'Connexion',
  'auth.login_blocked_lockout': 'Connexion bloquée (verrou)',
  'auth.login_failed': 'Connexion refusée',
  'auth.logout': 'Déconnexion',
  'auth.password_change_failed': 'Changement de mot de passe refusé',
  'auth.password_changed': 'Mot de passe changé',
  'auth.password_reset': 'Mot de passe réinitialisé',
  'auth.password_reset_requested': 'Réinitialisation demandée',
  'auth.password_reset_requested_unknown': 'Réinitialisation pour une adresse inconnue',
  'auth.password_reset_throttled': 'Réinitialisation freinée',
  'auth.refresh_reuse_detected': 'Réutilisation de jeton détectée',
  'auth.registered': 'Inscription',
  'auth.session_revoked': 'Appareil déconnecté',
  'auth.sessions_revoked_all': 'Tous les appareils déconnectés',
  'auth.social_attach_conflict': 'Conflit de connexion sociale',
  'auth.social_claimed_unverified_account': 'Compte non vérifié repris par connexion sociale',
  'auth.social_linked': 'Connexion sociale associée',
  'auth.social_login': 'Connexion sociale',
  'auth.social_login_blocked': 'Connexion sociale bloquée',
  'auth.social_login_refused_unverified_email': 'Connexion sociale refusée (e-mail non vérifié)',
  'auth.social_registered': 'Inscription par connexion sociale',
};

export function auditActionLabel(action: string): string {
  return ACTIONS[action] ?? action;
}

/**
 * La teinte d'une action : un refus ou un blocage se repère dans la liste,
 * une alerte de sécurité (jeton réutilisé) ressort en rouge. Le libellé, lui,
 * dit toujours ce qui s'est passé.
 */
export function auditActionTone(action: string): StatusTone {
  if (/reuse_detected|frozen/.test(action)) return 'danger';
  if (/failed|blocked|lockout|refused|throttled|conflict|not_issued|unknown/.test(action)) {
    return 'warning';
  }
  return 'neutral';
}
