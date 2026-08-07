import { createHmac } from 'node:crypto';
import { verifyStripeSignature } from './stripe-signature.util';

const SECRET = 'whsec_test_0123456789abcdef';

function sign(payload: string, timestampSeconds: number, secret: string = SECRET): string {
  const signature = createHmac('sha256', secret)
    .update(`${timestampSeconds}.${payload}`)
    .digest('hex');
  return `t=${timestampSeconds},v1=${signature}`;
}

describe('verifyStripeSignature', () => {
  const payload = Buffer.from('{"id":"evt_1","type":"customer.subscription.created"}');
  const nowMs = 1_770_000_000_000;
  const nowSeconds = nowMs / 1_000;

  it('accepte une signature valide dans la fenêtre de tolérance', () => {
    const header = sign(payload.toString(), nowSeconds - 10);
    expect(verifyStripeSignature(payload, header, SECRET, 300, nowMs)).toBe(true);
  });

  it('refuse un corps modifié après signature', () => {
    const header = sign(payload.toString(), nowSeconds);
    const tampered = Buffer.from('{"id":"evt_1","type":"customer.subscription.deleted"}');
    expect(verifyStripeSignature(tampered, header, SECRET, 300, nowMs)).toBe(false);
  });

  it('refuse une signature produite avec un autre secret', () => {
    const header = sign(payload.toString(), nowSeconds, 'whsec_autre_secret_123456');
    expect(verifyStripeSignature(payload, header, SECRET, 300, nowMs)).toBe(false);
  });

  it('refuse un horodatage hors tolérance (anti-rejeu)', () => {
    const header = sign(payload.toString(), nowSeconds - 3_600);
    expect(verifyStripeSignature(payload, header, SECRET, 300, nowMs)).toBe(false);
  });

  it('refuse un en-tête absent ou malformé', () => {
    expect(verifyStripeSignature(payload, undefined, SECRET, 300, nowMs)).toBe(false);
    expect(verifyStripeSignature(payload, 'v1=abc', SECRET, 300, nowMs)).toBe(false);
    expect(verifyStripeSignature(payload, 't=abc,v1=', SECRET, 300, nowMs)).toBe(false);
  });
});
