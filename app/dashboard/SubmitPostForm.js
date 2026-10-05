'use client';

import { useActionState } from 'react';
import { submitPost } from './actions';
import useSubmitOnce from './useSubmitOnce';
import styles from './dashboard.module.css';

export default function SubmitPostForm() {
  const [state, formAction, pending] = useActionState(submitPost, null);
  const onSubmit = useSubmitOnce(pending);

  return (
    <form action={formAction} onSubmit={onSubmit} className={styles.postForm}>
      <label htmlFor="url" className="sr-only">LinkedIn post URL</label>
      <input
        id="url"
        name="url"
        type="url"
        inputMode="url"
        placeholder="Paste the link to your LinkedIn post"
        maxLength={500}
        required
        readOnly={pending}
      />
      <button type="submit" className="btn" disabled={pending} aria-busy={pending}>
        {pending && <span className="spinner" aria-hidden="true" />}
        {pending ? 'Submitting…' : 'Submit post'}
      </button>
      {state?.error && (
        <p className={`err ${styles.formErr}`} role="alert">
          {state.error}
        </p>
      )}
    </form>
  );
}
