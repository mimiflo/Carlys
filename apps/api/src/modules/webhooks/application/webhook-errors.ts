/**
 * Un échec de traitement qu'il est INUTILE de rejouer.
 *
 * POURQUOI CETTE DISTINCTION DÉCIDE D'UN ENCAISSEMENT. La réponse au
 * fournisseur est la seule chose qui déclenche un réessai : Stripe et
 * RevenueCat réémettent un événement tant qu'ils n'ont pas reçu un 2xx, des
 * heures durant. Le service répondait 200 à TOUS les échecs, au motif que
 * « le fournisseur n'a pas à réémettre un événement bien reçu » — ce qui
 * confond REÇU et APPLIQUÉ. Le chemin de reprise existait pourtant déjà et
 * était sûr : un événement journalisé mais non traité EST retraité à la
 * re-livraison (`processedAt === null`). Personne ne l'empruntait, et rien
 * d'autre ne rejouait : aucune tâche planifiée, et `processingError` n'était
 * lu par aucun écran ni aucune alerte. Un paiement encaissé dont la
 * projection échouait laissait donc le compte gratuit, définitivement et en
 * silence.
 *
 * La règle est donc : ce qui peut guérir tout seul répond 5xx et sera rejoué ;
 * ce qui ne peut pas répond 200 et est journalisé.
 *
 * NE GUÉRIT PAS — 200, cette erreur :
 * - charge utile inexploitable (`metadata.userId` absent ou non-UUID, aucun
 *   `price`, `app_user_id` invalide, `product_id` absent). Le fournisseur
 *   réémettra le MÊME corps : le rejeu rendrait le même échec, indéfiniment.
 *
 * PEUT GUÉRIR — 5xx, toute autre erreur :
 * - produit inconnu du catalogue. C'est le cas dangereux, et il est courant :
 *   un tarif créé chez le fournisseur avant d'être chargé en base, ou un
 *   déploiement dont l'étape de catalogue a échoué. Le rejeu réussira dès que
 *   la base aura rattrapé — c'est exactement le membre qui a payé.
 * - base indisponible, contention, panne passagère.
 */
export class PermanentWebhookError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'PermanentWebhookError';
  }
}
