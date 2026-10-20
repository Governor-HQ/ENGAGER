'use client';

import { useActionState, useEffect, useRef, useState } from 'react';
import useSubmitOnce from '../dashboard/useSubmitOnce';
import { createClassroom, createGroup } from './actions';
import styles from './admin.module.css';

function SubmitLabel({ pending, idle }) {
  return (
    <>
      {pending && <span className="spinner" aria-hidden="true" />}
      {pending ? 'Saving…' : idle}
    </>
  );
}

// Small inline form: a button that reveals a name field.
export function NewClassroomForm() {
  const [open, setOpen] = useState(false);
  const [state, formAction, pending] = useActionState(createClassroom, null);
  const onSubmit = useSubmitOnce(pending);

  useEffect(() => {
    if (state?.ok) setOpen(false);
  }, [state]);

  if (!open) {
    return (
      <button type="button" className="btn btn-ghost" onClick={() => setOpen(true)}>
        New classroom
      </button>
    );
  }
  return (
    <form action={formAction} onSubmit={onSubmit} className={styles.inlineForm}>
      <label className="sr-only" htmlFor="new-classroom-name">
        Classroom name
      </label>
      <input
        id="new-classroom-name"
        type="text"
        name="name"
        placeholder="Classroom name"
        maxLength={80}
        required
        autoFocus
      />
      <button type="submit" className="btn" disabled={pending} aria-busy={pending}>
        <SubmitLabel pending={pending} idle="Add classroom" />
      </button>
      <button type="button" className="btn btn-ghost" onClick={() => setOpen(false)}>
        Cancel
      </button>
      {state?.error && <p className={`err ${styles.formErr}`} role="alert">{state.error}</p>}
    </form>
  );
}

// classrooms: [{ id, name }]. defaultId preselects the card's own classroom.
export function NewGroupForm({ classrooms, defaultId }) {
  const [open, setOpen] = useState(false);
  const [state, formAction, pending] = useActionState(createGroup, null);
  const onSubmit = useSubmitOnce(pending);
  const formRef = useRef(null);

  useEffect(() => {
    if (state?.ok) {
      formRef.current?.reset();
      setOpen(false);
    }
  }, [state]);

  if (!open) {
    return (
      <button type="button" className="btn" onClick={() => setOpen(true)}>
        New group
      </button>
    );
  }
  return (
    <form action={formAction} onSubmit={onSubmit} ref={formRef} className={styles.inlineForm}>
      <label className="sr-only" htmlFor={`new-group-classroom-${defaultId}`}>
        Classroom
      </label>
      <select
        id={`new-group-classroom-${defaultId}`}
        name="classroom_id"
        defaultValue={defaultId}
        className={styles.select}
      >
        {classrooms.map((c) => (
          <option key={c.id} value={c.id}>
            {c.name}
          </option>
        ))}
      </select>
      <label className="sr-only" htmlFor={`new-group-name-${defaultId}`}>
        Group name
      </label>
      <input
        id={`new-group-name-${defaultId}`}
        type="text"
        name="name"
        placeholder="Group name"
        maxLength={80}
        required
        autoFocus
      />
      <button type="submit" className="btn" disabled={pending} aria-busy={pending}>
        <SubmitLabel pending={pending} idle="Add group" />
      </button>
      <button type="button" className="btn btn-ghost" onClick={() => setOpen(false)}>
        Cancel
      </button>
      {state?.error && <p className={`err ${styles.formErr}`} role="alert">{state.error}</p>}
    </form>
  );
}
