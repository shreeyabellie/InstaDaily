'use client';

/**
 * apps/web/context/AuthContext.tsx
 *
 * Global session context for InstaDaily, backed by Supabase Auth's
 * phone-OTP flow. Owns:
 *  - `requestOtp` / `verifyOtp` to drive OTP-based sign-in.
 *  - The active user's profile and the raw Supabase `Session`/token.
 *  - `signOut`.
 *  - Silent token refresh, driven entirely by Supabase's own
 *    `onAuthStateChange` listener (the browser client's internal
 *    `autoRefreshToken` timer refreshes the access token ahead of
 *    expiry and emits a `TOKEN_REFRESHED` event, which this provider
 *    listens for and mirrors into React state).
 *
 * Consumed by `apps/web/components/Auth/OtpLoginForm.tsx` for the
 * sign-in UI, and mirrors the same Supabase session that
 * `apps/web/middleware.ts` validates on the edge.
 */

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import { createBrowserClient } from '@supabase/ssr';
import { AuthError, type Session, type SupabaseClient, type User } from '@supabase/supabase-js';
import { getErrorMessage } from '../lib/errors/errorHandler';

export interface AuthUserProfile {
  id: string;
  /** E.164 formatted, e.g. "+919876543210", or null if the account has no phone on file. */
  phone: string | null;
  email: string | null;
  displayName: string | null;
  createdAt: string;
}

export type AuthStatus =
  | 'initializing'
  | 'idle'
  | 'sendingOtp'
  | 'verifyingOtp'
  | 'authenticated'
  | 'unauthenticated'
  | 'refreshing';

interface AuthContextValue {
  status: AuthStatus;
  user: AuthUserProfile | null;
  session: Session | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
  requestOtp: (phone: string) => Promise<void>;
  verifyOtp: (phone: string, code: string) => Promise<AuthUserProfile>;
  signOut: () => Promise<void>;
  refreshSession: () => Promise<void>;
  clearError: () => void;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

const PHONE_REGEX = /^[6-9]\d{9}$/;
const OTP_REGEX = /^\d{6}$/;

/** How long to wait for Supabase's `INITIAL_SESSION` event before falling back to an explicit `getSession()` call. */
const INITIAL_SESSION_FALLBACK_MS = 2000;

// ---------------------------------------------------------------------------
// Supabase browser client — cached at module scope so re-mounting
// AuthProvider (Fast Refresh, tests) never spins up a second GoTrue client
// against the same storage key.
// ---------------------------------------------------------------------------

let cachedClient: SupabaseClient | null = null;
let cachedConfigError: string | null = null;

function getSupabaseBrowserClient(): { client: SupabaseClient | null; configError: string | null } {
  if (cachedClient || cachedConfigError) {
    return { client: cachedClient, configError: cachedConfigError };
  }

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseAnonKey) {
    cachedConfigError = 'Authentication is not configured. Please contact support.';
    return { client: null, configError: cachedConfigError };
  }

