'use client';

import { useActionState } from 'react';
import { submitPost } from './actions';
import useSubmitOnce from './useSubmitOnce';

export default function SubmitPostForm() {
  const [state, formAction, pending] = useActionState(submitPost, null);
  const onSubmit = useSubmitOnce(pending);

  return (
    <form action={formAction} onSubmit={onSubmit} className="submit-form">
      <label htmlFor="url" className="sr-only">LinkedIn post URL</label>
      <input
        id="url"
        name="url"
        type="url"
        inputMode="url"
        placeholder="https://www.linkedin.com/posts/…"
        maxLength={500}
        required
        readOnly={pending}
      />
      <button type="submit" className="btn btn-primary" disabled={pending} aria-busy={pending}>
        {pending && <span className="spinner" aria-hidden="true" />}
        {pending ? 'Submitting…' : 'Submit'}
      </button>
      {state?.error && <p className="error full" role="alert">{state.error}</p>}
    </form>
  );
}
