"use server";

const POST_ORDER_EDIT_WINDOW_MS = 2 * 60 * 1000;

export interface PostOrderEditWindow {
  orderId: string;
  createdAt: string;
  expiresAt: string;
  remainingMs: number;
  canEdit: boolean;
}

export interface GetPostOrderEditWindowResult {
  success: boolean;
  data: PostOrderEditWindow | null;
  error: string | null;
}

export interface IsOrderEditableResult {
  success: boolean;
  canEdit: boolean;
  remainingMs: number;
  error: string | null;
}

/**
 * Calculates the server-side post-order editing window.
 *
 * The caller must provide the order's `created_at` timestamp obtained
 * from the database. The current time is generated on the server so
 * the decision does not depend on the client's system clock.
 */
export async function getPostOrderEditWindow(
  orderId: string,
  createdAt: string,
): Promise<GetPostOrderEditWindowResult> {
  const trimmedOrderId = orderId.trim();

  if (!trimmedOrderId) {
    return {
      success: false,
      data: null,
      error: "Order ID is required.",
    };
  }

  const createdTimestamp = Date.parse(createdAt);

  if (!Number.isFinite(createdTimestamp)) {
    return {
      success: false,
      data: null,
      error: "The order creation timestamp is invalid.",
    };
  }

  const now = Date.now();
  const expiresAtTimestamp =
    createdTimestamp + POST_ORDER_EDIT_WINDOW_MS;

  const remainingMs = Math.max(0, expiresAtTimestamp - now);

  return {
    success: true,
    data: {
      orderId: trimmedOrderId,
      createdAt: new Date(createdTimestamp).toISOString(),
      expiresAt: new Date(expiresAtTimestamp).toISOString(),
      remainingMs,
      canEdit: remainingMs > 0,
    },
    error: null,
  };
}

/**
 * Checks whether an order is still inside the two-minute editing window.
 */
export async function isOrderEditable(
  orderId: string,
  createdAt: string,
): Promise<IsOrderEditableResult> {
  const result = await getPostOrderEditWindow(orderId, createdAt);

  if (!result.success || result.data === null) {
    return {
      success: false,
      canEdit: false,
      remainingMs: 0,
      error: result.error ?? "Unable to determine edit status.",
    };
  }

  return {
    success: true,
    canEdit: result.data.canEdit,
    remainingMs: result.data.remainingMs,
    error: null,
  };
}
