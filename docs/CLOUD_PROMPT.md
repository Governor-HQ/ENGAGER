# Prompt for the Claude Code cloud session

You are continuing the ENGAGER project for Governor. FIRST read docs/HANDOFF.md completely, then docs/CURRENT_STATE.md and docs/DECISIONS.md. Follow every rule in HANDOFF.md section 2 and section 3 (no em dashes, no AI co-author or trailer anywhere, never push to main, pop-up questions for decisions, honest about what is verified, no closing questions or offers).

BRANCH: work only on stage2-groups. Commit small, after every finished piece, and push the branch after each one. Never touch main.

TASK: build Stage 2 (B1 to B7 in HANDOFF.md). Use parallel subagents for independent work: the join page (B1) and the admin screens (B2) are independent, so build them in parallel. Then the group-aware dashboard (B3), the no-group note (B4), the schema.sql update (B5), tests for new data queries (B6) and the release plan in docs/RELEASE.md (B7).

BEFORE BUILDING SCREENS: ask Governor with a pop-up, then show real image mockups (screenshots of full screens) of the join page, the admin screens and the dashboard group view. Wait for his pick. Use the existing redesign in docs/design/engager-redesign.html and app/globals.css.

STOP AND ASK first only for: edits to the migration or its rollback; edits to proxy.js, lib/csp.js, lib/supabase/* or next.config.js; adding a package.

VERIFY with real checks: `npm ci`, `npm run build`, and `bash supabase/db-tests/run.sh` (check for PostgreSQL binaries first; it must not run as root). Take screenshots of what you build. You cannot sign in with dummy env values, so say plainly which screens you could view and which you could not.

KEEP docs/REVIEW_NOTES.md: log every shortcut, doubt, assumption and anything you could not check.

REPORT after each group of work, project name first: what is finished, what is partial, what you did not check, what you added that was not asked, and the one next step. No closing questions or offers.
