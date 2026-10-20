'use client';

import { useActionState, useEffect } from 'react';
import useSubmitOnce from '../dashboard/useSubmitOnce';
import styles from './admin.module.css';

// The red confirm step. Nothing runs until the person presses the Yes button,
// which is the only thing that submits the server action.
export default function ConfirmBar({ action, hidden, confirmLabel, onClose, children }) {
  const [state, formAction, pending] = useActionState(action, null);
  const onSubmit = useSubmitOnce(pending);

  useEffect(() => {
    if (state?.ok) onClose();
  }, [state, onClose]);

  return (
    <form action={formAction} onSubmit={onSubmit} className={styles.confirm} role="alert">
      {Object.entries(hidden).map(([name, value]) => (
        <input key={name} type="hidden" name={name} value={value} />
      ))}
      <p className={styles.confirmText}>{children}</p>
      <div className={styles.confirmActs}>
        <button type="submit" className="btn" disabled={pending} aria-busy={pending}>
          {pending && <span className="spinner" aria-hidden="true" />}
          {pending ? 'Working…' : confirmLabel}
        </button>
        <button type="button" className="btn btn-ghost" onClick={onClose} disabled={pending}>
          Cancel
        </button>
      </div>
      {state?.error && <p className={`err ${styles.confirmErr}`}>{state.error}</p>}
    </form>
  );
}
