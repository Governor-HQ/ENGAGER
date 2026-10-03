import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { logout } from '../auth-actions';
import SubmitPostForm from './SubmitPostForm';
import EngageButton from './EngageButton';

export const metadata = { title: 'Dashboard · Engager' };

export default async function DashboardPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect('/login');

  // "Today" comes from the database so it matches the one-post-per-day rule.
  const { data: today, error: todayError } = await supabase.rpc('app_today');
  if (todayError) throw new Error('Database not set up. Run supabase/schema.sql first.');

  const [profile, myPost, feed, myEngagedToday, postCount, givenCount, receivedCount] =
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
        .select('id, url, profiles(full_name)')
        .eq('post_date', today)
        .neq('user_id', user.id)
        .order('created_at', { ascending: true }),
      supabase
        .from('engagements')
        .select('post_id, posts!inner(post_date)')
        .eq('user_id', user.id)
        .eq('posts.post_date', today),
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
  const engagedIds = new Set((myEngagedToday.data || []).map((e) => e.post_id));
  const remaining = posts.filter((p) => !engagedIds.has(p.id)).length;

  return (
    <>
      <header className="topnav">
        <div className="container topnav-inner">
          <span className="brand">Engager</span>
          <div className="topnav-right">
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
            <h2>Classmates&apos; posts today</h2>
            {posts.length > 0 && (
              <span className="muted small">
                {remaining === 0 ? 'All caught up 🎉' : `${remaining} left to engage`}
              </span>
            )}
          </div>

          {posts.length === 0 ? (
            <p className="empty">No posts from classmates yet today. Check back later.</p>
          ) : (
            <ul className="feed">
              {posts.map((post) => (
                <li key={post.id} className="card">
                  <span className="card-name">{post.profiles?.full_name || 'Classmate'}</span>
                  <div className="card-actions">
                    <a
                      href={post.url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="btn btn-outline"
                    >
                      Open on LinkedIn ↗
                    </a>
                    <EngageButton postId={post.id} engaged={engagedIds.has(post.id)} />
                  </div>
                </li>
              ))}
            </ul>
          )}
        </section>
      </main>
    </>
  );
}
