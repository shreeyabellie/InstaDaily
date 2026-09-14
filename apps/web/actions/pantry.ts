export type PantryItem = {
  name: string;
  quantity: number;
  purchaseFrequency: number;
};

export type StockStatus = "LOW STOCK" | "OK";

export function getStockStatus(item: PantryItem): StockStatus {
  // Purchase frequency represents the usual quantity bought.
  const threshold = Math.max(1, Math.ceil(item.purchaseFrequency * 0.25));

  return item.quantity <= threshold ? "LOW STOCK" : "OK";
}

export function getLowStockItems(items: PantryItem[]): PantryItem[] {
  return items.filter((item) => getStockStatus(item) === "LOW STOCK");
}
"use server";

const MIN_PURCHASES_FOR_PATTERN = 2;
const LOW_STOCK_THRESHOLD_DAYS = 2;
const MAX_PURCHASE_HISTORY = 50;

export interface PantryPurchase {
  productId: string;
  purchasedAt: string;
  quantity: number;
}

export interface PantryStockStatus {
  productId: string;
  averagePurchaseIntervalDays: number | null;
  daysSinceLastPurchase: number | null;
  isLowStock: boolean;
  confidence: "low" | "medium" | "high";
}

export interface GetPantryStatusResult {
  success: boolean;
  data: PantryStockStatus | null;
  error: string | null;
}

function isValidPurchase(purchase: PantryPurchase): boolean {
  if (!purchase.productId.trim()) {
    return false;
  }

  if (!Number.isFinite(purchase.quantity) || purchase.quantity <= 0) {
    return false;
  }

  return Number.isFinite(Date.parse(purchase.purchasedAt));
}

function calculateAverageIntervalDays(
  purchases: PantryPurchase[],
): number | null {
  if (purchases.length < MIN_PURCHASES_FOR_PATTERN) {
    return null;
  }

  const timestamps = purchases
    .map((purchase) => Date.parse(purchase.purchasedAt))
    .sort((a, b) => a - b);

  const intervals: number[] = [];

  for (let index = 1; index < timestamps.length; index += 1) {
    const differenceMs = timestamps[index] - timestamps[index - 1];

    if (differenceMs > 0) {
      intervals.push(differenceMs / (1000 * 60 * 60 * 24));
    }
  }

  if (intervals.length === 0) {
    return null;
  }

  const total = intervals.reduce((sum, interval) => sum + interval, 0);

  return total / intervals.length;
}

function determineConfidence(purchaseCount: number): "low" | "medium" | "high" {
  if (purchaseCount >= 5) {
    return "high";
  }

  if (purchaseCount >= 3) {
    return "medium";
  }

  return "low";
}

export async function getPantryStatus(
  productId: string,
  purchases: PantryPurchase[],
  now = new Date(),
): Promise<GetPantryStatusResult> {
  const normalizedProductId = productId.trim();

  if (!normalizedProductId) {
    return {
      success: false,
      data: null,
      error: "Product ID is required.",
    };
  }

  if (Number.isNaN(now.getTime())) {
    return {
      success: false,
      data: null,
      error: "The current server timestamp is invalid.",
    };
  }

  const productPurchases = purchases
    .filter(
      (purchase) =>
        purchase.productId.trim() === normalizedProductId &&
        isValidPurchase(purchase),
    )
    .sort(
      (first, second) =>
        Date.parse(second.purchasedAt) - Date.parse(first.purchasedAt),
    )
    .slice(0, MAX_PURCHASE_HISTORY);

  if (productPurchases.length === 0) {
    return {
      success: true,
      data: {
        productId: normalizedProductId,
        averagePurchaseIntervalDays: null,
        daysSinceLastPurchase: null,
        isLowStock: false,
        confidence: "low",
      },
      error: null,
    };
  }

  const latestPurchaseTimestamp = Date.parse(
    productPurchases[0].purchasedAt,
  );

  const daysSinceLastPurchase = Math.max(
    0,
    (now.getTime() - latestPurchaseTimestamp) /
      (1000 * 60 * 60 * 24),
  );

  const averagePurchaseIntervalDays =
    calculateAverageIntervalDays(productPurchases);

  const isLowStock =
    averagePurchaseIntervalDays !== null &&
    daysSinceLastPurchase >=
      averagePurchaseIntervalDays - LOW_STOCK_THRESHOLD_DAYS;

  return {
    success: true,
    data: {
      productId: normalizedProductId,
      averagePurchaseIntervalDays,
      daysSinceLastPurchase,
      isLowStock,
      confidence: determineConfidence(productPurchases.length),
    },
    error: null,
  };
}

export async function getPantryStatuses(
  purchases: PantryPurchase[],
  productIds: string[],
  now = new Date(),
): Promise<GetPantryStatusResult[]> {
  const uniqueProductIds = Array.from(
    new Set(
      productIds
        .map((productId) => productId.trim())
        .filter((productId) => productId.length > 0),
    ),
  );

  return Promise.all(
    uniqueProductIds.map((productId) =>
      getPantryStatus(productId, purchases, now),
    ),
  );
}
