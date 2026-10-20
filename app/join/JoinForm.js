'use client';

import Link from 'next/link';
import { useActionState, useState } from 'react';
import { HELP_URL } from '@/lib/help';
import useSubmitOnce from '../dashboard/useSubmitOnce';
import authStyles from '../AuthForm.module.css';
import styles from './join.module.css';
import { joinGroup } from './actions';

export default function JoinForm({ initialCode = '' }) {
  const [state, formAction, pending] = useActionState(joinGroup, null);
  const onSubmit = useSubmitOnce(pending);
  // Controlled so a wrong code stays in the box (React 19 resets uncontrolled forms after an action).
  const [code, setCode] = useState(initialCode);

  return (
    <main className={authStyles.login}>
      <div className={authStyles.art}>
        <div>
          <h1 className={authStyles.wordmark}>Engager</h1>
          <p className={authStyles.tagline}>Post once a day. Support everyone else&apos;s.</p>
        </div>
        <div className={authStyles.rhythm} aria-hidden="true">
          <span>Post</span>
          <span>Engage</span>
          <span>Mark done</span>
        </div>
      </div>

      <form action={formAction} onSubmit={onSubmit} className={authStyles.form}>
        <h2 className={authStyles.title}>Join a group</h2>
        <p className="small">Enter the code from your group chat, or open the link you were sent.</p>

        <label className="field">
          Invite code
          <input
            className={styles.code}
            name="code"
            type="text"
            value={code}
            onChange={(event) => setCode(event.target.value)}
            maxLength={40}
            autoComplete="off"
            autoCapitalize="characters"
            autoCorrect="off"
            spellCheck={false}
            required
            readOnly={pending}
          />
        </label>

        <button type="submit" className="btn btn-block" disabled={pending} aria-busy={pending}>
          {pending && <span className="spinner" aria-hidden="true" />}
          {pending ? 'Joining…' : 'Join group'}
        </button>

        {state?.error && (
          <p className="err" role="alert">
            {state.error}{' '}
            {state.helpLink && (
              <a className="link" href={HELP_URL} target="_blank" rel="noopener noreferrer">
                Need help?
              </a>
            )}
          </p>
        )}
        {state?.info && (
          <p className={styles.info} role="status">
            {state.info}{' '}
            {state.dashboardLink && <Link className="link" href="/dashboard">Go to dashboard</Link>}
          </p>
        )}

        <p className="small">
          Wrong code? Letters like O, I and L are read as 0 and 1 for you. 5 wrong tries in a day locks joining.
        </p>
        <p className="small">
          <Link className="link" href="/dashboard">Back to dashboard</Link>
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
