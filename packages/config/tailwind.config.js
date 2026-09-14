/**
 * packages/config/tailwind.config.js
 *
 * InstaDaily Design System — Shared Tailwind Configuration
 * ----------------------------------------------------------------
 * The single source of truth for spacing, radii, typography, and
 * colors across every app/package in the monorepo. Apps should
 * re-export this config as a preset rather than defining their own:
 *
 *   // apps/web/tailwind.config.js
 *   const sharedConfig = require('@instadaily/config/tailwind.config.js');
 *
 *   module.exports = {
 *     presets: [sharedConfig],
 *     content: [
 *       ...sharedConfig.content,
 *       // app-specific globs beyond what the preset already covers
 *     ],
 *   };
 *
 * Colors mirror `packages/ui/src/tokens/colors.ts` — keep the two in
 * sync when the palette changes (this file stays plain CommonJS so it
 * can be loaded directly by the Tailwind CLI/PostCSS without a
 * TypeScript build step). Primitive scales (`orange`, `slate`, ...)
 * are copied here verbatim; the semantic layer (`background`,
 * `surface`, `success`, ...) is exposed as CSS-variable-backed tokens
 * so the same class (e.g. `bg-background`) resolves to the correct
 * WCAG AA-compliant value in both light and dark mode. Those
 * variables are declared in `packages/ui/src/styles/theme.css`, which
 * must be imported once at the application root.
 */

/** 8pt spacing grid — every spacing value is a multiple of 4px, with the
 * primary rhythm landing on 8px steps (4px reserved for fine adjustments). */
const SPACING = {
  0: '0px',
  px: '1px',
  0.5: '2px',
  1: '4px',
  1.5: '6px',
  2: '8px',
  2.5: '10px',
  3: '12px',
  4: '16px',
  5: '20px',
  6: '24px',
  7: '28px',
  8: '32px',
  9: '36px',
  10: '40px',
  11: '44px',
  12: '48px',
  14: '56px',
  16: '64px',
  20: '80px',
  24: '96px',
  28: '112px',
  32: '128px',
  36: '144px',
  40: '160px',
  48: '192px',
  56: '224px',
  64: '256px',
};

/** Border-radius tokens used consistently across cards, buttons, inputs. */
const BORDER_RADIUS = {
  none: '0px',
  sm: '6px',
  DEFAULT: '8px',
  md: '10px',
  lg: '12px',
  xl: '16px',
  '2xl': '20px',
  '3xl': '24px',
  full: '9999px',
};

const COLORS = {
  orange: {
    50: '#FFF7ED',
    100: '#FFEDD5',
    200: '#FED7AA',
    300: '#FDBA74',
    400: '#FB923C',
    500: '#F97316',
    600: '#EA580C',
    700: '#C2410C',
    800: '#9A3412',
    900: '#7C2D12',
    950: '#431407',
  },
  slate: {
    50: '#F8FAFC',
    100: '#F1F5F9',
    200: '#E2E8F0',
    300: '#CBD5E1',
    400: '#94A3B8',
    500: '#64748B',
    600: '#475569',
    700: '#334155',
    800: '#1E293B',
    900: '#0F172A',
    950: '#020617',
  },
  cream: {
    50: '#FFFDF9',
    100: '#FEFBF3',
    200: '#FDF6E8',
    300: '#FAEFD8',
    400: '#F5E4C0',
    500: '#EDD5A3',
    600: '#D9B876',
    700: '#B8944F',
    800: '#8C6E3A',
    900: '#5C4826',
    950: '#332715',
  },
  green: {
    50: '#F0FDF4',
    100: '#DCFCE7',
    200: '#BBF7D0',
    300: '#86EFAC',
    400: '#4ADE80',
    500: '#22C55E',
    600: '#16A34A',
    700: '#15803D',
    800: '#166534',
    900: '#14532D',
    950: '#052E16',
  },
  red: {
    50: '#FEF2F2',
    100: '#FEE2E2',
    200: '#FECACA',
    300: '#FCA5A5',
    400: '#F87171',
    500: '#EF4444',
    600: '#DC2626',
    700: '#B91C1C',
    800: '#991B1B',
    900: '#7F1D1D',
    950: '#450A0A',
  },
  amber: {
    50: '#FFFBEB',
    100: '#FEF3C7',
    200: '#FDE68A',
    300: '#FCD34D',
    400: '#FBBF24',
    500: '#F59E0B',
    600: '#D97706',
    700: '#B45309',
    800: '#92400E',
    900: '#78350F',
    950: '#451A03',
  },
  blue: {
    50: '#EFF6FF',
    100: '#DBEAFE',
    200: '#BFDBFE',
    300: '#93C5FD',
    400: '#60A5FA',
    500: '#3B82F6',
    600: '#2563EB',
    700: '#1D4ED8',
    800: '#1E40AF',
    900: '#1E3A8A',
    950: '#172554',
  },
};

