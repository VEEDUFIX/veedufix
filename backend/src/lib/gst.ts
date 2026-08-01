import { Prisma } from "@prisma/client";

export function asDecimal(value: Prisma.Decimal | number | string): Prisma.Decimal {
  return value instanceof Prisma.Decimal ? value : new Prisma.Decimal(value);
}

export function roundMoney(value: Prisma.Decimal | number | string): Prisma.Decimal {
  return asDecimal(value).toDecimalPlaces(2);
}

export function toPaise(amount: Prisma.Decimal | number | string): number {
  return asDecimal(amount).mul(100).toDecimalPlaces(0).toNumber();
}

export function reverseInclusiveTax(
  totalAmount: Prisma.Decimal | number | string,
  gstRate: Prisma.Decimal | number | string
): {
  baseAmount: Prisma.Decimal;
  gstAmount: Prisma.Decimal;
} {
  const gross = roundMoney(totalAmount);
  const rate = asDecimal(gstRate);

  if (rate.lte(0)) {
    return {
      baseAmount: gross,
      gstAmount: new Prisma.Decimal(0)
    };
  }

  const divisor = new Prisma.Decimal(1).add(rate.div(100));
  const baseAmount = roundMoney(gross.div(divisor));
  const gstAmount = roundMoney(gross.sub(baseAmount));

  return {
    baseAmount,
    gstAmount
  };
}

export function allocateProportionalShares(
  total: Prisma.Decimal | number | string,
  weights: Array<Prisma.Decimal | number | string>
): Prisma.Decimal[] {
  const roundedTotal = roundMoney(total);
  if (weights.length === 0) {
    return [];
  }

  const weightDecimals = weights.map((weight) => asDecimal(weight));
  const totalWeight = weightDecimals.reduce((sum, weight) => sum.add(weight), new Prisma.Decimal(0));

  if (totalWeight.lte(0)) {
    return weightDecimals.map(() => new Prisma.Decimal(0));
  }

  const shares: Prisma.Decimal[] = [];
  let allocated = new Prisma.Decimal(0);

  weightDecimals.forEach((weight, index) => {
    if (index === weightDecimals.length - 1) {
      shares.push(roundMoney(roundedTotal.sub(allocated)));
      return;
    }

    const share = roundMoney(roundedTotal.mul(weight).div(totalWeight));
    shares.push(share);
    allocated = allocated.add(share);
  });

  return shares;
}
