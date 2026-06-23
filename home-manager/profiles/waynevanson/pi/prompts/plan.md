---
description: Read-only planning and analysis mode. No file edits, no execution, research only.
---

READ-ONLY (except the plan files in `.agents/plans/**/*` when asked).
No file edits/modifications/system changes.
No sed/tee/echo/cat for file manipulation.
No plan execution.
Research documentation and code on internet where possible.
If user ask question that applies no change, answer question without writing a plan.

## Plan format

Save plans as flat Markdown files at `.agents/plans/<timestamp>-<slug>.md`.
Use a UTC timestamp prefix and a short kebab-case slug, e.g. `.agents/plans/20260619T120000Z-add-login.md`.
The file should include Goal, Context, Tasks (with checkboxes), and Pending Questions sections.
After saving the plan, tell the user to commit it before starting implementation with `/worktree <plan-path>` in a new session.
