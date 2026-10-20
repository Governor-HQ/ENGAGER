# ENGAGER review notes

The cloud session records here every shortcut, doubt, assumption or thing it could not check. Governor and the build lead read this file after each push. One entry per item: date, what, why, what would settle it.


## 20 Oct 2026

1. **Second migration added, first one untouched.** Governor chose a new file for admin member names and locked accounts: `supabase/migrations/20261020120000_admin_views.sql` (functions `admin_group_members`, `admin_locked_accounts`), with rollback `supabase/rollbacks/20261020120000_admin_views_rollback.sql`. Admin now sees member NAMES and join dates (not emails, not posts). This extends the decided admin rule ("sees counts and codes"); Governor approved it by pop-up. Apply order: first migration, then this one.
2. **Tests for it:** `supabase/db-tests/admin_views.test.sql`, 14 checks, wired into `run.sh` as run 4. Verified here on PostgreSQL 16.15 (not 17): 164 + 17 + 21 + 14 all pass. Two broken copies of the new migration were each caught (threshold 5 changed to 6; admin check removed). Not verified: PostgreSQL 17, real Supabase.
3. **run.sh changed** (not a protected file): added run 4 and an optional second argument for the admin views migration, so broken copies can be tested.
4. **Container setup, not committed:** run.sh refuses root, so it was run as the `postgres` user with `/usr/lib/postgresql/16/bin` on PATH.
5. **Mockups** were static HTML screenshots with a fallback font (Google Fonts not reachable). The "3 tries left" line in mockup join B was illustrative and is not built, because `join_group` returns a status word, not a count.
