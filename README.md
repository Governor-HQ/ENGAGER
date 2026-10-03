# Engager

A small web app that helps a class coordinate LinkedIn engagement. Each student submits one LinkedIn post per day. They see their classmates' posts for the day and mark each one as engaged once they've liked or commented on it.

**Built by [Governor](https://github.com/Governor-HQ), Emmanuel Chiemerie Okennwa**

Built with Next.js 16 (App Router), Supabase (Postgres + Auth) and plain CSS.

## 1. Set up Supabase

1. Create a project at [supabase.com](https://supabase.com).
2. **Turn off email confirmation:** go to **Authentication → Sign In / Providers → Email** and switch **Confirm email** off. New accounts then work right away.
3. **Choose your timezone (optional but recommended):** open [`supabase/schema.sql`](supabase/schema.sql). At the top, change `'UTC'` in `app_today()` to your class's timezone, for example `'Africa/Lagos'` or `'America/New_York'`. This sets when "today" rolls over.
4. Go to **SQL Editor → New query**, paste the whole of `supabase/schema.sql`, and click **Run**.
5. Go to **Project Settings → API** and copy the **Project URL** and the **anon / public** key.

## 2. Run locally

```bash
cp .env.local.example .env.local   # then fill in the two values
npm install
npm run dev
```

Open http://localhost:3000.

## 3. Deploy to Vercel

1. Push this folder to a GitHub repo.
2. In Vercel, click **Add New → Project** and import the repo. Vercel detects Next.js automatically.
3. Add these environment variables:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
4. Click **Deploy**.

## How the rules are enforced (database level)

| Rule | Enforced by |
|---|---|
| One post per user per day | `UNIQUE (user_id, post_date)` on `posts`. RLS also requires `post_date = app_today()`, so nobody can backfill or pre-post other days. |
| Can't engage with your own post | A `BEFORE INSERT` trigger on `engagements`. A CHECK constraint can't read another table, so a trigger does the job. Triggers also apply to the service role. |
| Can't engage with the same post twice | `UNIQUE (post_id, user_id)` on `engagements` |
| Only LinkedIn links | A CHECK constraint on `posts.url` that requires `https://…linkedin.com/` or `https://lnkd.in/`. It also stops `javascript:` links from ever reaching other students' browsers. |
| Insert only your own rows | RLS `WITH CHECK (user_id = auth.uid())` (`id = auth.uid()` for profiles) |
| No editing or deleting | RLS is on and there are no UPDATE or DELETE policies, so both are denied. |

Profiles are created by a trigger on `auth.users` that uses the full name entered at signup. Because of this, a profile row exists even if the browser fails partway through signup.

## Project layout

```
app/
  layout.js, globals.css     root layout and all styles
  AuthForm.js, auth-actions.js   login/signup form and server actions (signup, login, logout)
  login/, signup/            auth pages
  dashboard/                 main page, submit form, engage button, server actions
lib/supabase/server.js       Supabase client for server components and actions
proxy.js                     refreshes the session and redirects between auth pages and the dashboard
supabase/schema.sql          tables, constraints, triggers and RLS (run once)
```
