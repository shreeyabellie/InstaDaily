/**
 * apps/web/lib/errors/errorHandler.ts
 *
 * Converts raw errors — failed `fetch` calls, non-2xx API responses,
 * payment-gateway failures, and expired/invalid OTPs — into a single
 * shape the UI can render without each call site re-implementing its
 * own error copy.
 */

export type ErrorCategory =
  | 'network'
  | 'auth'
  | 'otp'
  | 'payment'
  | 'validation'
  | 'server'
  | 'unknown';

/**
 * How urgently the UI should draw attention to this error.
 *  - "info": user-initiated or expected (e.g. cancelled payment) — a quiet toast, no icon emphasis.
 *  - "warning": recoverable by the user retrying or correcting input — standard toast/inline banner.
 *  - "error": the action failed and needs explicit acknowledgement — persistent banner.
 *  - "critical": the outcome is ambiguous or high-stakes (e.g. a payment gateway timeout where the
 *    charge may or may not have gone through) — should block further action and suggest contacting support.
 */
export type ErrorSeverity = 'info' | 'warning' | 'error' | 'critical';

export interface ParsedAppError {
  /** High-level bucket, useful for routing to a toast vs. inline field error. */
  category: ErrorCategory;
  /** Stable machine-readable code, e.g. "OTP_EXPIRED" or "HTTP_429". */
  code: string;
  /** Short, human-readable message safe to show directly in the UI. */
  message: string;
  /** How urgently the UI should draw attention to this error. */
  severity: ErrorSeverity;
  /** Whether retrying the same action is likely to succeed. */
  retryable: boolean;
  /**
   * When `retryable` is true and the wait is known (e.g. a rate limit or an
   * OTP resend cooldown), the number of seconds the UI should ask the user
   * to wait before offering a "Retry" action again. `undefined` when
   * retryable immediately or when no specific wait is known.
   */
  retryAfterSeconds?: number;
  /** The original error/value, kept for logging — never render this directly. */
  cause: unknown;
}

/** Shape of an HTTP-style error many API clients throw (status + optional body). */
interface HttpLikeError {
  status?: number;
  statusCode?: number;
  /** Seconds the client should wait before retrying, mirroring an HTTP `Retry-After` header. */
  retryAfter?: number;
  response?: {
    status?: number;
    data?: { code?: string; message?: string };
    headers?: { 'retry-after'?: string | number };
  };
}

/** Shape of the OTP-specific errors the auth flow can raise. */
interface OtpLikeError {
  code: 'OTP_EXPIRED' | 'OTP_INVALID' | 'OTP_MAX_ATTEMPTS' | 'OTP_RATE_LIMITED';
}

/** Shape of payment-gateway errors (modelled on common Razorpay/Stripe-style payloads). */
interface PaymentLikeError {
  code:
    | 'PAYMENT_FAILED'
    | 'PAYMENT_DECLINED'
    | 'PAYMENT_CANCELLED'
    | 'INSUFFICIENT_FUNDS'
    | 'CARD_EXPIRED'
    | 'GATEWAY_TIMEOUT';
  description?: string;
}

const OTP_MESSAGES: Record<OtpLikeError['code'], string> = {
  OTP_EXPIRED: 'That OTP has expired. Request a new one to continue.',
  OTP_INVALID: 'That OTP doesn’t look right. Please check and try again.',
  OTP_MAX_ATTEMPTS: 'Too many incorrect attempts. Please wait a moment before trying again.',
  OTP_RATE_LIMITED: 'You’ve requested too many OTPs. Please wait before requesting another.',
};

/** Default wait, in seconds, before the UI should re-offer the action — mirrors the OTP form's own cooldown/lockout timers. */
const OTP_DEFAULT_RETRY_AFTER_SECONDS: Partial<Record<OtpLikeError['code'], number>> = {
  OTP_MAX_ATTEMPTS: 60,
  OTP_RATE_LIMITED: 30,
};

const OTP_SEVERITIES: Record<OtpLikeError['code'], ErrorSeverity> = {
  OTP_EXPIRED: 'warning',
  OTP_INVALID: 'warning',
  OTP_MAX_ATTEMPTS: 'error',
  OTP_RATE_LIMITED: 'warning',
};

