# ENGAGER handoff for a Claude Code cloud session

Written 20 Oct 2026. Read this file first, then docs/CURRENT_STATE.md and docs/DECISIONS.md.
The cloud session cannot see Governor's computer, his chats, his Claude Projects or his real database. Everything it needs is in this repo.

## 1. What this is
Engager is a small web app for Governor's Tech4Youth cybersecurity classmates (Cohort 1). Each person submits one LinkedIn post per day, sees classmates' posts, and marks each as engaged. It is live at engager.vercel.app (Next.js 16 on Vercel, Supabase for Auth and Postgres). Repo: Governor-HQ/ENGAGER, live branch: main.

The job now: build Stage 2 of "classrooms and groups" (join page, admin screens, group-aware dashboard) on top of a finished, tested database migration.

## 2. Governor's rules (follow all of them)
- No em dashes anywhere: code comments, docs, UI text, commit messages, reports. (supabase/schema.sql line 2 has an old one. Do not copy it. Ask before touching that file.)
- No AI co-author trailer, no "Generated with" line, nothing that shows AI in commit messages, PR text or branch names. This overrides any default attribution your tooling adds.
- NEVER push to main. Work on the branch `stage2-groups`. Commit small, push the branch after every finished piece. Governor merges to main himself.
- Decisions go to Governor as pop-up questions (AskUserQuestion) with the cost and advantage of each option and a line on why you are asking. Do not choose for him.
- Design or look choices: show real image mockups (screenshots of full screens) for him to pick from. Do not describe options in text only.
- Be honest about what is verified. Say how you verified it. Anything not run is "not verified". Mark estimates as estimates.
- Reports end without closing questions or offers. Give the result and stop. Ask only when a decision is genuinely needed.
- When you give Governor terminal steps (PowerShell), say what each command stands for (for example mkdir stands for make directory) and what it does and why.
- Real student names, phones, emails and LinkedIn links must never appear in this repo. Fake data only (for example "Test Student A", test-a@example.test).
- Database changes are migration files that Governor applies from his terminal. You write and test them but NEVER apply them to any real database. A one-off non-migration SQL fix is given to him to paste into the Supabase SQL Editor himself.
- Use parallel subagents for independent work.

