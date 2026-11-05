import { BODY_METRIC_BOUNDS } from '@carlys/api-contracts';
import { BODY_METRIC_VALUE_DESCRIPTION } from './progress.dto';

/**
 * La description Swagger de `value` dit les bornes que le service applique :
 * construite depuis `BODY_METRIC_BOUNDS`, elle ne peut pas en diverger.
 * Recopiée à la main, elle l'aurait fait au premier réglage d'une borne.
 */
describe('BODY_METRIC_VALUE_DESCRIPTION', () => {
  it.each(Object.entries(BODY_METRIC_BOUNDS))('annonce les bornes de %s', (type, bounds) => {
    expect(BODY_METRIC_VALUE_DESCRIPTION).toContain(
      `${type} ${bounds.min}–${bounds.max} (${bounds.decimals} déc.)`,
    );
  });
});