const PAYMENT_MESSAGES: Record<PaymentLikeError['code'], string> = {
  PAYMENT_FAILED: 'Your payment couldn’t be completed. Please try again.',
  PAYMENT_DECLINED: 'Your bank declined this payment. Try another card or payment method.',
  PAYMENT_CANCELLED: 'Payment was cancelled before it could complete.',
  INSUFFICIENT_FUNDS: 'This payment method has insufficient funds.',
  CARD_EXPIRED: 'This card has expired. Please use a different payment method.',
  GATEWAY_TIMEOUT:
    'We couldn’t confirm your payment in time. If any amount was deducted, it will be refunded within 5-7 business days. Please check your order status before trying again.',
};

/** Gateway timeouts leave the charge in an unknown state — never "retryable" in the simple sense; everything else is a clean failure the user can immediately retry or fix. */
const PAYMENT_SEVERITIES: Record<PaymentLikeError['code'], ErrorSeverity> = {
  PAYMENT_FAILED: 'error',
  PAYMENT_DECLINED: 'error',
  PAYMENT_CANCELLED: 'info',
  INSUFFICIENT_FUNDS: 'error',
  CARD_EXPIRED: 'error',
  GATEWAY_TIMEOUT: 'critical',
};

interface HttpStatusMapping {
  message: string;
  retryable: boolean;
  category: ErrorCategory;
  severity: ErrorSeverity;
  retryAfterSeconds?: number;
}

