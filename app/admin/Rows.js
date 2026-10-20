'use client';

import { useCallback, useState } from 'react';
import ConfirmBar from './ConfirmBar';
import CopyLink from './CopyLink';
import { moveMember, removeMember, rotateCode, unlockAccount } from './actions';
import styles from './admin.module.css';

function useOpen() {
  const [open, setOpen] = useState(null);
  const close = useCallback(() => setOpen(null), []);
  return [open, setOpen, close];
}

// One row of a classroom's group table. The confirm bar opens in a second
// full-width row so it reads like the mockup.
export function GroupRow({ group, code, joinUrl, manageHref, selected }) {
  const [open, setOpen, close] = useOpen();
  return (
    <>
      <tr className={selected ? styles.selectedRow : undefined}>
        <th scope="row" data-label="Group" className={styles.nameCell}>
          {group.name}
        </th>
        <td data-label="Members">{group.members}</td>
        <td data-label="Posts">{group.posts}</td>
        <td data-label="Engagements">{group.engagements}</td>
        <td data-label="Code">
          {code ? <span className={styles.code}>{code}</span> : <span className="small">None</span>}
        </td>
        <td className={styles.actCell}>
          <div className={styles.acts}>
            <a className="btn btn-ghost" href={manageHref} aria-label={`Manage ${group.name}`}>
              Manage
            </a>
            {code && <CopyLink url={joinUrl} label={group.name} />}
            <button
              type="button"
              className="btn btn-ghost"
              onClick={() => setOpen('rotate')}
              aria-expanded={open === 'rotate'}
            >
              Rotate code
            </button>
          </div>
        </td>
      </tr>
      {open === 'rotate' && (
        <tr className={styles.confirmRow}>
          <td colSpan={6}>
            <ConfirmBar
              action={rotateCode}
              hidden={{ group_id: group.id }}
              confirmLabel="Yes, rotate code"
              onClose={close}
            >
              Make a new code for <b>{group.name}</b>? The old code stops working at once.
            </ConfirmBar>
          </td>
        </tr>
      )}
    </>
  );
}

const dateFormat = new Intl.DateTimeFormat('en-GB', {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
  timeZone: 'Africa/Lagos',
});

// otherGroups: [{ id, label }] for every readable group except this one.
export function MemberRow({ member, groupId, groupName, otherGroups }) {
  const [open, setOpen, close] = useOpen();
  const [target, setTarget] = useState('');
  const name = member.full_name || 'Unnamed';
  const joined = member.joined_at ? dateFormat.format(new Date(member.joined_at)) : '';
  return (
    <>
      <tr>
        <th scope="row" data-label="Name" className={styles.nameCell}>
          {name}
        </th>
        <td data-label="Joined">{joined}</td>
        <td className={styles.actCell}>
          <div className={styles.acts}>
            <button
              type="button"
              className="btn btn-ghost"
              onClick={() => setOpen('move')}
              aria-expanded={open === 'move'}
              aria-label={`Move ${name}`}
              disabled={otherGroups.length === 0}
              title={otherGroups.length === 0 ? 'There is no other group to move them to.' : undefined}
            >
              Move
            </button>
            <button
              type="button"
              className="btn btn-ghost"
              onClick={() => setOpen('remove')}
              aria-expanded={open === 'remove'}
              aria-label={`Remove ${name}`}
            >
              Remove
            </button>
          </div>
        </td>
      </tr>
      {open === 'move' && (
        <tr className={styles.confirmRow}>
          <td colSpan={3}>
            <ConfirmBar
              action={moveMember}
              hidden={{ user_id: member.user_id, from_group_id: groupId, to_group_id: target }}
              confirmLabel="Yes, move"
              onClose={close}
            >
              Move <b>{name}</b> from {groupName} to{' '}
              <select
                className={styles.select}
                value={target}
                onChange={(e) => setTarget(e.target.value)}
                aria-label="Group to move to"
                required
              >
                <option value="">Pick a group</option>
                {otherGroups.map((g) => (
                  <option key={g.id} value={g.id}>
                    {g.label}
                  </option>
                ))}
              </select>
              ? Their posts stay.
            </ConfirmBar>
          </td>
        </tr>
      )}
      {open === 'remove' && (
        <tr className={styles.confirmRow}>
          <td colSpan={3}>
            <ConfirmBar
              action={removeMember}
              hidden={{ user_id: member.user_id, group_id: groupId }}
              confirmLabel="Yes, remove"
              onClose={close}
            >
              Remove <b>{name}</b> from {groupName}? Their posts and other groups stay.
            </ConfirmBar>
          </td>
        </tr>
      )}
    </>
  );
}

export function LockedRow({ account }) {
  const [open, setOpen, close] = useOpen();
  const name = account.full_name || 'Unnamed';
  return (
    <>
      <tr>
        <th scope="row" data-label="Name" className={styles.nameCell}>
          {name}
        </th>
        <td data-label="Wrong tries">{Number(account.failed_count)}</td>
        <td className={styles.actCell}>
          <div className={styles.acts}>
            <button
              type="button"
              className="btn btn-ghost"
              onClick={() => setOpen('unlock')}
              aria-expanded={open === 'unlock'}
              aria-label={`Unlock ${name}`}
            >
              Unlock
            </button>
          </div>
        </td>
      </tr>
      {open === 'unlock' && (
        <tr className={styles.confirmRow}>
          <td colSpan={3}>
            <ConfirmBar
              action={unlockAccount}
              hidden={{ user_id: account.user_id }}
              confirmLabel="Yes, unlock"
              onClose={close}
            >
              Unlock <b>{name}</b>? They can try joining again.
            </ConfirmBar>
          </td>
        </tr>
      )}
    </>
  );
}
