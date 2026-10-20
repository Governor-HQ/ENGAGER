import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { HELP_URL } from '@/lib/help';
import { logout } from '../auth-actions';
import SubmitPostForm from './SubmitPostForm';
import EngageButton from './EngageButton';
import styles from './dashboard.module.css';

export const metadata = { title: 'Dashboard · Engager' };

// Must match the timezone used by app_today() in supabase/schema.sql.
const CLASS_TIME_ZONE = 'Africa/Lagos';

// post_date values are plain 'YYYY-MM-DD' strings; do all date math in UTC
// so the server's timezone can't shift a date by one day.
function shiftDate(isoDate, days) {
  const d = new Date(`${isoDate}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

const dateFormat = new Intl.DateTimeFormat('en-US', {
  month: 'short',
  day: 'numeric',
  year: 'numeric',
  timeZone: 'UTC',
});

const longDateFormat = new Intl.DateTimeFormat('en-US', {
  weekday: 'long',
  month: 'long',
  day: 'numeric',
  timeZone: 'UTC',
});

const hourFormat = new Intl.DateTimeFormat('en-US', {
  hour: 'numeric',
  hourCycle: 'h23',
  timeZone: CLASS_TIME_ZONE,
});

function dateHeading(isoDate, today) {
  if (isoDate === today) return 'Today';
  if (isoDate === shiftDate(today, -1)) return 'Yesterday';
  return dateFormat.format(new Date(`${isoDate}T00:00:00Z`));
}

// Posts arrive sorted newest date first, so groups stay in that order.
function groupByDate(posts) {
  const groups = [];
  for (const post of posts) {
    const last = groups[groups.length - 1];
    if (last && last.date === post.post_date) last.posts.push(post);
    else groups.push({ date: post.post_date, posts: [post] });
  }
  return groups;
}

function greetingFor(date) {
  const hour = Number(hourFormat.format(date));
  if (hour >= 18) return 'Good evening';
  if (hour >= 12) return 'Good afternoon';
  return 'Good morning';
}

function initials(name) {
  const words = String(name || '').trim().split(/\s+/).filter(Boolean);
  if (words.length === 0) return '?';
  const letters = words.length > 1 ? words[0][0] + words[1][0] : words[0][0];
  return letters.toUpperCase();
}

const TONES = [styles.toneRed, styles.toneOrange, styles.toneSolid, styles.toneLine];

function toneFor(name) {
  let sum = 0;
  for (let i = 0; i < name.length; i += 1) sum += name.charCodeAt(i);
  return TONES[sum % TONES.length];
}

// Short, readable version of a post link, e.g. "linkedin.com/posts/abc…".
function shortUrl(url) {
  let text = url;
  try {
    const parsed = new URL(url);
    const host = parsed.hostname.replace(/^www\./, '');
    text = parsed.pathname === '/' ? host : host + parsed.pathname;
  } catch {
    text = url;
  }
  return text.length > 48 ? `${text.slice(0, 47)}…` : text;
}

function classmateName(post) {
  return post.profiles?.full_name || 'Classmate';
}

// "A", "A and B", "A, B and C".
function listNames(names) {
  if (names.length <= 1) return names.join('');
  return `${names.slice(0, -1).join(', ')} and ${names[names.length - 1]}`;
}

function GroupTiles({ groups }) {
  return (
    <section className={styles.card} aria-labelledby="your-groups-title">
      <div className={styles.postHead}>
        <div>
          <div className="eyebrow">Your groups</div>
          <h2 id="your-groups-title" className={styles.cardTitle}>
            Where you post
          </h2>
        </div>
        <Link className="link" href="/join">
          Join another group
        </Link>
      </div>
      <ul role="list" className={styles.groupTiles}>
        {groups.map((g) => (
          <li key={g.group_id} className={styles.tile}>
            <h3 className={styles.tileName}>{g.group_name}</h3>
            <p className={styles.tileClass}>{g.classroom_name}</p>
            <dl className={styles.tileStats}>
              <div>
                <dt>members</dt>
                <dd>{g.member_count}</dd>
              </div>
              <div>
                <dt>posts</dt>
                <dd>{g.post_count}</dd>
              </div>
              <div>
                <dt>engagements</dt>
                <dd>{g.engagement_count}</dd>
              </div>
            </dl>
          </li>
        ))}
      </ul>
    </section>
  );
}

function ProgressRing({ engaged, total }) {
  const circumference = 2 * Math.PI * 42;
  const fraction = total ? engaged / total : 0;
  return (
    <div className={styles.ring} role="img" aria-label={`${engaged} of ${total} posts engaged`}>
      <svg viewBox="0 0 100 100" aria-hidden="true">
        <circle cx="50" cy="50" r="42" fill="none" strokeWidth="9" stroke="rgba(255,255,255,.25)" />
        {engaged > 0 && (
          <circle
            cx="50"
            cy="50"
            r="42"
            fill="none"
            strokeWidth="9"
            stroke="#fff"
            strokeLinecap="round"
            strokeDasharray={circumference}
            strokeDashoffset={circumference * (1 - fraction)}
          />
        )}
      </svg>
      <span className={styles.ringText} aria-hidden="true">
        <span>
          {engaged}/{total}
        </span>
        <span className={styles.ringLabel}>engaged</span>
      </span>
    </div>
  );
}

function PostItem({ post }) {
  const name = classmateName(post);
  return (
    <li className={styles.item}>
      <span className={`${styles.itemAv} ${toneFor(name)}`} aria-hidden="true">
        {initials(name)}
      </span>
      <div className={styles.itemBody}>
        <span className={styles.itemName}>{name}</span>
        <span className={styles.meta}>{shortUrl(post.url)}</span>
      </div>
      <div className={styles.acts}>
        <a className="btn btn-ghost" href={post.url} target="_blank" rel="noopener noreferrer">
          Open post
        </a>
        <EngageButton postId={post.id} />
      </div>
    </li>
  );
}

function DateGroups({ posts, today }) {
  return groupByDate(posts).map((group) => (
    <div key={group.date}>
      <h3 className={`eyebrow ${styles.day}`}>{dateHeading(group.date, today)}</h3>
      <ul className={styles.list}>
        {group.posts.map((post) => (
          <PostItem key={post.id} post={post} />
        ))}
      </ul>
    </div>
  ));
}

export default async function DashboardPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect('/login');

  // "Today" comes from the database so it matches the one-post-per-day rule.
  const { data: today, error: todayError } = await supabase.rpc('app_today');
  if (todayError) throw new Error('Database not set up. Run supabase/schema.sql first.');

  const [
    profile,
    myPost,
    feed,
    myEngagements,
    postCount,
    givenCount,
    receivedCount,
    adminCheck,
    groupTotals,
  ] = await Promise.all([
      supabase.from('profiles').select('full_name').eq('id', user.id).maybeSingle(),
      supabase
        .from('posts')
        .select('url')
        .eq('user_id', user.id)
        .eq('post_date', today)
        .maybeSingle(),
      supabase
        .from('posts')
        .select('id, url, post_date, profiles(full_name)')
        .neq('user_id', user.id)
        .order('post_date', { ascending: false })
        .order('created_at', { ascending: false }),
      supabase.from('engagements').select('post_id').eq('user_id', user.id),
      supabase.from('posts').select('id', { count: 'exact', head: true }).eq('user_id', user.id),
      supabase
        .from('engagements')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', user.id),
      supabase
        .from('engagements')
        .select('id, posts!inner(user_id)', { count: 'exact', head: true })
        .eq('posts.user_id', user.id),
      supabase.rpc('is_admin'),
      // For a member: their own groups only. Counts, never names or rankings.
      supabase.rpc('group_totals'),
    ]);

  if (adminCheck.error || groupTotals.error) {
    throw new Error('Database not up to date. Apply the migrations in supabase/migrations first.');
  }
  // The admin account has its own screen and never joins a group.
  if (adminCheck.data === true) redirect('/admin');

  const fullName = profile.data?.full_name || user.email;
  const firstName = profile.data?.full_name?.trim().split(/\s+/)[0] || 'there';
  const posts = feed.data || [];
  const engagedIds = new Set((myEngagements.data || []).map((e) => e.post_id));
  const waiting = posts.filter((p) => !engagedIds.has(p.id));
  const done = posts.filter((p) => engagedIds.has(p.id));
  const groups = groupTotals.data || [];
  const inGroup = groups.length > 0;
  const isNewUser = (postCount.count ?? 0) === 0 && (givenCount.count ?? 0) === 0;
  const todayLabel = longDateFormat.format(new Date(`${today}T00:00:00Z`));
  const greeting = greetingFor(new Date());

  return (
    <>
      <header className={styles.band}>
        <div className={styles.inner}>
          <div className={styles.nav}>
            <span className={styles.wordmark}>Engager</span>
            <span className={styles.spacer} />
            <a
              href={HELP_URL}
              target="_blank"
              rel="noopener noreferrer"
              className={`link ${styles.onRed}`}
            >
              Need help?
            </a>
            <span className={styles.who}>
              <span className={styles.av} aria-hidden="true">
                {initials(fullName)}
              </span>
              <span className={styles.whoName} title={fullName}>
                {fullName}
              </span>
            </span>
            <form action={logout} className={styles.logoutForm}>
              <button type="submit" className={`link ${styles.onRed}`}>
                Log out
              </button>
            </form>
          </div>

          <div className={styles.hero}>
            <div className={styles.heroText}>
              <p className={styles.date}>{todayLabel}</p>
              <h1 className={styles.greeting}>
                {greeting}, {firstName}
              </h1>
              <p className={styles.sub}>
                {!inGroup
                  ? 'You are not in a group yet.'
                  : posts.length > 0
                    ? `You've engaged with ${done.length} of ${posts.length} classmates' posts.`
                    : "No classmates' posts yet."}
              </p>
            </div>
            {inGroup && <ProgressRing engaged={done.length} total={posts.length} />}
          </div>
        </div>
      </header>

      <main className={styles.main}>
        {!inGroup ? (
          <section className={`${styles.card} ${styles.noGroup}`} aria-labelledby="no-group-title">
            <div className="eyebrow">One step left</div>
            <h2 id="no-group-title" className={styles.cardTitle}>
              Join your group to start
            </h2>
            <p className={`small ${styles.noGroupText}`}>
              You see posts and can post only after you join a group. Ask your group chat for the
              invite link or code.
            </p>
            <Link className="btn" href="/join">
              Enter an invite code
            </Link>
          </section>
        ) : (
          <>
        <GroupTiles groups={groups} />

        {isNewUser && (
          <section className={styles.card} aria-labelledby="how-it-works-title">
            <h2 id="how-it-works-title" className={styles.cardTitle}>
              How it works
            </h2>
            <ol role="list" className={styles.steps}>
              <li>
                <span className={styles.stepNum} aria-hidden="true">1</span>
                <div>
                  <b className={styles.stepTitle}>Post your link</b>
                  <span className={styles.stepText}>Add one LinkedIn post a day.</span>
                </div>
              </li>
              <li>
                <span className={styles.stepNum} aria-hidden="true">2</span>
                <div>
                  <b className={styles.stepTitle}>Engage with others</b>
                  <span className={styles.stepText}>
                    Open a classmate&apos;s post. Like, comment, share.
                  </span>
                </div>
              </li>
              <li>
                <span className={styles.stepNum} aria-hidden="true">3</span>
                <div>
                  <b className={styles.stepTitle}>Mark it done</b>
                  <span className={styles.stepText}>Come back and tap Mark as engaged.</span>
                </div>
              </li>
            </ol>
          </section>
        )}

        <section className={styles.card} aria-labelledby="your-post-title">
          <div className={styles.postHead}>
            <div>
              <div className="eyebrow">Today</div>
              <h2 id="your-post-title" className={styles.cardTitle}>
                Your post
              </h2>
            </div>
            <div className={styles.mine}>
              <span>
                Your posts <b>{postCount.count ?? 0}</b>
              </span>
              <span>
                Engagements received <b>{receivedCount.count ?? 0}</b>
              </span>
            </div>
          </div>
          {myPost.data ? (
            <div className={styles.posted}>
              <span className={styles.tick} aria-hidden="true">✓</span>
              <div className={styles.postedText}>
                You posted today.
                <span className={styles.postedUrl}>
                  <a href={myPost.data.url} target="_blank" rel="noopener noreferrer">
                    {myPost.data.url}
                  </a>
                </span>
              </div>
            </div>
          ) : (
            <SubmitPostForm />
          )}
          <p className={`small ${styles.seenBy}`}>
            Your post is seen by everyone in {listNames(groups.map((g) => g.group_name))}.
          </p>
        </section>

        {posts.length === 0 ? (
          <p className={styles.boxed}>No posts from classmates yet. Check back later.</p>
        ) : (
          <>
            <section className={styles.feed} aria-labelledby="waiting-title">
              <div className={styles.secHead}>
                <h2 id="waiting-title" className={styles.secTitle}>
                  Waiting for you
                </h2>
                <span className="count">{waiting.length}</span>
              </div>
              {waiting.length === 0 ? (
                <div className={styles.caught}>
                  <div className={styles.bigTick} aria-hidden="true">✓</div>
                  <h3 className={styles.caughtTitle}>All caught up. Nice work.</h3>
                  <p className="small">New posts show up here as your classmates add them.</p>
                </div>
              ) : (
                <DateGroups posts={waiting} today={today} />
              )}
            </section>

            {done.length > 0 && (
              <details className={styles.done}>
                <summary>
                  Already engaged <span className="count">{done.length}</span>
                </summary>
                <ul className={styles.doneList}>
                  {done.map((post) => {
                    const name = classmateName(post);
                    return (
                      <li key={post.id}>
                        <span className={styles.doneName}>
                          <span className={styles.doneTick} aria-hidden="true">✓</span>
                          {name}
                        </span>
                        <span className={styles.doneMeta}>
                          {dateHeading(post.post_date, today)}
                          <a
                            className="link"
                            href={post.url}
                            target="_blank"
                            rel="noopener noreferrer"
                            aria-label={`Open ${name}'s post`}
                          >
                            Open
                          </a>
                        </span>
                      </li>
                    );
                  })}
                </ul>
              </details>
            )}
          </>
        )}
          </>
        )}
      </main>
    </>
  );
}
