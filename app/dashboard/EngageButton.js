'use client';

import { useActionState } from 'react';
import { markEngaged } from './actions';
import useSubmitOnce from './useSubmitOnce';
import styles from './dashboard.module.css';

export default function EngageButton({ postId }) {
  const [state, formAction, pending] = useActionState(markEngaged, null);
  const onSubmit = useSubmitOnce(pending);

  return (
    <form action={formAction} onSubmit={onSubmit} className={styles.engage}>
      <input type="hidden" name="post_id" value={postId} />
      <button type="submit" className="btn" disabled={pending} aria-busy={pending}>
        {pending && <span className="spinner" aria-hidden="true" />}
        {pending ? 'Saving…' : 'Mark as engaged'}
      </button>
      {state?.error && <p className="err" role="alert">{state.error}</p>}
    </form>
  );
}
