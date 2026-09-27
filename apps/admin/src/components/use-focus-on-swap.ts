import { useCallback, useEffect, useRef, useState } from 'react';

/** Une demande de focus : son numéro, et l'état qu'elle attend (s'il y en a un). */
interface Demand {
  readonly serial: number;
  readonly until: string | undefined;
}

const NO_DEMAND: Demand = { serial: 0, until: undefined };

/**
 * Garde le focus clavier à l'endroit du geste quand ce geste REMPLACE le
 * bouton qu'on vient d'activer.
 *
 * « Supprimer » qui devient « Confirmer / Annuler », « modifier » qui ouvre un
 * éditeur, « Annuler » qui le referme : à chaque fois, le bouton activé est
 * démonté. Le focus retombait alors sur `<body>` : plus aucun contour visible,
 * rien d'annoncé au lecteur d'écran, et la personne au clavier devait
 * retrouver sa place dans une table de cinquante lignes.
 *
 * Le composant pose `target` (une ref de rappel, donc valable sur n'importe
 * quel élément) sur le contrôle qui doit recevoir le focus dans CHAQUE état,
 * un seul étant monté à la fois, et appelle `request()` dans le geste, dans
 * le même lot que le changement d'état. Le contrôle monté au rendu qui suit
 * reçoit le focus. Sans demande, rien ne bouge : l'arrivée d'une réponse ou un
 * rafraîchissement de la liste ne volent jamais le focus.
 *
 * Quand le contrôle à focaliser n'apparaît qu'avec une DONNÉE rafraîchie
 * (« Restaurer » ne paraît qu'une fois la liste rechargée), la demande nomme
 * l'état qu'elle attend, `request('deleted')`, et le composant passe son état
 * courant, `useFocusOnSwap(état)` : la demande patiente jusqu'à ce que les
 * deux coïncident. Demander le focus « après `invalidateQueries` » ne
 * suffisait pas : React Query livre la nouvelle liste aux composants dans un
 * `setTimeout(0)`, donc souvent APRÈS la fin de la promesse. Selon l'ordre des
 * tâches, le focus allait à l'ancien bouton, démonté un instant plus tard, et
 * retombait sur `<body>`.
 *
 * La demande est un ÉTAT, pas un drapeau dans une ref : elle provoque donc à
 * coup sûr le rendu qui la sert, même quand le geste ne change rien d'autre
 * (une restauration dont la liste a déjà été rafraîchie). Elle se sert UNE
 * fois, et seulement si le focus est perdu (sur `<body>`) : une demande restée
 * en attente, parce que la liste tardait, ne l'arrache jamais à la personne
 * qui l'a entre-temps posé ailleurs.
 */
export function useFocusOnSwap(state?: string) {
  const node = useRef<HTMLElement | null>(null);
  const [demand, setDemand] = useState<Demand>(NO_DEMAND);
  const served = useRef(NO_DEMAND.serial);

  useEffect(() => {
    const ready = demand.until === undefined || demand.until === state;
    if (demand.serial === served.current || !ready) {
      return;
    }
    served.current = demand.serial;
    const active = document.activeElement;
    if (active === null || active === document.body) {
      node.current?.focus();
    }
  }, [demand, state]);

  const target = useCallback((element: HTMLElement | null) => {
    node.current = element;
  }, []);

  const request = useCallback((until?: string) => {
    setDemand((previous) => ({ serial: previous.serial + 1, until }));
  }, []);

  return { target, request };
}
