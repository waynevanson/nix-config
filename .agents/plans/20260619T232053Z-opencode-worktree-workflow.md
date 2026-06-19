# OpenCode worktree implementation workflow

Created: 2026-06-19T23:20:53Z

## Goal

Add an OpenCode plugin + skill that turns a saved plan into an isolated git-worktree implementation, runs verification, prompts for acceptance, commits the work, removes the plan, and merges the result back into the original branch.

## Context

- The plugin source lives in this repo at `home-manager/profiles/waynevanson/opencode/plugins/worktree/` and is installed globally via home-manager.
- Plans are flat Markdown files at `<project-root>/.agents/plans/<timestamp>-<slug>.md`.
- Worktrees are created under `<project-root>/.worktrees/opencode-worktree/<slug>/`.
- The feature branch is named `opencode-worktree/<slug>` and is created from the branch that is current when `/worktree` is invoked.
- Workflow state is persisted in `<project-root>/.worktrees/.config.json`.
- The workflow is triggered by a custom `/worktree <plan-path>` command.
- Verification commands are inferred from project files (flake.nix, package.json, Cargo.toml, etc.).
- If the user rejects the implementation, the agent iterates in the same worktree.
- On acceptance, the agent commits the implementation, removes the plan file in the worktree, commits that removal, merges the feature branch back into the original branch with a merge commit, then removes the worktree and updates state.

## Tasks

- [ ] Task 1: Scaffold plugin and skill
  - Create `home-manager/profiles/waynevanson/opencode/plugins/worktree/` with:
    - `index.ts` — plugin entry point
    - `package.json` — dev dependency on `@opencode-ai/plugin` and a `typecheck` script
    - `tsconfig.json` — strict TypeScript config
  - Create `home-manager/profiles/waynevanson/opencode/skills/worktree/SKILL.md` with workflow instructions for the agent.

- [ ] Task 2: Implement project-root detection and state management
  - In the plugin, write helpers that find the original project root even when OpenCode is running inside a worktree:
    - Use `git rev-parse --git-common-dir` / `--show-toplevel` to distinguish the main repo from a linked worktree.
  - Read/write `<original-project-root>/.worktrees/.config.json`.
  - State schema per entry:
    - `slug`, `planPath`, `baseBranch`, `featureBranch`, `worktreePath`
    - `status`: `implementing` | `verifying` | `reviewing` | `accepted` | `merged` | `closed`
    - `createdAt`, `updatedAt`, `commits?: string[]`

- [ ] Task 3: Implement `/worktree` command
  - Hook `config` to register `command.worktree` with description and prompt.
  - Hook `command.execute.before` for `/worktree` to:
    - Parse the plan path argument.
    - Validate the plan file exists.
    - Derive `slug` from the filename (strip timestamp prefix if present).
    - Determine `baseBranch` from the current branch of the original project root.
    - Compute `featureBranch = opencode-worktree/<slug>` and `worktreePath = .worktrees/opencode-worktree/<slug>`.
    - Require a clean working tree before creating a new worktree; warn if dirty.
    - Create the worktree with `git worktree add -b <feature-branch> <worktree-path>` if it does not already exist.
    - Load or append state entry with status `implementing`.
    - Pass context to the agent (plan path, worktree path, branch names, state entry).

- [ ] Task 4: Write the worktree skill
  - Instruct the agent to treat the worktree directory as the implementation root.
  - Instruct the agent to read the plan, implement changes, then run verification inferred from project files:
    - `flake.nix` present -> `nix flake check`
    - `package.json` + `package-lock.json` -> `npm test`; `pnpm-lock.yaml` -> `pnpm test`; `yarn.lock` -> `yarn test`
    - `Cargo.toml` -> `cargo test`
    - Other common markers can be added later.
  - Instruct the agent to ask the user whether the result is acceptable using the question tool.
  - If accepted:
    - Commit implementation changes with a descriptive message.
    - Remove the plan file from the worktree (`rm .agents/plans/<slug>.md`) and commit the removal.
    - Return to the original project root, merge `opencode-worktree/<slug>` into `baseBranch` with `--no-ff`.
    - Run `git worktree remove <worktree-path>` and `git branch -d <feature-branch>`.
    - Update state to `merged` and remove or archive the entry.
  - If rejected:
    - Keep status as `implementing`, gather feedback, and iterate without discarding the worktree.

- [ ] Task 5: Wire plugin and skill into OpenCode config
  - Update `home-manager/profiles/waynevanson/opencode/opencode.json` to:
    - Reference the plugin via `./plugins/worktree/index.ts` (auto-discovered plugins also work from `.opencode/plugin/`, but this is global config so explicit plugin entry is clearer).
    - Ensure `skills` path includes `./skills`.
  - Update `home-manager/profiles/waynevanson/opencode/default.nix` to install:
    - `xdg.configFile."opencode/plugins/worktree".source = ./plugins/worktree;`
    - `xdg.configFile."opencode/skills/worktree".source = ./skills/worktree;`

- [ ] Task 6: Update plan agent conventions
  - Update `home-manager/profiles/waynevanson/opencode/agents/plan.md` to save plans as flat files at `.agents/plans/<timestamp>-<slug>.md` instead of directories.
  - Keep the existing permission: allow edits only inside `.agents/plans/**/*`.

- [ ] Task 7: Ignore worktree directories
  - Add `.worktrees/` to the project `.gitignore` so worktree directories are never tracked.
  - Do not gitignore `.agents/plans/`; plan files are intentionally tracked until removed by the workflow.

- [ ] Task 8: Verify the plugin and workflow
  - Run TypeScript typecheck on the plugin.
  - Build the home-manager generation to ensure config files are installed correctly.
  - Test the end-to-end flow on a trivial plan in this repo (e.g., add a comment or a small config change).

## Pending Questions

- None. Scope, trigger (`/worktree`), plan path format, branch/worktree naming, merge strategy, verification approach, and failure handling have been confirmed.
