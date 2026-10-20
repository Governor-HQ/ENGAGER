import { headers } from 'next/headers';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { logout } from '../auth-actions';
import { isUuid } from './validate';
import { GroupRow, MemberRow, LockedRow } from './Rows';
import { NewClassroomForm, NewGroupForm } from './Forms';
import styles from './admin.module.css';

export const metadata = { title: 'Admin · Engager' };

function baseUrl(h) {
  const host = h.get('x-forwarded-host') || h.get('host') || '';
  const proto = host.startsWith('localhost') ? 'http' : 'https';
  return `${proto}://${host}`;
}

function plural(n, word) {
  return `${n} ${word}${n === 1 ? '' : 's'}`;
}

export default async function AdminPage({ searchParams }) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect('/login');

  const { data: isAdmin } = await supabase.rpc('is_admin');
  if (isAdmin !== true) redirect('/dashboard');

  const params = await searchParams;
  const rawGroup = Array.isArray(params?.group) ? params.group[0] : params?.group;
  const selectedId = isUuid(rawGroup) ? rawGroup : null;

  const [totals, invites, groups, classrooms, locked, members] = await Promise.all([
    supabase.rpc('group_totals'),
    supabase.from('group_invites').select('group_id, code'),
    supabase.from('groups').select('id, classroom_id, name'),
    supabase.from('classrooms').select('id, name').order('name'),
    supabase.rpc('admin_locked_accounts'),
    selectedId
      ? supabase.rpc('admin_group_members', { p_group_id: selectedId })
      : Promise.resolve({ data: null, error: null }),
  ]);

  const loadError = [totals, invites, groups, classrooms, locked, members].find((r) => r.error);
  if (loadError) console.error('admin page load failed:', loadError.error);

  const classroomList = classrooms.data || [];
  const groupRows = groups.data || [];
  const totalById = new Map((totals.data || []).map((t) => [t.group_id, t]));
  const codeById = new Map((invites.data || []).map((i) => [i.group_id, i.code]));
  const lockedList = locked.data || [];
  const memberList = members.data || [];
  const selected = selectedId ? groupRows.find((g) => g.id === selectedId) : null;

  const base = baseUrl(await headers());

  const groupsByClassroom = new Map();
  for (const g of groupRows) {
    const t = totalById.get(g.id);
    const entry = {
      id: g.id,
      name: g.name,
      members: Number(t?.member_count ?? 0),
      posts: Number(t?.post_count ?? 0),
      engagements: Number(t?.engagement_count ?? 0),
    };
    if (!groupsByClassroom.has(g.classroom_id)) groupsByClassroom.set(g.classroom_id, []);
    groupsByClassroom.get(g.classroom_id).push(entry);
  }
  for (const list of groupsByClassroom.values()) {
    list.sort((a, b) => a.name.localeCompare(b.name));
  }

  const classroomName = new Map(classroomList.map((c) => [c.id, c.name]));
  const otherGroups = selected
    ? groupRows
        .filter((g) => g.id !== selected.id)
        .map((g) => ({
          id: g.id,
          label:
            g.classroom_id === selected.classroom_id
              ? g.name
              : `${classroomName.get(g.classroom_id) || 'Classroom'}: ${g.name}`,
        }))
    : [];

  return (
    <>
      <header className={styles.band}>
        <div className={styles.inner}>
          <div className={styles.nav}>
            <span className={styles.wordmark}>Engager</span>
            <span className={styles.chip}>Admin</span>
            <span className={styles.spacer} />
            <form action={logout} className={styles.logoutForm}>
              <button type="submit" className={`link ${styles.onRed}`}>
                Log out
              </button>
            </form>
          </div>
          <h1 className={styles.title}>Admin</h1>
          <p className={styles.sub}>Counts and codes only. You cannot read posts.</p>
        </div>
      </header>

      <main className={styles.main}>
        {loadError && (
          <p className="err" role="alert">
            Some data could not be loaded. Reload the page, or check that the database migrations
            are applied.
          </p>
        )}

        {classroomList.length === 0 && (
          <section className={styles.card}>
            <p className={styles.empty}>No classrooms yet. Use New classroom to add one.</p>
          </section>
        )}

        {classroomList.map((c) => {
          const list = groupsByClassroom.get(c.id) || [];
          return (
            <section key={c.id} className={styles.card} aria-labelledby={`room-${c.id}`}>
              <div className={styles.cardHead}>
                <div className={styles.headLeft}>
                  <h2 id={`room-${c.id}`} className={styles.cardTitle}>
                    {c.name}
                  </h2>
                  <span className="count">{plural(list.length, 'group')}</span>
                </div>
                <NewGroupForm classrooms={classroomList} defaultId={c.id} />
              </div>
              {list.length === 0 ? (
                <p className={styles.empty}>No groups yet</p>
              ) : (
                <table className={styles.table}>
                  <thead>
                    <tr>
                      <th scope="col">Group</th>
                      <th scope="col">Members</th>
                      <th scope="col">Posts</th>
                      <th scope="col">Engagements</th>
                      <th scope="col">Code</th>
                      <th scope="col">
                        <span className="sr-only">Actions</span>
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    {list.map((g) => {
                      const code = codeById.get(g.id);
                      return (
                        <GroupRow
                          key={g.id}
                          group={g}
                          code={code}
                          joinUrl={code ? `${base}/join/${code}` : ''}
                          manageHref={`?group=${g.id}#members`}
                          selected={g.id === selectedId}
                        />
                      );
                    })}
                  </tbody>
                </table>
              )}
            </section>
          );
        })}

        <section className={`${styles.card} ${styles.cardHead}`} aria-label="Add a classroom">
          <span className={styles.hint}>Need another cohort or class?</span>
          <NewClassroomForm />
        </section>

        <section id="members" className={styles.card} aria-labelledby="members-title">
          <div className={styles.cardHead}>
            <h2 id="members-title" className={styles.cardTitle}>
              {selected ? `${selected.name} members` : 'Members'}
            </h2>
            {selected && <span className="count">{memberList.length}</span>}
          </div>
          {!selected ? (
            <p className={styles.empty}>Pick a group above and press Manage to see its members</p>
          ) : memberList.length === 0 ? (
            <p className={styles.empty}>No members in this group yet</p>
          ) : (
            <table className={styles.table}>
              <thead>
                <tr>
                  <th scope="col">Name</th>
                  <th scope="col">Joined</th>
                  <th scope="col">
                    <span className="sr-only">Actions</span>
                  </th>
                </tr>
              </thead>
              <tbody>
                {memberList.map((m) => (
                  <MemberRow
                    key={m.user_id}
                    member={m}
                    groupId={selected.id}
                    groupName={selected.name}
                    otherGroups={otherGroups}
                  />
                ))}
              </tbody>
            </table>
          )}
        </section>

        <section className={styles.card} aria-labelledby="locked-title">
          <div className={styles.cardHead}>
            <h2 id="locked-title" className={styles.cardTitle}>
              Locked accounts
            </h2>
            <span className="count">{lockedList.length}</span>
          </div>
          {lockedList.length === 0 ? (
            <p className={styles.empty}>No locked accounts</p>
          ) : (
            <table className={styles.table}>
              <thead>
                <tr>
                  <th scope="col">Name</th>
                  <th scope="col">Wrong tries</th>
                  <th scope="col">
                    <span className="sr-only">Actions</span>
                  </th>
                </tr>
              </thead>
              <tbody>
                {lockedList.map((a) => (
                  <LockedRow key={a.user_id} account={a} />
                ))}
              </tbody>
            </table>
          )}
        </section>
      </main>
    </>
  );
}
