'use client';

import { useActionState } from 'react';
import { markEngaged } from './actions';
import useSubmitOnce from './useSubmitOnce';

export default function EngageButton({ postId, engaged }) {
  const [state, formAction, pending] = useActionState(markEngaged, null);
  const onSubmit = useSubmitOnce(pending);

  const error = state?.error && <p className="error small" role="alert">{state.error}</p>;

  if (engaged) {
    return (
      <div className="engage-form">
        <button type="button" className="btn btn-engaged" disabled>
          Engaged ✓
        </button>
        {error}
      </div>
    );
  }

  return (
    <form action={formAction} onSubmit={onSubmit} className="engage-form">
      <input type="hidden" name="post_id" value={postId} />
      <button type="submit" className="btn btn-secondary" disabled={pending} aria-busy={pending}>
        {pending && <span className="spinner" aria-hidden="true" />}
        {pending ? 'Saving…' : 'Mark as engaged'}
      </button>
      {error}
    </form>
  );
}
