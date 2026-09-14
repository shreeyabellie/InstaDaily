/**
 * apps/web/middleware.ts
 *
 * Edge-level route protection backed by Supabase Auth.
 *
 * On every non-public request this:
 *   1. Builds a Supabase server client bound to the request/response cookie jar.
 *   2. Calls `supabase.auth.getUser()`, which validates the session's JWT
 *      against the Supabase Auth server (never trusting the cookie payload
 *      on its own) and transparently refreshes the access token via the
 *      refresh-token cookie when it's near/past expiry. Any refreshed
 *      tokens are re-written onto both the request (for downstream reads
 *      in this same invocation) and the outgoing response (so the browser
 *      receives the new `Set-Cookie`).
 *   3. Redirects to `/login?redirect=<original-path>` when there's no
 *      valid user, or lets the request through with the (possibly
 *      refreshed) session cookies attached.
 *
 * Public routes (login, OTP verification, Supabase auth callbacks, static
 * assets) bypass the check entirely.
 *
 * Works alongside `apps/web/context/AuthContext.tsx`, which mirrors this
 * same Supabase session on the client.
 */

import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';
import type { User } from '@supabase/supabase-js';

/** Path prefixes reachable without an authenticated session. */
const PUBLIC_ROUTE_PREFIXES = ['/login', '/auth', '/onboarding'] as const;

/** Number of times to retry `getUser()` after a transient network failure (not an auth failure). */
const SESSION_CHECK_MAX_ATTEMPTS = 2;
const SESSION_CHECK_RETRY_DELAY_MS = 150;

interface SessionCheckResult {
  user: User | null;
  /** True only when we could not reach Supabase Auth at all after retrying — distinct from "no session". */
  checkFailed: boolean;
}

function isPublicRoute(pathname: string): boolean {
  return PUBLIC_ROUTE_PREFIXES.some(
    (prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`)
  );
}

function isStaticAssetPath(pathname: string): boolean {
  return (
    pathname.startsWith('/_next/') ||
    pathname === '/favicon.ico' ||
    /\.(?:png|jpg|jpeg|svg|webp|gif|ico|css|js|map|txt|xml|json|woff2?|ttf)$/i.test(pathname)
  );
}

/**
 * Only allow same-origin, absolute-path redirect targets (e.g. "/cart"),
 * rejecting protocol-relative ("//evil.com") or absolute URLs so an
 * attacker can't smuggle an open redirect through `?redirect=`.
 */
function sanitizeRedirectTarget(rawTarget: string | null): string | null {
  if (!rawTarget) {
    return null;
  }

  if (!rawTarget.startsWith('/') || rawTarget.startsWith('//')) {
    return null;
  }

  try {
    // Resolving against a dummy origin rejects malformed/backslash-based tricks
    // (e.g. "/\evil.com") while leaving legitimate paths untouched.
    const resolved = new URL(rawTarget, 'https://instadaily.internal');
    if (resolved.origin !== 'https://instadaily.internal') {
      return null;
    }
    return `${resolved.pathname}${resolved.search}${resolved.hash}`;
  } catch {
    return null;
  }
}

async function checkSession(
  supabase: ReturnType<typeof createServerClient>
): Promise<SessionCheckResult> {
  for (let attempt = 1; attempt <= SESSION_CHECK_MAX_ATTEMPTS; attempt += 1) {
    try {
      const { data, error } = await supabase.auth.getUser();

      if (error) {
        // An auth-level error (no session, expired refresh token, revoked
        // token, etc.) is a definitive "not signed in" — retrying won't help.
        return { user: null, checkFailed: false };
      }

      return { user: data.user, checkFailed: false };
    } catch {
      if (attempt < SESSION_CHECK_MAX_ATTEMPTS) {
        await new Promise((resolve) => setTimeout(resolve, SESSION_CHECK_RETRY_DELAY_MS));
        continue;
      }

      // Exhausted retries on what looks like a network/infra fault talking
      // to Supabase Auth, as opposed to the user simply being unauthenticated.
      return { user: null, checkFailed: true };
    }
  }

  return { user: null, checkFailed: true };
}

export async function middleware(request: NextRequest): Promise<NextResponse> {
  const { pathname, search } = request.nextUrl;

  if (isStaticAssetPath(pathname)) {
    return NextResponse.next();
  }

  let response = NextResponse.next({
    request: { headers: request.headers },
  });

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseAnonKey) {
    // Misconfigured deployment: don't 500 the whole edge function. Let
    // public routes through untouched and fail closed on protected ones.
    if (isPublicRoute(pathname)) {
      return response;
    }

    const loginUrl = new URL('/login', request.url);
    loginUrl.searchParams.set('redirect', `${pathname}${search}`);
    loginUrl.searchParams.set('error', 'auth_unavailable');
    return NextResponse.redirect(loginUrl);
  }

  const supabase = createServerClient(supabaseUrl, supabaseAnonKey, {
    cookies: {
      get(name: string): string | undefined {
        return request.cookies.get(name)?.value;
      },
      set(name: string, value: string, options: CookieOptions): void {
        request.cookies.set({ name, value, ...options });
        response = NextResponse.next({ request: { headers: request.headers } });
        response.cookies.set({ name, value, ...options });
      },
      remove(name: string, options: CookieOptions): void {
        request.cookies.set({ name, value: '', ...options });
        response = NextResponse.next({ request: { headers: request.headers } });
        response.cookies.set({ name, value: '', ...options });
      },
    },
  });

  const { user, checkFailed } = await checkSession(supabase);

  if (isPublicRoute(pathname)) {
    if (user && pathname === '/login') {
      const requestedRedirect = sanitizeRedirectTarget(request.nextUrl.searchParams.get('redirect'));
      return NextResponse.redirect(new URL(requestedRedirect ?? '/', request.url));
    }
    return response;
  }

  if (!user) {
    const loginUrl = new URL('/login', request.url);
    loginUrl.searchParams.set('redirect', `${pathname}${search}`);
    if (checkFailed) {
      loginUrl.searchParams.set('error', 'session_check_failed');
    }
    return NextResponse.redirect(loginUrl);
  }

  return response;
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
};