/**
 * Semantic color tokens, backed by the CSS custom properties declared
 * in `packages/ui/src/styles/theme.css`. Each token resolves to a
 * different literal value under `:root` (light) vs `.dark`, so a
 * single class like `bg-background` or `text-foreground-secondary`
 * stays WCAG AA-compliant in both modes without a `dark:` variant.
 * Status colors (`success`/`error`/`warning`/`info`) additionally
 * expose the full 50–950 primitive scale for one-off cases (badges,
 * charts) that need a specific shade rather than a themed role.
 */
function statusColorSet(prefix) {
  return {
    bg: `var(--color-${prefix}-bg)`,
    'bg-subtle': `var(--color-${prefix}-bg-subtle)`,
    border: `var(--color-${prefix}-border)`,
    text: `var(--color-${prefix}-text)`,
    icon: `var(--color-${prefix}-icon)`,
    solid: `var(--color-${prefix}-solid)`,
    'solid-hover': `var(--color-${prefix}-solid-hover)`,
    'on-solid': `var(--color-${prefix}-on-solid)`,
  };
}

const SEMANTIC_COLORS = {
  brand: {
    DEFAULT: 'var(--color-brand-primary)',
    hover: 'var(--color-brand-primary-hover)',
    active: 'var(--color-brand-primary-active)',
    subtle: 'var(--color-brand-primary-subtle)',
    'subtle-hover': 'var(--color-brand-primary-subtle-hover)',
    border: 'var(--color-brand-primary-border)',
    foreground: 'var(--color-brand-on-primary)',
  },
  background: {
    DEFAULT: 'var(--color-background)',
    subtle: 'var(--color-background-subtle)',
  },
  surface: {
    DEFAULT: 'var(--color-surface)',
    elevated: 'var(--color-surface-elevated)',
    overlay: 'var(--color-surface-overlay)',
  },
  border: {
    DEFAULT: 'var(--color-border)',
    subtle: 'var(--color-border-subtle)',
  },
  foreground: {
    DEFAULT: 'var(--color-text-primary)',
    secondary: 'var(--color-text-secondary)',
    tertiary: 'var(--color-text-tertiary)',
    inverse: 'var(--color-text-inverse)',
    disabled: 'var(--color-text-disabled)',
  },
  success: { ...COLORS.green, ...statusColorSet('success') },
  error: { ...COLORS.red, ...statusColorSet('error') },
  warning: { ...COLORS.amber, ...statusColorSet('warning') },
  info: { ...COLORS.blue, ...statusColorSet('info') },
};

/** Typography scale — font size paired with an 8pt-grid-aligned line height. */
const FONT_SIZE = {
  xs: ['12px', { lineHeight: '16px' }],
  sm: ['14px', { lineHeight: '20px' }],
  base: ['16px', { lineHeight: '24px' }],
  lg: ['18px', { lineHeight: '28px' }],
  xl: ['20px', { lineHeight: '28px' }],
  '2xl': ['24px', { lineHeight: '32px' }],
  '3xl': ['30px', { lineHeight: '36px' }],
  '4xl': ['36px', { lineHeight: '40px' }],
  '5xl': ['48px', { lineHeight: '56px' }],
};

/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: 'class',
  content: [
    './app/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './apps/*/app/**/*.{js,ts,jsx,tsx,mdx}',
    './apps/*/components/**/*.{js,ts,jsx,tsx,mdx}',
    './apps/*/context/**/*.{js,ts,jsx,tsx,mdx}',
    './packages/ui/src/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    spacing: SPACING,
    borderRadius: BORDER_RADIUS,
    extend: {
      colors: {
        orange: COLORS.orange,
        slate: COLORS.slate,
        cream: COLORS.cream,
        ...SEMANTIC_COLORS,
      },
      fontFamily: {
        sans: ['-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'Helvetica', 'Arial', 'sans-serif'],
      },
      fontSize: FONT_SIZE,
    },
  },
  plugins: [],
};

module.exports.spacing = SPACING;
module.exports.borderRadius = BORDER_RADIUS;
module.exports.colors = COLORS;
module.exports.semanticColors = SEMANTIC_COLORS;
module.exports.fontSize = FONT_SIZE;
