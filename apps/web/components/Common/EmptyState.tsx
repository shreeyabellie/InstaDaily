/**
 * apps/web/components/Common/EmptyState.tsx
 *
 * Reusable empty-state screen for any list/collection in InstaDaily
 * that can be empty — search results, the cart, order history, and
 * so on. The variant a caller passes is a discriminated union keyed
 * on `variant`, so TypeScript enforces exactly the props each variant
 * needs (e.g. only the "search" variant accepts `query`) and narrows
 * automatically inside the component with no casts.
 */

import type { ReactNode } from 'react';
import { Inbox, PackageSearch, ShoppingCart, Sparkles, type LucideIcon } from 'lucide-react';

interface SearchEmptyStateProps {
  variant: 'search';
  /** The term the user searched for, if any — shown back to them for context. */
  query?: string;
  /** Invoked when the user taps "Clear search". Omit to hide the action entirely. */
  onClearSearch?: () => void;
}

interface CartEmptyStateProps {
  variant: 'cart';
  /** Invoked when the user taps "Start shopping". Omit to hide the action entirely. */
  onBrowse?: () => void;
}

interface OrderHistoryEmptyStateProps {
  variant: 'orderHistory';
  /** Invoked when the user taps "Start shopping". Omit to hide the action entirely. */
  onBrowse?: () => void;
}

interface PantryEmptyStateProps {
  variant: 'pantry';
  /** Invoked when the user taps "Plan a recipe". Omit to hide the action entirely. */
  onPlanMeals?: () => void;
}

interface CustomEmptyStateProps {
  variant: 'custom';
  icon?: LucideIcon;
  title: string;
  description?: string;
  actionLabel?: string;
  onAction?: () => void;
  /** Optional secondary, lower-emphasis action (e.g. "Browse categories"). */
  secondaryActionLabel?: string;
  onSecondaryAction?: () => void;
}

type EmptyStateVariantProps =
  | SearchEmptyStateProps
  | CartEmptyStateProps
  | OrderHistoryEmptyStateProps
  | PantryEmptyStateProps
  | CustomEmptyStateProps;

export type EmptyStateProps = EmptyStateVariantProps & {
  className?: string;
  children?: ReactNode;
};

interface ResolvedEmptyStateContent {
  icon: LucideIcon;
  title: string;
  description: string | undefined;
  actionLabel: string | undefined;
  onAction: (() => void) | undefined;
  secondaryActionLabel: string | undefined;
  onSecondaryAction: (() => void) | undefined;
}

function cn(...classes: Array<string | false | null | undefined>): string {
  return classes.filter(Boolean).join(' ');
}

function assertUnreachable(value: never): never {
  throw new Error(`EmptyState received an unhandled variant: ${JSON.stringify(value)}`);
}

function resolveContent(props: EmptyStateVariantProps): ResolvedEmptyStateContent {
  switch (props.variant) {
    case 'search': {
      const trimmedQuery = props.query?.trim();
      return {
        icon: PackageSearch,
        title: 'No results found',
        description: trimmedQuery
          ? `We couldn’t find anything for “${trimmedQuery}”. Try a different search term.`
          : 'Try a different search term or check the spelling.',
        actionLabel: props.onClearSearch ? 'Clear search' : undefined,
        onAction: props.onClearSearch,
        secondaryActionLabel: undefined,
        onSecondaryAction: undefined,
      };
    }

    case 'cart': {
      return {
        icon: ShoppingCart,
        title: 'Your cart is empty',
        description: 'Add groceries and daily essentials to get started.',
        actionLabel: props.onBrowse ? 'Start shopping' : undefined,
        onAction: props.onBrowse,
        secondaryActionLabel: undefined,
        onSecondaryAction: undefined,
      };
    }

    case 'orderHistory': {
      return {
        icon: Inbox,
        title: 'No orders yet',
        description: 'Once you place an order, you’ll be able to track it and reorder from here.',
        actionLabel: props.onBrowse ? 'Start shopping' : undefined,
        onAction: props.onBrowse,
        secondaryActionLabel: undefined,
        onSecondaryAction: undefined,
      };
    }

    case 'pantry': {
      return {
        icon: Sparkles,
        title: 'Your pantry is all stocked up!',
        description: 'Nothing’s running low right now. We’ll let you know when it’s time to reorder.',
        actionLabel: props.onPlanMeals ? 'Plan a recipe' : undefined,
        onAction: props.onPlanMeals,
        secondaryActionLabel: undefined,
        onSecondaryAction: undefined,
      };
    }

    case 'custom': {
      return {
        icon: props.icon ?? Inbox,
        title: props.title,
        description: props.description,
        actionLabel: props.onAction ? props.actionLabel : undefined,
        onAction: props.onAction,
        secondaryActionLabel: props.onSecondaryAction ? props.secondaryActionLabel : undefined,
        onSecondaryAction: props.onSecondaryAction,
      };
    }

    default:
      return assertUnreachable(props);
  }
}

export function EmptyState(props: EmptyStateProps): ReactNode {
  const { className, children, ...variantProps } = props;
  const { icon: Icon, title, description, actionLabel, onAction, secondaryActionLabel, onSecondaryAction } =
    resolveContent(variantProps);

  return (
    <div
      className={cn(
        'flex flex-col items-center justify-center gap-3 rounded-2xl px-6 py-12 text-center',
        className
      )}
    >
      <div className="flex h-16 w-16 items-center justify-center rounded-full bg-orange-50 text-[#F97316] dark:bg-orange-950 dark:text-orange-400">
        <Icon className="h-8 w-8" aria-hidden="true" />
      </div>

      <div className="flex flex-col gap-1">
        <h3 className="text-base font-bold text-neutral-900 dark:text-neutral-50">{title}</h3>
        {description && (
          <p className="max-w-xs text-sm text-neutral-500 dark:text-neutral-400">{description}</p>
        )}
      </div>

      {children}

      {(actionLabel || secondaryActionLabel) && (
        <div className="mt-2 flex flex-col items-center gap-2 sm:flex-row">
          {actionLabel && onAction && (
            <button
              type="button"
              onClick={onAction}
              className="inline-flex min-h-[44px] items-center justify-center rounded-xl bg-[#F97316] px-5 text-sm font-semibold text-white transition-colors duration-150 hover:bg-[#EA580C] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#F97316] focus-visible:ring-offset-2 dark:focus-visible:ring-offset-neutral-950"
            >
              {actionLabel}
            </button>
          )}
          {secondaryActionLabel && onSecondaryAction && (
            <button
              type="button"
              onClick={onSecondaryAction}
              className="inline-flex min-h-[44px] items-center justify-center rounded-xl border border-neutral-300 px-5 text-sm font-semibold text-neutral-700 transition-colors duration-150 hover:bg-neutral-50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#F97316] focus-visible:ring-offset-2 dark:border-neutral-700 dark:text-neutral-200 dark:hover:bg-neutral-900 dark:focus-visible:ring-offset-neutral-950"
            >
              {secondaryActionLabel}
            </button>
          )}
        </div>
      )}
    </div>
  );
}

export default EmptyState;
