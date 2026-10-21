# ENGAGER release plan for Stage 2 (groups)

Written 21 Oct 2026 for branch `stage2-groups`. Read only: nothing here has been run against the real database or the live site. Steps that only Governor can do are marked (Governor).

## The short answers

**Between the migration and the new deploy, does the live app keep working for existing users?**
Yes for the database side. Right after the migration, the same queries the live dashboard runs (feed with author names, own profile, own engagements, engagements received, post count, marking a post engaged, submitting today's post) returned the same results for an existing user in the throwaway test database. This is test run 5, `supabase/db-tests/release_gap.test.sql`, 16 checks, PostgreSQL 16.15. It copies the query shapes as SQL. It did not run the live Next.js app or the real Supabase API, so the translation through the API is not verified.

**What happens to someone who signs up in that gap?**
Verified in the same test run: sign up itself works and a profile is created. The new person sees no classmates' posts and no other profiles. Submitting a post is refused by the database (error 42501), and so is marking a classmate's post as engaged. From reading the old code (not run): the old dashboard shows "No posts from classmates yet. Check back later." and the old submit form shows the generic "Something went wrong, try again." because the old code does not map error 42501. Nothing is lost or broken for them; they simply cannot take part until the new app ships and they join a group. They would leave the gap with a working account, so the fix is only the new deploy. Keep the gap short and ask students not to sign up during it.

**What if the new app is deployed BEFORE the migration?**
Do not do this. The new dashboard calls `group_totals` and `is_admin`, which do not exist yet, so it stops with the message "Database not up to date. Apply the migrations in supabase/migrations first." (code reading and the dashboard edit, not run against a database without the functions). The join page would show "Something went wrong, try again." Nothing is damaged, but every student sees an error until the migration runs.

## Order to go live

1. (Governor) Tell the class: sign-ups pause for about 15 minutes. Pick a quiet time. The goal is a short gap between steps 4 and 9.
2. (Governor) Check the Vercel project: does the Preview environment have the Supabase variables? Not verified. If it does, remember that every pushed branch (including `stage2-groups`) already has a preview that uses the real database. A preview of Stage 2 code opened before step 4 shows the "Database not up to date" error. It writes nothing.
3. (Governor) Back up the real database to a file OUTSIDE the repo (it holds real emails): `pg_dump` with the direct connection string, to a local file. Check the file is not empty. Without a backup, the groups rollback (step 13) cannot restore deleted group data.
4. (Governor) Apply both migrations from the terminal, in this order. They are in `supabase/migrations/` and the Supabase CLI applies them in file name order:
   - `20261009120000_classrooms_groups.sql` (tables, rules, moves everyone into "Main group" in "Tech4Youth cohort")
   - `20261020120000_admin_views.sql` (two admin only functions: members of a group, locked accounts)

   Open question: `supabase/config.toml` does not exist in the repo, so the CLI needs `supabase init` and `supabase link` first on his machine. The files contain their own `begin` and `commit`; how the CLI treats that is not verified. If the CLI complains, the fallback is the SQL Editor: paste file 1, run, then paste file 2, run.
5. (Governor) Prove the migration: `supabase migration list` shows both as applied. In the SQL Editor run `select count(*) from public.group_members;` (should equal the number of profiles) and `select g.name, i.code from public.group_invites i join public.groups g on g.id = i.group_id;` to read the Main group invite code. Whether the CLI prints the code from the migration's `RAISE NOTICE` is not verified, so use this query.
6. (Governor) Open the live site as an existing student account. The feed should look exactly as before (this is what run 5 checks). If anything looks wrong, go to the rollback section before step 7.
7. (Governor) Merge `stage2-groups` into `main` himself. Vercel deploys `main`.
8. (Governor) Wait for the Vercel deployment to finish.
9. (Governor) Create the admin account (from the header of the first migration): sign up a SEPARATE account in the app, then in the SQL Editor:
   - `insert into public.admins (user_id) select id from auth.users where email = '<admin email>';`
   - if that account existed before the migration, remove its membership: `delete from public.group_members where user_id = (select id from auth.users where email = '<admin email>');`

   Do this after step 8 so the admin lands on `/admin`. Signing in as admin then sends `/dashboard` to `/admin`.
10. (Governor) Check the live app on a phone (about 390px wide) and on a desktop: log in as a student (dashboard shows the Main group tile and the line saying who sees the post), log in as admin (`/admin` shows groups, counts, codes), and open a join link in a private window (it should go to sign up, then back to the join page).
11. (Governor) In `/admin`, make new groups for the real classes, press Copy link, and share each link in WhatsApp. Students open the link, sign up or log in, and are joined.
12. (Governor) Move people out of "Main group" with Move or Remove (each asks for a confirm). Main group is a temporary landing place. Students who mistype 5 wrong codes in a day are locked; the admin page lists them with an Unlock button.

## Rollback (only if something goes wrong)

Order matters: the app first, then the database.
13. Put the previous Vercel deployment back (Vercel dashboard, Deployments, promote the one before the merge), or revert the merge on `main`.
14. Undo the admin functions: `supabase/rollbacks/20261020120000_admin_views_rollback.sql` (drops two functions, touches no data; tested in run 6, 4 checks).
15. Undo groups: `supabase/rollbacks/20261009120000_classrooms_groups_rollback.sql` (restores the old "everyone reads everything" rules and DELETES all classrooms, groups, memberships, invite codes, admin rows and join attempts; posts, engagements and profiles are kept; tested in run 2). Group data deleted this way is only recoverable from the step 3 backup.

These rollback files live outside `supabase/migrations/` on purpose so the CLI never applies them by accident. Paste each into the SQL Editor.

## What was and was not verified (for this plan)

Verified in the cloud session: `npm ci`, `npm run build` (routes `/admin`, `/join`, `/join/[code]` present), `npm test` (5 helper tests), all six database runs (250 checks) on PostgreSQL 16.15, and the signed-in screens against a throwaway fake of the Supabase API (see `docs/REVIEW_NOTES.md` item 14).

Not verified: anything on the real Supabase project or real sign in; PostgreSQL 17; the Supabase CLI applying these files; the Vercel Preview environment variables; the live app on a real phone; the effect of a real group invite link in WhatsApp (link previews).
