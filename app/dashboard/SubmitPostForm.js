'use client';

import { useActionState } from 'react';
import { submitPost } from './actions';

export default function SubmitPostForm() {
  const [state, formAction, pending] = useActionState(submitPost, null);

  return (
    <form action={formAction} className="submit-form">
      <label htmlFor="url" className="sr-only">LinkedIn post URL</label>
      <input
        id="url"
        name="url"
        type="url"
        inputMode="url"
        placeholder="https://www.linkedin.com/posts/…"
        maxLength={500}
        required
      />
      <button type="submit" className="btn btn-primary" disabled={pending}>
        {pending ? 'Submitting…' : 'Submit'}
      </button>
      {state?.error && <p className="error full" role="alert">{state.error}</p>}
    </form>
  );
}