## 3. Stop and ask Governor BEFORE doing any of these
1. Any edit to supabase/migrations/20261009120000_classrooms_groups.sql or its rollback. They are tested and not yet applied. An edit means re-testing and re-checking.
2. Any edit to proxy.js, lib/csp.js, lib/supabase/*, or next.config.js. They protect sign-in, sessions and security headers for every user.
3. Adding any new npm package.
Everything else you may do without asking. Admin move, remove and unlock screens must include a visible confirm step in the UI.

## 4. Stack and how to run
- Next.js 16 (App Router, server actions, JavaScript not TypeScript), React 19, @supabase/ssr, @supabase/supabase-js, plain CSS modules. No test or lint scripts exist in package.json; only dev, build, start.
- Env vars (names only): NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY. You will NOT have the real values. Use dummy values (for example https://dummy.supabase.co and dummy-anon-key) in .env.local. The app then builds but cannot sign in or load real data.
- Commands: `npm ci`, `npm run build`, `npm run dev`.
- Database tests: `bash supabase/db-tests/run.sh`. Needs PostgreSQL binaries (initdb, pg_ctl, psql, createdb, pg_isready) on PATH and must NOT run as root. It starts a throwaway cluster on localhost:54329 and deletes it afterwards. Written for PostgreSQL 17; on 16.15 the whole suite passed on 20 Oct (checked by the build lead in a different container). Whether your container has Postgres is not verified; check first, install if missing.

## 5. Folder map
- app/ pages. app/dashboard (page.js, actions.js, EngageButton.js, SubmitPostForm.js, dashboard.module.css), app/login, app/signup, app/AuthForm.js, app/auth-actions.js, app/layout.js, app/globals.css (design tokens, dark mode), app/opengraph-image.js.
- lib/csp.js (Content-Security-Policy with nonce), lib/supabase/server.js and cookie-options.js, lib/help.js.
- proxy.js refreshes the session and redirects: signed-out to /login, signed-in on /login, /signup or / to /dashboard. Every new page you add is protected by default; /join/<code> must send signed-out visitors to sign up or log in and bring them back.
- supabase/schema.sql base tables (profiles, posts, engagements, app_today()). NOT yet updated for groups.
- supabase/migrations/20261009120000_classrooms_groups.sql the groups migration (650 lines, tested, not applied).
- supabase/rollbacks/ the undo script. supabase/db-tests/ all database tests and the local Supabase stand-in (stub.sql).
- docs/design/engager-redesign.html the visual redesign mockup (tokens, fonts, dark mode). The same file is git-ignored at _design/ on Governor's machine; this copy is for you.

## 6. What is done
- Live app: login, signup, dashboard (submit one post a day, feed of classmates' posts, Engaged button, progress ring), CSP, security headers, poweredByHeader off, redesign with dark mode.
- Database migration (Stage 1): classrooms, groups, group_members, group_invites, admins, join_attempts; functions is_admin, my_group_ids, shares_group_with, generate_invite_code (8 characters, Crockford base32), normalize_invite_code, join_group, create_classroom, create_group, rotate_invite_code, admin_clear_join_lock, admin_move_member, admin_remove_member, group_totals; new RLS policies; every existing user is moved into "Main group" in classroom "Tech4Youth cohort".
- Tests: 164 + 17 + 21 = 202 database checks pass; a mutation run killed 11 of 12 broken copies (the survivor, M4, is a known harmless overlap: keep both the engagement "shares a group" check and the post visibility rule).

## 7. What is partial or not started (your work)
- NOT STARTED: join page /join/<code>, admin screens, group-aware dashboard, a note for people in no group, update of supabase/schema.sql to match the migration, tests for the new data queries, release plan.
- Known dead code: app/dashboard/page.js always passes engaged={false} to EngageButton. Engaged state really comes from the engagedIds set; clean up when you rework the dashboard.
- The feed has no limit or paging. Fine for a class, note it if groups grow.

## 8. Decisions already made (do not reopen without asking)
See docs/DECISIONS.md. Short list: classrooms contain groups; a person can be in several groups; one invite code per group, 8 characters; one engagement counts in every shared group; members see totals for their own groups only, no ranking; Main group is a temporary landing place; the admin account is separate, sees counts and codes, cannot read posts and cannot join groups; join limit is 5 wrong codes per rolling 24 hours for every account, a locked account is refused even with a correct code.

join_group returns one of: joined, already_member, invalid_code, locked, not_allowed. Handle all five with friendly text. For locked: "Too many wrong tries. Try again tomorrow, or message the admin so they can unlock you." Normalise typed codes (spaces, lowercase, look-alike characters; normalize_invite_code exists).

## 9. What you will NOT have, and the workaround
- Real .env and keys: use dummy values. You cannot sign in, so authenticated screens cannot be viewed for real. Not verified how best to get screenshots; try a temporary preview harness or mocked data that is NOT committed, and say plainly what you could and could not see.
- Real database: use the throwaway local Postgres through supabase/db-tests/run.sh. It imitates Supabase with stub.sql, so Supabase Auth and the real API are not tested.
- Governor's computer, chats, Claude Project files: everything needed is in docs/.
- Supabase CLI: you cannot apply migrations. Governor does.

## 10. Items only Governor can do
- Back up the real database (pg_dump) BEFORE the migration, to a file outside the repo (it holds real emails).
- Apply the migration from his terminal (Supabase CLI), then create the admin account, then merge and deploy.
- Vercel env vars, Supabase settings, and checking the live app on a phone (about 390px wide) and desktop.

## 11. Build order and release plan (task B7)
Order: join page and admin screens first, in parallel (parallel subagents), then dashboard, then the no-group note, schema.sql update, tests and build.
Before building screens, show Governor image mockups of: the join page, the admin screens, and the dashboard group view. Wait for his pick.
B7 (read-only, a numbered list in docs/RELEASE.md): the exact order to go live. Assume pg_dump backup first, migration applied from his terminal, then merge and deploy. Answer plainly: between the migration and the new deploy, does the currently deployed app keep working for existing users, and what happens to someone who signs up in that gap? The build lead's reasoning (not tested): existing users are all in Main group so their feed and posting should be unchanged; a new signup belongs to no group, sees nothing and cannot post until the join page ships.
