'use client';

import { useActionState } from 'react';
import { markEngaged } from './actions';

export default function EngageButton({ postId, engaged }) {
  const [state, formAction, pending] = useActionState(markEngaged, null);

  if (engaged) {
    return (
      <button type="button" className="btn btn-engaged" disabled>
        Engaged ✓
      </button>
    );
  }

  return (
    <form action={formAction} className="engage-form">
      <input type="hidden" name="post_id" value={postId} />
      <button type="submit" className="btn btn-secondary" disabled={pending}>
        {pending ? 'Saving…' : 'Mark as engaged'}
      </button>
      {state?.error && <p className="error small" role="alert">{state.error}</p>}
    </form>
  );
}
