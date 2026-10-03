'use client';

import Link from 'next/link';
import { useActionState } from 'react';
import { HELP_URL } from '@/lib/help';
import { login, signup } from './auth-actions';

export default function AuthForm({ mode }) {
  const isSignup = mode === 'signup';
  const [state, formAction, pending] = useActionState(isSignup ? signup : login, null);

  return (
    <main className="auth-page">
      <div className="auth-card">
        <h1 className="brand brand-lg">Engager</h1>
        <p className="muted">{isSignup ? 'Create your account' : 'Log in to your account'}</p>

        <form action={formAction} className="stack">
          {isSignup && (
            <label className="field">
              <span>Full name</span>
              <input name="full_name" type="text" autoComplete="name" maxLength={80} required />
            </label>
          )}
          <label className="field">
            <span>Email</span>
            <input name="email" type="email" autoComplete="email" required />
          </label>
          <label className="field">
            <span>Password</span>
            <input
              name="password"
              type="password"
              autoComplete={isSignup ? 'new-password' : 'current-password'}
              minLength={isSignup ? 8 : undefined}
              required
            />
          </label>

          {state?.error && <p className="error" role="alert">{state.error}</p>}

          <button type="submit" className="btn btn-primary btn-block" disabled={pending}>
            {pending ? 'Please wait…' : isSignup ? 'Sign up' : 'Log in'}
          </button>
        </form>

        <p className="muted small center">
          {isSignup ? (
            <>Already have an account? <Link href="/login">Log in</Link></>
          ) : (
            <>New here? <Link href="/signup">Create an account</Link></>
          )}
        </p>
        <p className="muted small center">
          <a href={HELP_URL} target="_blank" rel="noopener noreferrer" className="help-link">
            Need help?
          </a>
        </p>
      </div>
    </main>
  );
}
