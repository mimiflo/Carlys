import { createHmac, timingSafeEqual } from 'node:crypto';

const DEFAULT_TOLERANCE_SECONDS = 300;

/**
 * Vérifie l'en-tête `Stripe-Signature` (`t=<epoch>,v1=<hmac>`) : HMAC-SHA256
 * de `<t>.<corps brut>` avec le secret du webhook, comparaison à temps
 * constant, et fenêtre de tolérance contre le rejeu d'anciens événements.
 */
export function verifyStripeSignature(
  payload: Buffer,
  header: string | undefined,
  secret: string,
  toleranceSeconds: number = DEFAULT_TOLERANCE_SECONDS,
  nowMs: number = Date.now(),
): boolean {
  if (header === undefined || header.length === 0) {
    return false;
  }

  let timestamp: string | undefined;
  const signatures: string[] = [];
  for (const part of header.split(',')) {
    const separator = part.indexOf('=');
    if (separator === -1) {
      continue;
    }
    const key = part.slice(0, separator).trim();
    const value = part.slice(separator + 1).trim();
    if (key === 't') {
      timestamp = value;
    } else if (key === 'v1' && value.length > 0) {
      signatures.push(value);
    }
  }

  if (timestamp === undefined || signatures.length === 0) {
    return false;
  }
  const timestampSeconds = Number(timestamp);
  if (!Number.isFinite(timestampSeconds)) {
    return false;
  }
  if (Math.abs(nowMs / 1_000 - timestampSeconds) > toleranceSeconds) {
    return false;
  }

  const expected = Buffer.from(
    createHmac('sha256', secret).update(`${timestamp}.`).update(payload).digest('hex'),
  );
  return signatures.some((signature) => {
    const candidate = Buffer.from(signature);
    return candidate.length === expected.length && timingSafeEqual(candidate, expected);
  });
}
