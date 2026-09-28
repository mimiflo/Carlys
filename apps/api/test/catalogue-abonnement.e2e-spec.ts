process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';

import { BillingPeriod, PaymentProvider, PrismaClient } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { syncSubscriptionCatalog } from '../src/modules/subscriptions/application/subscription-catalog-sync';

describe('Catalogue d’abonnement (e2e)', () => {
  const prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
  const ancien = `price_e2e_ancien_${randomUUID()}`;
  const nouveau = `price_e2e_nouveau_${randomUUID()}`;
  const stripeMensuel = (externalProductId: string) => ({
    provider: PaymentProvider.STRIPE,
    externalProductId,
    billingPeriod: BillingPeriod.MONTHLY,
  });

  afterAll(async () => {
    await prisma.subscriptionProduct.deleteMany({
      where: { externalProductId: { in: [ancien, nouveau] } },
    });
    await prisma.$disconnect();
  });

  it('un tarif Stripe remplacé reste lié : ses abonnés renouvellent dessus', async () => {
    await syncSubscriptionCatalog(prisma, [stripeMensuel(ancien)]);
    await syncSubscriptionCatalog(prisma, [stripeMensuel(nouveau)]);

    const lies = await prisma.subscriptionProduct.findMany({
      where: { externalProductId: { in: [ancien, nouveau] } },
      select: { externalProductId: true },
    });
    expect(lies.map((produit) => produit.externalProductId).sort()).toEqual(
      [ancien, nouveau].sort(),
    );
  });
});
