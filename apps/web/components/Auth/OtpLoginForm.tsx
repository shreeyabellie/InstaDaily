'use client';

/**
 * apps/web/components/Auth/OtpLoginForm.tsx
 *
 * Two-step Indian phone number + OTP login form:
 *  1. Phone entry — validates a 10-digit Indian mobile number (+91).
 *  2. OTP entry — validates a 6-digit code, with a resend cooldown
 *     timer and a lockout timer after repeated failed attempts.
 *
 * Wrapped in a local error boundary so a render-time failure here
 * doesn't take down the rest of the page.
 */

import {
  Component,
  useEffect,
  useRef,
  useState,
  type ClipboardEvent,
  type FormEvent,
  type KeyboardEvent,
  type ReactNode,
} from 'react';
import { Smartphone, AlertCircle, Loader2 } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { getErrorMessage } from '../../lib/errors/errorHandler';

const PHONE_REGEX = /^[6-9]\d{9}$/;
const OTP_REGEX = /^\d{6}$/;
const OTP_LENGTH = 6;

const RESEND_COOLDOWN_SECONDS = 30;
const MAX_VERIFY_ATTEMPTS = 5;
const LOCKOUT_SECONDS = 60;

type Step = 'phone' | 'otp';

const EMPTY_OTP_DIGITS: string[] = Array.from({ length: OTP_LENGTH }, () => '');

function cn(...classes: Array<string | false | null | undefined>): string {
  return classes.filter(Boolean).join(' ');
}

const INPUT_STYLES =
  'w-full min-h-[44px] rounded-xl border border-neutral-300 bg-white px-3 text-base text-neutral-900 ' +
  'placeholder:text-neutral-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#F97316] ' +
  'focus-visible:border-[#F97316] disabled:cursor-not-allowed disabled:opacity-60 ' +
  'dark:border-neutral-700 dark:bg-neutral-900 dark:text-neutral-50 dark:placeholder:text-neutral-500';

const PRIMARY_BUTTON_STYLES =
  'inline-flex w-full min-h-[44px] items-center justify-center gap-2 rounded-xl bg-[#F97316] px-4 ' +
  'text-base font-semibold text-white transition-colors duration-150 hover:bg-[#EA580C] ' +
  'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#F97316] focus-visible:ring-offset-2 ' +
  'disabled:cursor-not-allowed disabled:opacity-50 dark:focus-visible:ring-offset-neutral-950';

function formatCountdown(seconds: number): string {
  return `0:${seconds.toString().padStart(2, '0')}`;
}

