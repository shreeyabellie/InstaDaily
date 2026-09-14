import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

interface NotifyFlatmatesPayload {
  cart_id: string;
  actor_user_id: string;
  actor_display_name: string;
  item_name: string;
  item_quantity: number;
  item_price_paise: number;
  action: "added" | "removed" | "updated_quantity";
}

interface CartParticipantRow {
  user_id: string;
  cart_id: string;
  role: string;
  users: {
    id: string;
    display_name: string;
    push_token: string | null;
    notification_preferences: {
      shared_cart_updates: boolean;
    } | null;
  } | null;
}

interface PushNotificationPayload {
  to: string;
  title: string;
  body: string;
  data: {
    type: "SHARED_CART_UPDATE";
    cart_id: string;
    actor_user_id: string;
    item_name: string;
    action: string;
  };
  sound: "default";
  priority: "high";
}

interface EdgeFunctionErrorResponse {
  error: string;
  details?: string;
}

interface EdgeFunctionSuccessResponse {
  success: true;
  notified_count: number;
  skipped_count: number;
  cart_id: string;
}

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const JSON_HEADERS: Record<string, string> = {
  ...CORS_HEADERS,
  "Content-Type": "application/json",
};

function formatIndianRupees(paise: number): string {
  const rupees = paise / 100;
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 0,
  }).format(rupees);
}

function isValidPayload(payload: unknown): payload is NotifyFlatmatesPayload {
  if (typeof payload !== "object" || payload === null) {
    return false;
  }

  const candidate = payload as Record<string, unknown>;

  if (typeof candidate.cart_id !== "string" || candidate.cart_id.trim() === "") {
    return false;
  }
  if (
    typeof candidate.actor_user_id !== "string" ||
    candidate.actor_user_id.trim() === ""
  ) {
    return false;
  }
  if (
    typeof candidate.actor_display_name !== "string" ||
    candidate.actor_display_name.trim() === ""
  ) {
    return false;
  }
  if (typeof candidate.item_name !== "string" || candidate.item_name.trim() === "") {
    return false;
  }
  if (
    typeof candidate.item_quantity !== "number" ||
    !Number.isFinite(candidate.item_quantity) ||
    candidate.item_quantity <= 0
  ) {
    return false;
  }
  if (
    typeof candidate.item_price_paise !== "number" ||
    !Number.isFinite(candidate.item_price_paise) ||
    candidate.item_price_paise < 0
  ) {
    return false;
  }
  if (
    candidate.action !== "added" &&
    candidate.action !== "removed" &&
    candidate.action !== "updated_quantity"
  ) {
    return false;
  }

  return true;
}

function buildNotificationCopy(
  payload: NotifyFlatmatesPayload,
): { title: string; body: string } {
  const formattedPrice = formatIndianRupees(payload.item_price_paise);
  const title = "Shared Cart Update";

  if (payload.action === "added") {
    const quantityLabel = payload.item_quantity > 1 ? ` x${payload.item_quantity}` : "";
    return {
      title,
      body: `${payload.actor_display_name} added ${payload.item_name}${quantityLabel} (${formattedPrice}) to the shared cart`,
    };
  }

  if (payload.action === "removed") {
    return {
      title,
      body: `${payload.actor_display_name} removed ${payload.item_name} from the shared cart`,
    };
  }

  return {
    title,
    body: `${payload.actor_display_name} updated ${payload.item_name} to x${payload.item_quantity} in the shared cart`,
  };
}

async function dispatchPushNotification(
  pushToken: string,
  notification: PushNotificationPayload,
): Promise<boolean> {
  try {
    const response = await fetch("https://exp.host/--/api/v2/push/send", {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(notification),
    });

    console.log(
      `[notify-flatmates] Dispatched push to token=${pushToken} status=${response.status} payload=${JSON.stringify(
        notification,
      )}`,
    );

    return response.ok;
  } catch (dispatchError) {
    console.error(
      `[notify-flatmates] Failed to dispatch push to token=${pushToken}`,
      dispatchError,
    );
    return false;
  }
}

