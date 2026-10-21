# ENGAGER current state (21 Oct 2026)

## Git
- Branch main, last commit f2fdbf2 "Hide X-Powered-By header, restyle Already engaged state, fix dashboard dead space", pushed to Governor-HQ/ENGAGER. This is what is live at engager.vercel.app.
- Stage 2 work is on branch stage2-groups (see the Stage 2 section below).

## Verified on 20 Oct 2026 (by the build lead, not by the cloud session)
- `bash supabase/db-tests/run.sh` on throwaway PostgreSQL 16.15: engager_test 164 passed 0 failed; engager_rollback 17 passed 0 failed; engager_propagation 21 passed 0 failed; RESULT PASS (all 3 runs). Port 54329 free afterwards.
- `npm ci` and `npx next build` with dummy env values: compiled successfully, 8 static pages generated, routes /, /_not-found, /dashboard, /icon.svg, /login, /opengraph-image, /signup, plus the Proxy.
- Scan of supabase/ for real data: no real emails, no phone numbers, no keys. Test users are "Test Student A/B/C" and *.example.test addresses; ids are placeholder UUIDs.
- Reported earlier by Claude Code (not re-run by the build lead): mutation test, 12 broken copies, 11 caught, M4 survives by design.

## Not verified
- Anything on the real Supabase project or real Auth. The migration has never been run against a real database.
- PostgreSQL 17 (the version run.sh is written for). Only 16.15 was used.
- No unit, lint or type-check scripts exist in this project, so none were run. The build ran TypeScript step with no TS files.
- The live app on a phone or desktop after the latest deploy (Governor's check).
- Supabase CLI behaviour with this migration file (it has its own begin and commit). See "Open questions".

## Open questions for Governor (do not guess)
- Applying the migration with `supabase db push` instead of the SQL Editor: the file header still says "Supabase Dashboard > SQL Editor". Whether the CLI prints the Main group invite code (it is a RAISE NOTICE) is not verified. Fallback to read it: run `select g.name, i.code from public.group_invites i join public.groups g on g.id = i.group_id;` in the SQL Editor (one-off query).
- supabase/config.toml does not exist in the repo (needs `supabase init` and `supabase link` on Governor's machine).
- Vercel creates preview deployments for pushed branches. Not verified whether the Preview environment has Supabase env vars, or that a preview of Stage 2 code must not be used against the real database before the migration runs.

## Next
Cloud session builds B1 to B7 on branch stage2-groups (see docs/HANDOFF.md section 11).

## Stage 2 built on branch stage2-groups (21 Oct 2026, cloud session)
Built and pushed to `stage2-groups` (never main): join page `/join` and `/join/<code>` (invite link survives sign up and log in, small approved edit in proxy.js), admin screens `/admin` (groups, codes, members, locked accounts, confirm bars for rotate, move, remove, unlock), group aware dashboard (group tiles, who sees your post, no-group card, admin sent to `/admin`), a second migration `20261020120000_admin_views.sql` with rollback, schema.sql header fixed, tests, and `docs/RELEASE.md` (order to go live, the gap answer, rollback).

Verified in the cloud session: `npm ci`; `npm run build`; `npm test` (5 helper tests); `bash supabase/db-tests/run.sh` on PostgreSQL 16.15, 6 runs, 164 + 17 + 21 + 28 + 16 + 4 = 250 checks pass; mutation checks on the new migration (3 broken copies caught); signed in screens loaded and screenshotted against a throwaway fake of the Supabase API (not in the repo).

Not verified: real Supabase and real sign in; PostgreSQL 17; the CLI applying the migrations; Vercel Preview variables; a real phone; dark mode of join and admin. Everything doubtful is in `docs/REVIEW_NOTES.md`.

Next: Governor reviews the branch and follows `docs/RELEASE.md`. Both migrations are still NOT applied anywhere.