  cachedClient = createBrowserClient(supabaseUrl, supabaseAnonKey);
  return { client: cachedClient, configError: null };
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function normalizePhone(rawPhone: string): string {
  const digitsOnly = rawPhone.replace(/\D/g, '').slice(-10);
  return `+91${digitsOnly}`;
}

function toAuthUserProfile(user: User): AuthUserProfile {
  const metadataName = user.user_metadata?.full_name;

  return {
    id: user.id,
    phone: user.phone ? `+${user.phone.replace(/^\+/, '')}` : null,
    email: user.email ?? null,
    displayName: typeof metadataName === 'string' && metadataName.length > 0 ? metadataName : null,
    createdAt: user.created_at,
  };
}

const OTP_ERROR_MESSAGES: Record<string, string> = {
  otp_expired: 'That OTP has expired. Request a new one to continue.',
  invalid_credentials: 'That OTP doesn’t look right. Please check and try again.',
  otp_disabled: 'OTP sign-in is currently unavailable. Please try again later.',
  over_sms_send_rate_limit: 'You’ve requested too many OTPs. Please wait before requesting another.',
  over_request_rate_limit: 'Too many attempts. Please wait a moment and try again.',
  sms_send_failed: 'We couldn’t send an OTP to that number. Please check it and try again.',
};

/** Prefers InstaDaily's known OTP error copy, then falls back to the shared HTTP/network-aware parser. */
function resolveAuthErrorMessage(error: unknown): string {
  if (error instanceof AuthError && error.code && error.code in OTP_ERROR_MESSAGES) {
    return OTP_ERROR_MESSAGES[error.code];
  }

  return getErrorMessage(error);
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

export function AuthProvider({ children }: { children: ReactNode }) {
  const [status, setStatus] = useState<AuthStatus>('initializing');
  const [user, setUser] = useState<AuthUserProfile | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [error, setError] = useState<string | null>(null);

  const { client: supabase, configError } = useMemo(() => getSupabaseBrowserClient(), []);

  const mountedRef = useRef(true);
  useEffect(
    () => () => {
      mountedRef.current = false;
    },
    []
  );

  useEffect(() => {
    if (configError) {
      setError(configError);
      setStatus('unauthenticated');
      return;
    }

    if (!supabase) {
      return;
    }

    let initialSessionHandled = false;

    const { data: authListener } = supabase.auth.onAuthStateChange((event, nextSession) => {
      if (!mountedRef.current) {
        return;
      }

      switch (event) {
        case 'INITIAL_SESSION': {
          initialSessionHandled = true;
          setSession(nextSession);
          setUser(nextSession?.user ? toAuthUserProfile(nextSession.user) : null);
          setStatus(nextSession ? 'authenticated' : 'unauthenticated');
          break;
        }
        case 'SIGNED_IN': {
          setSession(nextSession);
          setUser(nextSession?.user ? toAuthUserProfile(nextSession.user) : null);
          setStatus('authenticated');
          setError(null);
          break;
        }
        case 'TOKEN_REFRESHED': {
          setSession(nextSession);
          if (nextSession?.user) {
            setUser(toAuthUserProfile(nextSession.user));
          }
          setStatus('authenticated');
          break;
        }
        case 'USER_UPDATED': {
          setSession(nextSession);
          if (nextSession?.user) {
            setUser(toAuthUserProfile(nextSession.user));
          }
          break;
        }
        case 'SIGNED_OUT': {
          setSession(null);
          setUser(null);
          setStatus('unauthenticated');
          break;
        }
        default:
          break;
      }
    });

    // `INITIAL_SESSION` normally arrives within a tick of subscribing. As a
    // defensive fallback (slow storage access, an older client version),
    // resolve the session explicitly so the provider never gets stuck in
    // "initializing" indefinitely.
    const fallbackTimer = setTimeout(() => {
      if (initialSessionHandled || !mountedRef.current) {
        return;
      }

      supabase.auth
        .getSession()
        .then(({ data, error: sessionError }) => {
          if (!mountedRef.current) {
            return;
          }

          if (sessionError) {
            setError(resolveAuthErrorMessage(sessionError));
            setStatus('unauthenticated');
            return;
          }

          setSession(data.session);
          setUser(data.session?.user ? toAuthUserProfile(data.session.user) : null);
          setStatus(data.session ? 'authenticated' : 'unauthenticated');
        })
        .catch((sessionError: unknown) => {
          if (!mountedRef.current) {
            return;
          }
          setError(resolveAuthErrorMessage(sessionError));
          setStatus('unauthenticated');
        });
    }, INITIAL_SESSION_FALLBACK_MS);

    return () => {
      clearTimeout(fallbackTimer);
      authListener.subscription.unsubscribe();
    };
  }, [supabase, configError]);

  const requestOtp = useCallback(
    async (phone: string): Promise<void> => {
      if (!supabase) {
        const message = configError ?? 'Authentication is not configured.';
        setError(message);
        throw new Error(message);
      }

      if (!PHONE_REGEX.test(phone)) {
        const message = 'Enter a valid 10-digit Indian mobile number.';
        setError(message);
        throw new Error(message);
      }

      setStatus('sendingOtp');
      setError(null);

      const { error: otpError } = await supabase.auth.signInWithOtp({
        phone: normalizePhone(phone),
      });

      if (otpError) {
        setError(resolveAuthErrorMessage(otpError));
        setStatus('unauthenticated');
        throw otpError;
      }

      setStatus('idle');
    },
    [supabase, configError]
  );

  const verifyOtp = useCallback(
    async (phone: string, code: string): Promise<AuthUserProfile> => {
      if (!supabase) {
        const message = configError ?? 'Authentication is not configured.';
        setError(message);
        throw new Error(message);
      }

      if (!OTP_REGEX.test(code)) {
        setError('Enter the 6-digit code we sent you.');
        throw { code: 'invalid_credentials' } satisfies { code: string };
      }

      setStatus('verifyingOtp');
      setError(null);

      const { data, error: verifyError } = await supabase.auth.verifyOtp({
        phone: normalizePhone(phone),
        token: code,
        type: 'sms',
      });

      if (verifyError || !data.user) {
        const failure = verifyError ?? { code: 'invalid_credentials' };
        setError(resolveAuthErrorMessage(failure));
        setStatus('unauthenticated');
        throw failure;
      }

      const profile = toAuthUserProfile(data.user);
      setSession(data.session);
      setUser(profile);
      setStatus('authenticated');
      return profile;
    },
    [supabase, configError]
  );

  const signOut = useCallback(async (): Promise<void> => {
    if (!supabase) {
      setUser(null);
      setSession(null);
      setStatus('unauthenticated');
      return;
    }

    const { error: signOutError } = await supabase.auth.signOut();

    if (signOutError) {
      setError(resolveAuthErrorMessage(signOutError));
    }

    // Clear local state even if the network call failed, so the shopper is
    // never stranded on a signed-in screen with a session Supabase already
    // considers dead.
    setUser(null);
    setSession(null);
    setStatus('unauthenticated');
  }, [supabase]);

  const refreshSession = useCallback(async (): Promise<void> => {
    if (!supabase) {
      return;
    }

    setStatus('refreshing');

    const { data, error: refreshError } = await supabase.auth.refreshSession();

    if (refreshError) {
      setError(resolveAuthErrorMessage(refreshError));
      setUser(null);
      setSession(null);
      setStatus('unauthenticated');
      return;
    }

    setSession(data.session);
    setUser(data.session?.user ? toAuthUserProfile(data.session.user) : null);
    setStatus(data.session ? 'authenticated' : 'unauthenticated');
  }, [supabase]);

  const clearError = useCallback(() => setError(null), []);

  const value = useMemo<AuthContextValue>(
    () => ({
      status,
      user,
      session,
      isAuthenticated: status === 'authenticated' && user !== null,
      isLoading:
        status === 'initializing' ||
        status === 'sendingOtp' ||
        status === 'verifyingOtp' ||
        status === 'refreshing',
      error,
      requestOtp,
      verifyOtp,
      signOut,
      refreshSession,
      clearError,
    }),
    [status, user, session, error, requestOtp, verifyOtp, signOut, refreshSession, clearError]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);

  if (!context) {
    throw new Error('useAuth must be used inside an AuthProvider');
  }

  return context;
}