const HTTP_STATUS_MESSAGES: Record<number, HttpStatusMapping> = {
  400: { message: 'That request wasn’t valid. Please check your details and try again.', retryable: false, category: 'validation', severity: 'warning' },
  401: { message: 'Your session has expired. Please log in again.', retryable: false, category: 'auth', severity: 'warning' },
  403: { message: 'You don’t have permission to do that.', retryable: false, category: 'auth', severity: 'error' },
  404: { message: 'We couldn’t find what you were looking for.', retryable: false, category: 'server', severity: 'error' },
  408: { message: 'That took too long to respond. Please try again.', retryable: true, category: 'network', severity: 'warning' },
  409: { message: 'That change conflicts with something else. Please refresh and try again.', retryable: false, category: 'validation', severity: 'warning' },
  422: { message: 'Some of the details you entered aren’t valid.', retryable: false, category: 'validation', severity: 'warning' },
  429: { message: 'You’re doing that a little too fast. Please wait a moment and try again.', retryable: true, category: 'server', severity: 'warning', retryAfterSeconds: 30 },
  500: { message: 'Something went wrong on our end. Please try again.', retryable: true, category: 'server', severity: 'error' },
  502: { message: 'Our servers are having trouble right now. Please try again shortly.', retryable: true, category: 'server', severity: 'error' },
  503: { message: 'InstaDaily is temporarily unavailable. Please try again shortly.', retryable: true, category: 'server', severity: 'error' },
  504: { message: 'Our servers are having trouble right now. Please try again shortly.', retryable: true, category: 'server', severity: 'error' },
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function isOtpLikeError(value: unknown): value is OtpLikeError {
  return isRecord(value) && typeof value.code === 'string' && value.code in OTP_MESSAGES;
}

function isPaymentLikeError(value: unknown): value is PaymentLikeError {
  return isRecord(value) && typeof value.code === 'string' && value.code in PAYMENT_MESSAGES;
}

function extractHttpStatus(value: unknown): number | undefined {
  if (!isRecord(value)) {
    return undefined;
  }

  const candidate = value as HttpLikeError;
  return candidate.status ?? candidate.statusCode ?? candidate.response?.status;
}

/**
 * Reads an explicit retry wait off an HTTP-like error — either a numeric
 * `retryAfter` field or a `Retry-After` response header (seconds, per RFC
 * 9110; HTTP-date values aren't supported here and are ignored).
 */
function extractRetryAfterSeconds(value: unknown): number | undefined {
  if (!isRecord(value)) {
    return undefined;
  }

  const candidate = value as HttpLikeError;

  if (typeof candidate.retryAfter === 'number' && Number.isFinite(candidate.retryAfter) && candidate.retryAfter >= 0) {
    return candidate.retryAfter;
  }

  const header = candidate.response?.headers?.['retry-after'];
  const parsedHeader = typeof header === 'number' ? header : typeof header === 'string' ? Number.parseInt(header, 10) : NaN;

  return Number.isFinite(parsedHeader) && parsedHeader >= 0 ? parsedHeader : undefined;
}

function isNetworkError(error: unknown): boolean {
  if (typeof navigator !== 'undefined' && navigator.onLine === false) {
    return true;
  }

  if (error instanceof TypeError) {
    // Both browser `fetch` ("Failed to fetch") and Node's undici
    // ("fetch failed") throw a bare TypeError when the network is down
    // or the host can't be reached.
    return /failed to fetch|fetch failed|network/i.test(error.message);
  }

  return false;
}

function isTimeoutError(error: unknown): boolean {
  return (
    (error instanceof DOMException && error.name === 'AbortError') ||
    (isRecord(error) && error.name === 'AbortError')
  );
}

/**
 * Converts any thrown value into a `ParsedAppError` with a message
 * that's safe to render directly in the UI.
 */
export function parseError(error: unknown): ParsedAppError {
  if (isTimeoutError(error)) {
    return {
      category: 'network',
      code: 'REQUEST_TIMEOUT',
      message: 'That took too long to respond. Please check your connection and try again.',
      severity: 'warning',
      retryable: true,
      cause: error,
    };
  }

  if (isNetworkError(error)) {
    return {
      category: 'network',
      code: 'OFFLINE',
      message: 'You appear to be offline. Please check your connection and try again.',
      severity: 'warning',
      retryable: true,
      cause: error,
    };
  }

  if (isOtpLikeError(error)) {
    return {
      category: 'otp',
      code: error.code,
      message: OTP_MESSAGES[error.code],
      severity: OTP_SEVERITIES[error.code],
      retryable: error.code !== 'OTP_MAX_ATTEMPTS',
      retryAfterSeconds: OTP_DEFAULT_RETRY_AFTER_SECONDS[error.code],
      cause: error,
    };
  }

  if (isPaymentLikeError(error)) {
    return {
      category: 'payment',
      code: error.code,
      message: error.description?.trim() || PAYMENT_MESSAGES[error.code],
      severity: PAYMENT_SEVERITIES[error.code],
      retryable: error.code !== 'PAYMENT_CANCELLED' && error.code !== 'CARD_EXPIRED' && error.code !== 'GATEWAY_TIMEOUT',
      cause: error,
    };
  }

  const status = extractHttpStatus(error);
  if (status !== undefined && status in HTTP_STATUS_MESSAGES) {
    const mapped = HTTP_STATUS_MESSAGES[status];
    return {
      category: mapped.category,
      code: `HTTP_${status}`,
      message: mapped.message,
      severity: mapped.severity,
      retryable: mapped.retryable,
      retryAfterSeconds: extractRetryAfterSeconds(error) ?? mapped.retryAfterSeconds,
      cause: error,
    };
  }

  if (status !== undefined) {
    return {
      category: status >= 500 ? 'server' : 'validation',
      code: `HTTP_${status}`,
      message: 'Something unexpected happened. Please try again.',
      severity: status >= 500 ? 'error' : 'warning',
      retryable: status >= 500,
      retryAfterSeconds: extractRetryAfterSeconds(error),
      cause: error,
    };
  }

  return {
    category: 'unknown',
    code: 'UNKNOWN_ERROR',
    message: 'Something unexpected happened. Please try again.',
    severity: 'error',
    retryable: true,
    cause: error,
  };
}

/** Convenience shortcut for call sites that only need the display string. */
export function getErrorMessage(error: unknown): string {
  return parseError(error).message;
}

/** Convenience shortcut for deciding whether to show a "Retry" action. */
export function isRetryableError(error: unknown): boolean {
  return parseError(error).retryable;
}

/** Convenience shortcut for toast/banner components deciding how loudly to surface an error. */
export function getErrorSeverity(error: unknown): ErrorSeverity {
  return parseError(error).severity;
}

/** Convenience shortcut for the number of seconds to wait before re-offering a "Retry" action, if known. */
export function getRetryAfterSeconds(error: unknown): number | undefined {
  return parseError(error).retryAfterSeconds;
}
