---
name: worktree
description: Use when the user invokes /worktree or implements a plan from .agents/plans/ in a git worktree. Guides the agent through creating, implementing, verifying, merging, and cleaning up a worktree-based feature branch.
---

# Worktree implementation workflow

This skill is invoked by the `/worktree <plan-path>` command.

## Entry

The worktree extension prepares the worktree and records state before you start. If you are running without the extension, compute the identifiers below and create the worktree manually with `git worktree add -b <feature-branch> <worktree-path>`.

## Compute identifiers

Given the plan path (e.g. `.agents/plans/20260619T120000Z-add-login.md`):

- `slug`: filename without timestamp prefix and without `.md`. For the example above, slug is `add-login`.
- `featureBranch`: `opencode-worktree/<slug>`
- `worktreePath`: `.worktrees/opencode-worktree/<slug>` relative to the original project root.
- `projectRoot`: the original git repository root. If running inside the worktree, use `dirname $(git rev-parse --git-common-dir)`. Otherwise use `git rev-parse --show-toplevel`.
- `baseBranch`: the branch current when `/worktree` was invoked, read from `.worktrees/.config.json` or from `git branch --show-current` in `projectRoot`.

## Implementation steps

1. Read the plan file.
2. Treat the worktree directory as the implementation root. Run bash commands in that directory and edit files using absolute paths under the worktree.
3. Implement the plan.
4. Update `.worktrees/.config.json` status for this entry to `verifying`.
5. Run verification. Infer commands from project files:
   - `flake.nix` exists -> `nix flake check`
   - `package.json` exists -> choose by lockfile: `package-lock.json` -> `npm test`, `pnpm-lock.yaml` -> `pnpm test`, `yarn.lock` -> `yarn test`
   - `Cargo.toml` exists -> `cargo test`
   - If multiple apply, run them in a sensible order.
6. Fix any verification failures before continuing.
7. Update `.worktrees/.config.json` status for this entry to `reviewing`.
8. Ask the user whether the result is acceptable using the question tool. Show a concise summary of changes and verification results.

## On acceptance

1. Update `.worktrees/.config.json` status for this entry to `accepted`.
2. In the worktree, commit all implementation changes with a descriptive message referencing the plan slug.
3. Remove the plan file from the worktree: `rm .agents/plans/<plan-filename>`.
4. Commit the removal.
5. Switch to `projectRoot`.
6. Merge `featureBranch` into `baseBranch` with `--no-ff`:
   `git merge <featureBranch> --no-ff -m "merge(opencode-worktree): <slug>"`
7. Delete the worktree:
   `git worktree remove <worktreePath>`
8. Delete the feature branch:
   `git branch -d <featureBranch>`
9. Update `.worktrees/.config.json`: set status to `merged`, then remove or archive the entry.

## On rejection

1. Keep `.worktrees/.config.json` status as `implementing`.
2. Ask the user what needs to change.
3. Iterate in the same worktree. Do not delete the worktree or branch.

## Notes

- Do not commit unless the user has explicitly accepted the implementation.
- If verification fails, fix the failures before asking for acceptance.
- Always use absolute paths when editing files in the worktree.
- Keep commits focused: one commit for the implementation, one commit for the plan removal.