async function verifyRequestingUser(
  supabaseAdmin: SupabaseClient,
  authorizationHeader: string,
): Promise<{ userId: string } | null> {
  const jwt = authorizationHeader.replace("Bearer ", "").trim();

  if (jwt.length === 0) {
    return null;
  }

  const { data, error } = await supabaseAdmin.auth.getUser(jwt);

  if (error || !data.user) {
    return null;
  }

  return { userId: data.user.id };
}

async function verifyCartMembership(
  supabaseAdmin: SupabaseClient,
  cartId: string,
  userId: string,
): Promise<boolean> {
  const { data, error } = await supabaseAdmin
    .from("cart_participants")
    .select("user_id")
    .eq("cart_id", cartId)
    .eq("user_id", userId)
    .maybeSingle();

  if (error) {
    console.error("[notify-flatmates] Error verifying cart membership", error);
    return false;
  }

  return data !== null;
}

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    const errorBody: EdgeFunctionErrorResponse = {
      error: "Method not allowed. This endpoint only accepts POST requests.",
    };
    return new Response(JSON.stringify(errorBody), {
      status: 405,
      headers: JSON_HEADERS,
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !supabaseServiceRoleKey) {
    console.error(
      "[notify-flatmates] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variables",
    );
    const errorBody: EdgeFunctionErrorResponse = {
      error: "Server misconfiguration. Please contact support.",
    };
    return new Response(JSON.stringify(errorBody), {
      status: 500,
      headers: JSON_HEADERS,
    });
  }

  const supabaseAdmin: SupabaseClient = createClient(
    supabaseUrl,
    supabaseServiceRoleKey,
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    },
  );

  try {
    const authorizationHeader = req.headers.get("Authorization");

    if (!authorizationHeader || authorizationHeader.trim() === "") {
      const errorBody: EdgeFunctionErrorResponse = {
        error: "Missing Authorization header.",
      };
      return new Response(JSON.stringify(errorBody), {
        status: 401,
        headers: JSON_HEADERS,
      });
    }

    const verifiedUser = await verifyRequestingUser(
      supabaseAdmin,
      authorizationHeader,
    );

    if (!verifiedUser) {
      const errorBody: EdgeFunctionErrorResponse = {
        error: "Invalid or expired authorization token.",
      };
      return new Response(JSON.stringify(errorBody), {
        status: 401,
        headers: JSON_HEADERS,
      });
    }

    let rawBody: string;
    try {
      rawBody = await req.text();
    } catch (readError) {
      console.error("[notify-flatmates] Failed to read request body", readError);
      const errorBody: EdgeFunctionErrorResponse = {
        error: "Unable to read request body.",
      };
      return new Response(JSON.stringify(errorBody), {
        status: 400,
        headers: JSON_HEADERS,
      });
    }

    if (!rawBody || rawBody.trim() === "") {
      const errorBody: EdgeFunctionErrorResponse = {
        error: "Request body is empty.",
      };
      return new Response(JSON.stringify(errorBody), {
        status: 400,
        headers: JSON_HEADERS,
      });
    }

    let parsedPayload: unknown;
    try {
      parsedPayload = JSON.parse(rawBody);
    } catch (parseError) {
      console.error("[notify-flatmates] Malformed JSON payload", parseError);
      const errorBody: EdgeFunctionErrorResponse = {
        error: "Malformed JSON payload.",
      };
      return new Response(JSON.stringify(errorBody), {
        status: 400,
        headers: JSON_HEADERS,
      });
    }

    if (!isValidPayload(parsedPayload)) {
      const errorBody: EdgeFunctionErrorResponse = {
        error:
          "Invalid payload shape. Expected cart_id, actor_user_id, actor_display_name, item_name, item_quantity, item_price_paise, and action.",
      };
      return new Response(JSON.stringify(errorBody), {
        status: 400,
        headers: JSON_HEADERS,
      });
    }

    const payload = parsedPayload;

    if (payload.actor_user_id !== verifiedUser.userId) {
      const errorBody: EdgeFunctionErrorResponse = {
        error: "actor_user_id does not match the authenticated user.",
      };
      return new Response(JSON.stringify(errorBody), {
        status: 401,
        headers: JSON_HEADERS,
      });
    }

    const isMember = await verifyCartMembership(
      supabaseAdmin,
      payload.cart_id,
      verifiedUser.userId,
    );

    if (!isMember) {
      const errorBody: EdgeFunctionErrorResponse = {
        error: "You are not a participant of this shared cart.",
      };
      return new Response(JSON.stringify(errorBody), {
        status: 401,
        headers: JSON_HEADERS,
      });
    }

    const { data: participantRows, error: participantsError } =
      await supabaseAdmin
        .from("cart_participants")
        .select(
          `
          user_id,
          cart_id,
          role,
          users:user_id (
            id,
            display_name,
            push_token,
            notification_preferences
          )
        `,
        )
        .eq("cart_id", payload.cart_id)
        .neq("user_id", payload.actor_user_id)
        .returns<CartParticipantRow[]>();

    if (participantsError) {
      console.error(
        "[notify-flatmates] Error querying cart_participants",
        participantsError,
      );
      const errorBody: EdgeFunctionErrorResponse = {
        error: "Failed to query cart participants.",
        details: participantsError.message,
      };
      return new Response(JSON.stringify(errorBody), {
        status: 500,
        headers: JSON_HEADERS,
      });
    }

    if (!participantRows || participantRows.length === 0) {
      const successBody: EdgeFunctionSuccessResponse = {
        success: true,
        notified_count: 0,
        skipped_count: 0,
        cart_id: payload.cart_id,
      };
      return new Response(JSON.stringify(successBody), {
        status: 200,
        headers: JSON_HEADERS,
      });
    }

    const notificationCopy = buildNotificationCopy(payload);

    let notifiedCount = 0;
    let skippedCount = 0;

    const dispatchResults = await Promise.all(
      participantRows.map(async (participant) => {
        const flatmate = participant.users;

        if (!flatmate) {
          return false;
        }

        const wantsUpdates =
          flatmate.notification_preferences?.shared_cart_updates ?? true;

        if (!wantsUpdates) {
          return false;
        }

        if (!flatmate.push_token || flatmate.push_token.trim() === "") {
          return false;
        }

        const notification: PushNotificationPayload = {
          to: flatmate.push_token,
          title: notificationCopy.title,
          body: notificationCopy.body,
          data: {
            type: "SHARED_CART_UPDATE",
            cart_id: payload.cart_id,
            actor_user_id: payload.actor_user_id,
            item_name: payload.item_name,
            action: payload.action,
          },
          sound: "default",
          priority: "high",
        };

        return await dispatchPushNotification(flatmate.push_token, notification);
      }),
    );

    for (const wasDispatched of dispatchResults) {
      if (wasDispatched) {
        notifiedCount += 1;
      } else {
        skippedCount += 1;
      }
    }

    const successBody: EdgeFunctionSuccessResponse = {
      success: true,
      notified_count: notifiedCount,
      skipped_count: skippedCount,
      cart_id: payload.cart_id,
    };

    return new Response(JSON.stringify(successBody), {
      status: 200,
      headers: JSON_HEADERS,
    });
  } catch (unexpectedError) {
    console.error("[notify-flatmates] Unhandled exception", unexpectedError);
    const errorBody: EdgeFunctionErrorResponse = {
      error: "Internal server error.",
      details:
        unexpectedError instanceof Error
          ? unexpectedError.message
          : "Unknown error",
    };
    return new Response(JSON.stringify(errorBody), {
      status: 500,
      headers: JSON_HEADERS,
    });
  }
});