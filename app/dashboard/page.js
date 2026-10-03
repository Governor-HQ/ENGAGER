import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { HELP_URL } from '@/lib/help';
import { logout } from '../auth-actions';
import SubmitPostForm from './SubmitPostForm';
import EngageButton from './EngageButton';

export const metadata = { title: 'Dashboard · Engager' };

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

function PostCard({ post, engaged }) {
  return (
    <li className="card">
      <span className="card-name">{post.profiles?.full_name || 'Classmate'}</span>
      <div className="card-actions">
        <a href={post.url} target="_blank" rel="noopener noreferrer" className="btn btn-outline">
          Open on LinkedIn ↗
        </a>
        <EngageButton postId={post.id} engaged={engaged} />
      </div>
    </li>
  );
}

function DateGroups({ posts, today, engaged }) {
  return groupByDate(posts).map((group) => (
    <div key={group.date} className="date-group">
      <h4 className="date-heading">{dateHeading(group.date, today)}</h4>
      <ul className="feed">
        {group.posts.map((post) => (
          <PostCard key={post.id} post={post} engaged={engaged} />
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

  const [profile, myPost, feed, myEngagements, postCount, givenCount, receivedCount] =
    await Promise.all([
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
    ]);

  const fullName = profile.data?.full_name || user.email;
  const posts = feed.data || [];
  const engagedIds = new Set((myEngagements.data || []).map((e) => e.post_id));
  const waiting = posts.filter((p) => !engagedIds.has(p.id));
  const done = posts.filter((p) => engagedIds.has(p.id));
  const progress = posts.length > 0 ? Math.round((done.length / posts.length) * 100) : 0;
  const isNewUser = (postCount.count ?? 0) === 0 && (givenCount.count ?? 0) === 0;

  return (
    <>
      <header className="topnav">
        <div className="container topnav-inner">
          <span className="brand">Engager</span>
          <div className="topnav-right">
            <a href={HELP_URL} target="_blank" rel="noopener noreferrer" className="help-link">
              Need help?
            </a>
            <span className="user-name" title={fullName}>{fullName}</span>
            <form action={logout}>
              <button type="submit" className="btn btn-ghost">Log out</button>
            </form>
          </div>
        </div>
      </header>

      <main className="container dashboard">
        <section className="stats" aria-label="Your stats">
          <div className="stat">
            <span className="stat-value">{postCount.count ?? 0}</span>
            <span className="stat-label">Your posts</span>
          </div>
          <div className="stat">
            <span className="stat-value">{givenCount.count ?? 0}</span>
            <span className="stat-label">Engagements given</span>
          </div>
          <div className="stat">
            <span className="stat-value">{receivedCount.count ?? 0}</span>
            <span className="stat-label">Engagements received</span>
          </div>
        </section>

        {isNewUser && (
          <section className="how-it-works" aria-labelledby="how-it-works-title">
            <h2 id="how-it-works-title">How it works</h2>
            <ol>
              <li>Post on LinkedIn, then paste your link here. One post per day.</li>
              <li>Open your classmates&apos; posts and like or comment on them.</li>
              <li>Come back and tap &quot;Mark as engaged&quot; so it counts.</li>
            </ol>
          </section>
        )}

        <section className="panel">
          <h2>Today&apos;s post</h2>
          {myPost.data ? (
            <div className="submitted">
              <span className="badge">Submitted ✓</span>
              <a
                href={myPost.data.url}
                target="_blank"
                rel="noopener noreferrer"
                className="submitted-url"
              >
                {myPost.data.url}
              </a>
            </div>
          ) : (
            <>
              <p className="muted small">
                Paste the link to your LinkedIn post for today. One post per day.
              </p>
              <SubmitPostForm />
            </>
          )}
        </section>

        <section>
          <div className="feed-header">
            <h2>Classmates&apos; posts</h2>
          </div>

          {posts.length === 0 ? (
            <p className="empty">No posts from classmates yet. Check back later.</p>
          ) : (
            <>
              <div className="progress-block">
                <p className="muted small" id="engage-progress-label">
                  You&apos;ve engaged with {done.length} of {posts.length} classmates&apos; posts
                </p>
                <div
                  className="progress-track"
                  role="progressbar"
                  aria-labelledby="engage-progress-label"
                  aria-valuemin={0}
                  aria-valuemax={posts.length}
                  aria-valuenow={done.length}
                >
                  <div className="progress-fill" style={{ width: `${progress}%` }} />
                </div>
              </div>

              <div>
                <h3 className="section-title">Waiting for you ({waiting.length})</h3>
                {waiting.length === 0 ? (
                  <p className="caught-up">All caught up. Nice work.</p>
                ) : (
                  <DateGroups posts={waiting} today={today} engaged={false} />
                )}
              </div>

              {done.length > 0 && (
                <details className="engaged-details">
                  <summary>Already engaged ({done.length})</summary>
                  <div className="engaged-body">
                    <DateGroups posts={done} today={today} engaged />
                  </div>
                </details>
              )}
            </>
          )}
        </section>
      </main>
    </>
  );
}
