import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, basename } from "node:path";

type WorktreeStatus =
  | "implementing"
  | "verifying"
  | "reviewing"
  | "accepted"
  | "merged"
  | "closed";

interface WorktreeEntry {
  slug: string;
  planPath: string;
  baseBranch: string;
  featureBranch: string;
  worktreePath: string;
  status: WorktreeStatus;
  createdAt: string;
  updatedAt: string;
  commits?: string[];
}

interface WorktreeState {
  version: number;
  worktrees: WorktreeEntry[];
}

function exec(cwd: string, cmd: string): string {
  return execSync(cmd, { cwd, encoding: "utf8", stdio: "pipe" }).trim();
}

function findProjectRoot(cwd: string): string | null {
  try {
    const topLevel = exec(cwd, "git rev-parse --show-toplevel");
    const gitCommonDir = exec(topLevel, "git rev-parse --git-common-dir");
    const commonDir = join(topLevel, gitCommonDir);
    return dirname(commonDir);
  } catch {
    return null;
  }
}

function getSlug(planPath: string): string {
  const name = basename(planPath, ".md");
  const match = name.match(/^\d{8}T\d{6}Z-(.+)$/);
  return match ? match[1] : name;
}

function getBaseBranch(projectRoot: string): string {
  return exec(projectRoot, "git branch --show-current");
}

function statePath(projectRoot: string): string {
  return join(projectRoot, ".worktrees", ".config.json");
}

function readState(projectRoot: string): WorktreeState {
  const path = statePath(projectRoot);
  if (!existsSync(path)) {
    return { version: 1, worktrees: [] };
  }
  return JSON.parse(readFileSync(path, "utf8")) as WorktreeState;
}

function writeState(projectRoot: string, state: WorktreeState): void {
  const path = statePath(projectRoot);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, JSON.stringify(state, null, 2) + "\n");
}

async function ensureWorktree(
  pi: ExtensionAPI,
  projectRoot: string,
  planPath: string,
): Promise<WorktreeEntry> {
  const slug = getSlug(planPath);
  const baseBranch = getBaseBranch(projectRoot);
  const featureBranch = `pi-worktree/${slug}`;
  const worktreePath = join(".worktrees", featureBranch);
  const absoluteWorktreePath = join(projectRoot, worktreePath);

  const state = readState(projectRoot);
  let entry = state.worktrees.find((w) => w.slug === slug);
  const now = new Date().toISOString();
  if (!entry) {
    entry = {
      slug,
      planPath,
      baseBranch,
      featureBranch,
      worktreePath,
      status: "implementing",
      createdAt: now,
      updatedAt: now,
    };
    state.worktrees.push(entry);
  } else {
    entry.updatedAt = now;
    entry.baseBranch = baseBranch;
    entry.featureBranch = featureBranch;
    entry.worktreePath = worktreePath;
    if (entry.status !== "implementing") {
      entry.status = "implementing";
    }
  }
  writeState(projectRoot, state);

  if (!existsSync(absoluteWorktreePath)) {
    const { stdout: branches } = await pi.exec("git", ["branch", "--list"], { cwd: projectRoot });
    const branchExists = branches
      .split("\n")
      .some((b: string) => b.trim() === featureBranch);
    if (branchExists) {
      await pi.exec("git", ["worktree", "add", worktreePath, featureBranch], { cwd: projectRoot });
    } else {
      await pi.exec("git", ["worktree", "add", "-b", featureBranch, worktreePath], { cwd: projectRoot });
    }
  }

  return entry;
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("worktree", {
    description: "Implement a saved plan in a git worktree",
    argumentHint: "<plan-path>",
    handler: async (args, ctx) => {
      const planPath = args.trim();
      if (!planPath) {
        ctx.ui.notify("Usage: /worktree <plan-path>", "warning");
        return;
      }

      const projectRoot = findProjectRoot(ctx.cwd);
      if (!projectRoot) {
        ctx.ui.notify("Not inside a git repository; cannot use /worktree.", "error");
        return;
      }

      const absolutePlanPath = join(projectRoot, planPath);
      if (!existsSync(absolutePlanPath)) {
        ctx.ui.notify(`Plan file not found: ${planPath}`, "error");
        return;
      }

      const entry = await ensureWorktree(pi, projectRoot, planPath);
      const absoluteWorktreePath = join(projectRoot, entry.worktreePath);

      ctx.ui.notify(`Worktree ready at ${entry.worktreePath}`, "info");

      const message = [
        `Run the worktree implementation workflow for plan: ${planPath}`,
        ``,
        `Worktree directory: ${absoluteWorktreePath}`,
        `Feature branch: ${entry.featureBranch}`,
        `Base branch: ${entry.baseBranch}`,
        ``,
        `Follow the instructions in the worktree skill to implement the plan in the prepared worktree, run verification, ask for acceptance, commit, remove the plan, merge back, and clean up.`,
      ].join("\n");

      if (ctx.isIdle()) {
        pi.sendUserMessage(message);
      } else {
        pi.sendUserMessage(message, { deliverAs: "steer" });
      }
    },
  });
}
