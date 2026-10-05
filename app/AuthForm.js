'use client';

import Link from 'next/link';
import { useActionState } from 'react';
import { HELP_URL } from '@/lib/help';
import { login, signup } from './auth-actions';
import styles from './AuthForm.module.css';

export default function AuthForm({ mode }) {
  const isSignup = mode === 'signup';
  const [state, formAction, pending] = useActionState(isSignup ? signup : login, null);

  return (
    <main className={styles.login}>
      <div className={styles.art}>
        <div>
          <h1 className={styles.wordmark}>Engager</h1>
          <p className={styles.tagline}>Post once a day. Support everyone else&apos;s.</p>
        </div>
        <div className={styles.rhythm} aria-hidden="true">
          <span>Post</span>
          <span>Engage</span>
          <span>Mark done</span>
        </div>
      </div>

      <form action={formAction} className={styles.form}>
        <h2 className={styles.title}>{isSignup ? 'Create your account' : 'Log in to your account'}</h2>

        {isSignup && (
          <label className="field">
            Full name
            <input name="full_name" type="text" autoComplete="name" maxLength={80} required />
          </label>
        )}
        <label className="field">
          Email
          <input name="email" type="email" autoComplete="email" required />
        </label>
        <label className="field">
          Password
          <input
            name="password"
            type="password"
            autoComplete={isSignup ? 'new-password' : 'current-password'}
            minLength={isSignup ? 8 : undefined}
            required
          />
        </label>

        {state?.error && <p className="err" role="alert">{state.error}</p>}

        <button type="submit" className="btn btn-block" disabled={pending}>
          {pending ? 'Please wait…' : isSignup ? 'Sign up' : 'Log in'}
        </button>

        <p className="small">
          {isSignup ? (
            <>Already have an account? <Link className="link" href="/login">Log in</Link></>
          ) : (
            <>New here? <Link className="link" href="/signup">Create an account</Link></>
          )}
        </p>
        <p className="small">
          <a className="link" href={HELP_URL} target="_blank" rel="noopener noreferrer">
            Need help?
          </a>
        </p>
      </form>
    </main>
  );
}