function OtpLoginFormInner(): ReactNode {
  const { requestOtp, verifyOtp, status, error: authError, clearError } = useAuth();

  const [step, setStep] = useState<Step>('phone');
  const [phone, setPhone] = useState('');
  const [otpDigits, setOtpDigits] = useState<string[]>(EMPTY_OTP_DIGITS);
  const [fieldError, setFieldError] = useState<string | null>(null);
  const [resendSeconds, setResendSeconds] = useState(0);
  const [failedAttempts, setFailedAttempts] = useState(0);
  const [lockoutSeconds, setLockoutSeconds] = useState(0);

  const otpBoxRefs = useRef<Array<HTMLInputElement | null>>([]);

  const otp = otpDigits.join('');
  const isSendingOtp = status === 'sendingOtp';
  const isVerifyingOtp = status === 'verifyingOtp';
  const isLocked = lockoutSeconds > 0;
  const otpInputsDisabled = isVerifyingOtp || isLocked;

  const focusOtpBox = (index: number): void => {
    const clamped = Math.min(Math.max(index, 0), OTP_LENGTH - 1);
    otpBoxRefs.current[clamped]?.focus();
  };

  // Resend cooldown countdown.
  useEffect(() => {
    if (resendSeconds <= 0) {
      return;
    }
    const timer = setInterval(() => setResendSeconds((s) => Math.max(s - 1, 0)), 1000);
    return () => clearInterval(timer);
  }, [resendSeconds]);

  // Lockout countdown after too many failed OTP attempts.
  useEffect(() => {
    if (lockoutSeconds <= 0) {
      return;
    }
    const timer = setInterval(() => setLockoutSeconds((s) => Math.max(s - 1, 0)), 1000);
    return () => clearInterval(timer);
  }, [lockoutSeconds]);

  useEffect(() => {
    if (step === 'otp') {
      focusOtpBox(0);
    }
  }, [step]);

  const handlePhoneSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setFieldError(null);
    clearError();

    if (!PHONE_REGEX.test(phone)) {
      setFieldError('Enter a valid 10-digit Indian mobile number.');
      return;
    }

    try {
      await requestOtp(phone);
      setStep('otp');
      setOtpDigits(EMPTY_OTP_DIGITS);
      setFailedAttempts(0);
      setResendSeconds(RESEND_COOLDOWN_SECONDS);
    } catch (err) {
      setFieldError(getErrorMessage(err));
    }
  };

  const handleResend = async () => {
    if (resendSeconds > 0 || isSendingOtp) {
      return;
    }

    setFieldError(null);
    clearError();

    try {
      await requestOtp(phone);
      setOtpDigits(EMPTY_OTP_DIGITS);
      setFailedAttempts(0);
      setResendSeconds(RESEND_COOLDOWN_SECONDS);
      focusOtpBox(0);
    } catch (err) {
      setFieldError(getErrorMessage(err));
    }
  };

  const handleOtpSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setFieldError(null);
    clearError();

    if (isLocked) {
      return;
    }

    if (!OTP_REGEX.test(otp)) {
      setFieldError('Enter the 6-digit code we sent you.');
      return;
    }

    try {
      await verifyOtp(phone, otp);
      // On success, AuthContext flips `status` to "authenticated" and the
      // parent page/route is expected to redirect away from this form.
    } catch (err) {
      const nextAttempts = failedAttempts + 1;
      setFailedAttempts(nextAttempts);
      setOtpDigits(EMPTY_OTP_DIGITS);
      focusOtpBox(0);

      if (nextAttempts >= MAX_VERIFY_ATTEMPTS) {
        setLockoutSeconds(LOCKOUT_SECONDS);
        setFieldError(`Too many incorrect attempts. Try again in ${LOCKOUT_SECONDS}s.`);
      } else {
        setFieldError(getErrorMessage(err));
      }
    }
  };

  const handleOtpDigitChange = (index: number, rawValue: string): void => {
    const digits = rawValue.replace(/\D/g, '');

    if (digits.length === 0) {
      setOtpDigits((prev) => {
        const next = [...prev];
        next[index] = '';
        return next;
      });
      return;
    }

    setOtpDigits((prev) => {
      const next = [...prev];
      let cursor = index;
      for (const digit of digits) {
        if (cursor >= OTP_LENGTH) {
          break;
        }
        next[cursor] = digit;
        cursor += 1;
      }
      return next;
    });

    const lastFilledIndex = Math.min(index + digits.length, OTP_LENGTH) - 1;
    focusOtpBox(lastFilledIndex + 1 <= OTP_LENGTH - 1 ? lastFilledIndex + 1 : lastFilledIndex);
  };

  const handleOtpKeyDown = (index: number, event: KeyboardEvent<HTMLInputElement>): void => {
    if (event.key === 'Backspace') {
      if (otpDigits[index]) {
        setOtpDigits((prev) => {
          const next = [...prev];
          next[index] = '';
          return next;
        });
        return;
      }

      if (index > 0) {
        event.preventDefault();
        setOtpDigits((prev) => {
          const next = [...prev];
          next[index - 1] = '';
          return next;
        });
        focusOtpBox(index - 1);
      }
      return;
    }

    if (event.key === 'ArrowLeft' && index > 0) {
      event.preventDefault();
      focusOtpBox(index - 1);
      return;
    }

    if (event.key === 'ArrowRight' && index < OTP_LENGTH - 1) {
      event.preventDefault();
      focusOtpBox(index + 1);
    }
  };

  const handleOtpPaste = (event: ClipboardEvent<HTMLInputElement>): void => {
    const pasted = event.clipboardData.getData('text').replace(/\D/g, '').slice(0, OTP_LENGTH);
    if (pasted.length === 0) {
      return;
    }

    event.preventDefault();
    setOtpDigits(() => {
      const next = [...EMPTY_OTP_DIGITS];
      for (let i = 0; i < pasted.length; i += 1) {
        next[i] = pasted[i];
      }
      return next;
    });
    focusOtpBox(Math.min(pasted.length, OTP_LENGTH - 1));
  };

  const handleChangeNumber = () => {
    setStep('phone');
    setOtpDigits(EMPTY_OTP_DIGITS);
    setFieldError(null);
    setFailedAttempts(0);
    setResendSeconds(0);
    clearError();
  };

  const displayError = fieldError ?? authError;

  return (
    <div className="mx-auto w-full max-w-sm">
      {step === 'phone' ? (
        <form onSubmit={handlePhoneSubmit} noValidate className="flex flex-col gap-4">
          <div className="flex flex-col gap-1.5">
            <label htmlFor="phone" className="text-sm font-medium text-neutral-700 dark:text-neutral-200">
              Mobile number
            </label>
            <div className="flex items-stretch gap-2">
              <span className="flex min-h-[44px] items-center rounded-xl border border-neutral-300 bg-neutral-50 px-3 text-base font-medium text-neutral-600 dark:border-neutral-700 dark:bg-neutral-800 dark:text-neutral-300">
                +91
              </span>
              <div className="relative flex-1">
                <Smartphone
                  className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-neutral-400"
                  aria-hidden="true"
                />
                <input
                  id="phone"
                  type="tel"
                  inputMode="numeric"
                  autoComplete="tel-national"
                  maxLength={10}
                  placeholder="98765 43210"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value.replace(/\D/g, '').slice(0, 10))}
                  disabled={isSendingOtp}
                  aria-invalid={Boolean(displayError)}
                  aria-describedby={displayError ? 'phone-error' : undefined}
                  className={cn(INPUT_STYLES, 'pl-9')}
                />
              </div>
            </div>
          </div>

          {displayError && (
            <p id="phone-error" role="alert" className="flex items-start gap-1.5 text-sm text-red-600 dark:text-red-400">
              <AlertCircle className="mt-0.5 h-4 w-4 flex-shrink-0" aria-hidden="true" />
              {displayError}
            </p>
          )}

          <button type="submit" disabled={isSendingOtp} className={PRIMARY_BUTTON_STYLES}>
            {isSendingOtp && <Loader2 className="h-4 w-4 animate-spin" aria-hidden="true" />}
            {isSendingOtp ? 'Sending OTP…' : 'Send OTP'}
          </button>
        </form>
      ) : (
        <form onSubmit={handleOtpSubmit} noValidate className="flex flex-col gap-4">
          <div className="flex flex-col gap-1.5">
            <span id="otp-group-label" className="text-sm font-medium text-neutral-700 dark:text-neutral-200">
              Enter the 6-digit code
            </span>
            <p className="text-sm text-neutral-500 dark:text-neutral-400">
              Sent to +91 {phone}.{' '}
              <button
                type="button"
                onClick={handleChangeNumber}
                className="font-semibold text-[#F97316] underline-offset-2 hover:underline"
              >
                Change number
              </button>
            </p>
            <div
              role="group"
              aria-labelledby="otp-group-label"
              aria-describedby={displayError ? 'otp-error' : undefined}
              className="flex items-center justify-between gap-2"
            >
              {otpDigits.map((digit, index) => (
                <input
                  key={index}
                  ref={(el) => {
                    otpBoxRefs.current[index] = el;
                  }}
                  id={index === 0 ? 'otp' : undefined}
                  type="text"
                  inputMode="numeric"
                  autoComplete={index === 0 ? 'one-time-code' : 'off'}
                  maxLength={1}
                  value={digit}
                  onChange={(e) => handleOtpDigitChange(index, e.target.value)}
                  onKeyDown={(e) => handleOtpKeyDown(index, e)}
                  onPaste={handleOtpPaste}
                  onFocus={(e) => e.target.select()}
                  disabled={otpInputsDisabled}
                  aria-label={`Digit ${index + 1} of ${OTP_LENGTH}`}
                  aria-invalid={Boolean(displayError)}
                  className={cn(
                    INPUT_STYLES,
                    'h-12 w-12 flex-1 px-0 text-center text-xl font-semibold tracking-normal'
                  )}
                />
              ))}
            </div>
          </div>

          {displayError && (
            <p id="otp-error" role="alert" className="flex items-start gap-1.5 text-sm text-red-600 dark:text-red-400">
              <AlertCircle className="mt-0.5 h-4 w-4 flex-shrink-0" aria-hidden="true" />
              {displayError}
            </p>
          )}

          <button type="submit" disabled={isVerifyingOtp || isLocked} className={PRIMARY_BUTTON_STYLES}>
            {isVerifyingOtp && <Loader2 className="h-4 w-4 animate-spin" aria-hidden="true" />}
            {isVerifyingOtp ? 'Verifying…' : 'Verify & Continue'}
          </button>

          <button
            type="button"
            onClick={handleResend}
            disabled={resendSeconds > 0 || isSendingOtp}
            className="text-sm font-semibold text-[#F97316] disabled:cursor-not-allowed disabled:text-neutral-400 dark:disabled:text-neutral-600"
          >
            {resendSeconds > 0 ? `Resend OTP in ${formatCountdown(resendSeconds)}` : 'Resend OTP'}
          </button>
        </form>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Error boundary — catches render errors within the login form and offers a
// recovery path instead of crashing the whole auth page.
// ---------------------------------------------------------------------------

interface ErrorBoundaryState {
  hasError: boolean;
}

class OtpFormErrorBoundary extends Component<{ children: ReactNode }, ErrorBoundaryState> {
  state: ErrorBoundaryState = { hasError: false };

  static getDerivedStateFromError(): ErrorBoundaryState {
    return { hasError: true };
  }

  componentDidCatch(error: unknown): void {
    // eslint-disable-next-line no-console -- surfaced for now; wire to real logging later
    console.error('OtpLoginForm crashed:', error);
  }

  handleRetry = (): void => {
    this.setState({ hasError: false });
  };

  render(): ReactNode {
    if (this.state.hasError) {
      return (
        <div className="mx-auto flex w-full max-w-sm flex-col items-center gap-3 rounded-2xl border border-red-200 bg-red-50 p-6 text-center dark:border-red-900 dark:bg-red-950">
          <AlertCircle className="h-6 w-6 text-red-600 dark:text-red-400" aria-hidden="true" />
          <p className="text-sm font-medium text-red-700 dark:text-red-300">
            Something went wrong loading the login form.
          </p>
          <button
            type="button"
            onClick={this.handleRetry}
            className="text-sm font-semibold text-[#F97316] underline-offset-2 hover:underline"
          >
            Try again
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}

export default function OtpLoginForm(): ReactNode {
  return (
    <OtpFormErrorBoundary>
      <OtpLoginFormInner />
    </OtpFormErrorBoundary>
  );
}
