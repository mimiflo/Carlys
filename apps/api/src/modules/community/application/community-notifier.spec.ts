import { PUSH_DESTINATIONS, pushDataSchema } from '@carlys/api-contracts';
import { type PinoLogger } from 'nestjs-pino';
import { type NotificationsService } from '../../notifications/application/notifications.service';
import { type PushMessage } from '../../notifications/domain/push-sender.port';
import { type CommunityRepository } from '../infrastructure/community.repository';
import { CommunityNotifier } from './community-notifier';

/**
 * CE QUE CE FICHIER PROTÈGE : chaque notification de la communauté dit OÙ
 * mène son toucher.
 *
 * Sans le champ `data`, toucher une demande d'ami ou une invitation ouvrait
 * l'application, jamais l'écran concerné. Le contrat (`PushData`, clé
 * `destination`) est lu par le mobile, écrit en parallèle : chaque message
 * est donc confronté au schéma publié, pas seulement à une valeur recopiée.
 */

const INVITEE = 'utilisateur-invitee';
const CHLOE = 'utilisateur-chloe';
const DEFI = '4b0f3f5e-8a8f-4a8c-9a57-2f4c1d3e5b6a';

function build() {
  const notifications = { pushEnabled: true, sendToUser: jest.fn().mockResolvedValue(undefined) };
  const community = { displayNameOf: jest.fn().mockResolvedValue('Chloé') };
  const notifier = new CommunityNotifier(
    community as unknown as CommunityRepository,
    notifications as unknown as NotificationsService,
    { error: jest.fn() } as unknown as PinoLogger,
  );
  /** Le message remis à l'envoi, tel quel. */
  const sent = (): PushMessage => {
    const call = notifications.sendToUser.mock.calls[0] as [string, PushMessage, string];
    return call[1];
  };
  return { notifier, notifications, sent };
}

describe('CommunityNotifier — la destination du toucher', () => {
  it.each([
    ['une demande d’ami reçue', (n: CommunityNotifier) => n.newRequest(CHLOE, INVITEE)],
    ['une demande acceptée', (n: CommunityNotifier) => n.requestAccepted(CHLOE, INVITEE)],
    ['un encouragement', (n: CommunityNotifier) => n.encouragement(INVITEE, CHLOE, 'Bravo !')],
  ])('%s mène à l’onglet Amis', async (_cas, envoyer) => {
    const { notifier, sent } = build();

    await envoyer(notifier);

    expect(sent().data).toEqual({ destination: 'community-friends' });
    expect(pushDataSchema.safeParse(sent().data).success).toBe(true);
  });

  it('une invitation à un défi mène à CE défi, par son identifiant', async () => {
    const { notifier, notifications, sent } = build();

    await notifier.challengeInvite(INVITEE, CHLOE, DEFI, 'Qui court le plus');

    expect(notifications.sendToUser).toHaveBeenCalledWith(
      INVITEE,
      {
        title: 'Nouveau défi',
        body: 'Chloé te défie : Qui court le plus',
        data: { destination: 'friend-challenge', challengeId: DEFI },
      },
      'CHALLENGE_INVITES',
    );
    expect(pushDataSchema.safeParse(sent().data).success).toBe(true);
  });

  it('le contrat publié couvre exactement les destinations annoncées', () => {
    // Deux listes à garder d'accord : les valeurs exportées pour le mobile,
    // et les formes du schéma. Une destination sans forme (ou l'inverse)
    // serait un toucher que personne ne sait router.
    const formes = pushDataSchema.options.map((option) => option.shape.destination.value);
    expect([...formes].sort()).toEqual([...PUSH_DESTINATIONS].sort());
  });
});
