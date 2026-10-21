# ENGAGER decisions and status

Decided by Governor unless stated. Newest first.

## 21 Oct 2026: Stage 2 screen choices (picked by Governor from image mockups)
- Join page: split layout like login (red panel plus form).
- Admin: one page with a table per classroom, members and locked accounts, with a visible confirm bar for rotate, move, remove and unlock.
- Dashboard: a "Your groups" card with one tile per group (members, posts, engagements) and a line saying who sees your post. Totals only, no per group filter.
- No group: a "Join your group to start" card with an Enter an invite code button.
- proxy.js: small edit approved so a signed out visitor on /join goes to /signup?next=/join/<code> and comes back after.
- Admin member names: a second migration (`20261020120000_admin_views.sql`) adds admin only functions for member names and locked accounts. The tested first migration is untouched. This widens the admin rule: the admin now sees member names and join dates (not emails, not posts).
- schema.sql stays the base file with a header pointing to the migrations (merging the group tables in would break the tests and the migration's run-twice guard).
- Commit author stays as the container identity; commit messages carry no AI trailer.

## 20 Oct 2026: how the cloud session works
- Git: the cloud session commits small pieces and pushes the branch stage2-groups. Never main. Governor merges.
- Order: join page and admin screens first (in parallel), then the dashboard.
- Mockups: image mockups for the join page, the admin screens and the dashboard group view before building them.
- Stop and ask only for: edits to the migration or rollback; edits to proxy.js, lib/csp.js, lib/supabase/*, next.config.js; new npm packages. Not every action needs a pause.
- Database changes use his preferred pattern: migration files applied from his terminal, not pasted into the SQL Editor (one-off non-migration SQL is the exception, pasted by him).

## 9 Oct 2026: join limit
- 5 wrong codes per rolling 24 hours for EVERY account, group or not (was 5 per 15 minutes). A locked account is refused even with a correct code, and the reply (locked) reveals nothing about any code. Locked calls are not recorded, so the lock lifts 24 hours after the 5th wrong code.
- Why: sign-up is open with no email confirmation, so fake accounts are free. A limit only for accounts with no group could be bypassed by joining one group first.
- Admin can clear one account's failed attempts (admin_clear_join_lock). Accepted cost: a student who mistypes 5 times waits up to a day or asks the admin.
- Rejected for now: site-wide ceiling (an attacker could block real students from joining), 10-character codes, CAPTCHA, email confirmation. Brute-force arithmetic: 32^8 is about 1.1 trillion codes; at 5 guesses a day per account an attacker with 1,000,000 fake accounts needs about 60 years (estimate).

## 9 Oct 2026: groups design
- Classrooms contain groups. A person can be in several groups.
- One invite code per group, shared in WhatsApp. Codes are 8 characters, Crockford base32 (regex ^[0-9A-HJKMNP-TV-Z]{8}$).
- Engaging a mutual author's post once counts as engaged in every shared group. Proven by tests: one engagement row per post and person, counted in every shared group, post shown once.
- Members see group totals for their own groups only. No ranking.
- "Main group" in classroom "Tech4Youth cohort" is a temporary landing place for existing users. The admin moves or removes people out of it.
- The admin account is separate: sees counts and codes, cannot read posts, cannot join groups.
- A post requires membership of at least one group.
- Keep BOTH the engagement "shares a group" check and the post visibility rule even though they overlap (mutant M4).

## Earlier
- Live fixes shipped in commit f2fdbf2: poweredByHeader off, Already engaged badge, dashboard dead space fixed.
- Redesign (tokens, fonts, dark mode) and CSP with nonce shipped before that.

## Status
Stage 1 (database) finished and tested, not applied. Stage 2 (screens) built on branch stage2-groups, not merged. See docs/CURRENT_STATE.md and docs/RELEASE.md.
