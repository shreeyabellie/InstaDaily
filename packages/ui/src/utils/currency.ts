/**
 * packages/ui/src/utils/currency.ts
 *
 * InstaDaily Design System — Currency Formatting Utilities
 * ----------------------------------------------------------------
 * Single source of truth for converting raw numbers into
 * Indian Rupee display strings (e.g. `1299` -> `₹1,299`).
 *
 * Prices across InstaDaily are stored in whole rupees in some
 * places and in paise (1 rupee = 100 paise) in others — use the
 * helper that matches how the amount is stored rather than
 * dividing/multiplying by 100 inline at the call site.
 */

export interface FormatINROptions {
  /** Show paise as a decimal, e.g. ₹1,299.50 instead of ₹1,300. Default: false. */
  showDecimals?: boolean;
}

export interface FormatINRCompactOptions {
  /** Number of significant fraction digits in the compact form, e.g. ₹1.5L. Default: 1. */
  maximumFractionDigits?: number;
}

const wholeRupeeFormatter = new Intl.NumberFormat('en-IN', {
  style: 'currency',
  currency: 'INR',
  maximumFractionDigits: 0,
});

const decimalRupeeFormatter = new Intl.NumberFormat('en-IN', {
  style: 'currency',
  currency: 'INR',
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

/**
 * Formats a raw rupee amount into an Indian Rupee string using the
 * Indian digit grouping convention (lakh/crore commas). Accepts
 * `null`/`undefined` so call sites can pass optional or not-yet-loaded
 * values (e.g. a product price before its API response resolves)
 * without a separate guard at every call site — these render as `₹0`.
 *
 * formatINR(1299) -> "₹1,299"
 * formatINR(129900) -> "₹1,29,900"
 * formatINR(1299.5, { showDecimals: true }) -> "₹1,299.50"
 * formatINR(-1299) -> "-₹1,299"
 * formatINR(null) -> "₹0"
 */
export function formatINR(amount: number | null | undefined, options: FormatINROptions = {}): string {
  if (typeof amount !== 'number' || !Number.isFinite(amount)) {
    return '₹0';
  }

  const formatter = options.showDecimals ? decimalRupeeFormatter : wholeRupeeFormatter;
  return formatter.format(amount);
}

/**
 * Formats an amount stored in paise (the smallest INR unit, as used
 * by most Indian payment gateways) into a Rupee display string.
 * Accepts `null`/`undefined`, rendering `₹0`.
 *
 * formatPaiseToINR(129900) -> "₹1,299"
 */
export function formatPaiseToINR(
  amountInPaise: number | null | undefined,
  options: FormatINROptions = {}
): string {
  if (typeof amountInPaise !== 'number' || !Number.isFinite(amountInPaise)) {
    return '₹0';
  }

  return formatINR(amountInPaise / 100, options);
}

/**
 * Formats a large rupee amount using Indian compact notation
 * (thousand/lakh/crore) instead of full digit grouping. Accepts
 * `null`/`undefined`, rendering `₹0`.
 *
 * formatINRCompact(150000) -> "₹1.5L"
 * formatINRCompact(12500000) -> "₹1.3Cr"
 */
export function formatINRCompact(
  amount: number | null | undefined,
  options: FormatINRCompactOptions = {}
): string {
  if (typeof amount !== 'number' || !Number.isFinite(amount)) {
    return '₹0';
  }

  const formatter = new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    notation: 'compact',
    maximumFractionDigits: options.maximumFractionDigits ?? 1,
  });

  return formatter.format(amount);
}

/**
 * Parses a user-entered or API-provided value into a finite rupee
 * number, returning `0` for anything that isn't a valid amount.
 * Useful when reading price input fields or untyped API responses.
 */
export function parseRupeeAmount(value: string | number | null | undefined): number {
  if (typeof value === 'number') {
    return Number.isFinite(value) ? value : 0;
  }

  if (typeof value !== 'string') {
    return 0;
  }

  const normalized = value.replace(/[₹,\s]/g, '');
  const parsed = Number.parseFloat(normalized);
  return Number.isFinite(parsed) ? parsed : 0;
}
