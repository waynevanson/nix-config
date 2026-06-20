import type { Plugin } from "@opencode-ai/plugin";
import { execSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, basename } from "node:path";
import { fileURLToPath } from "node:url";

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

function ensureWorktree(projectRoot: string, planPath: string): WorktreeEntry {
  const slug = getSlug(planPath);
  const baseBranch = getBaseBranch(projectRoot);
  const featureBranch = `opencode-worktree/${slug}`;
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
    const branches = exec(projectRoot, "git branch --list");
    const branchExists = branches
      .split("\n")
      .some((b) => b.trim() === featureBranch);
    if (branchExists) {
      exec(projectRoot, `git worktree add "${worktreePath}" "${featureBranch}"`);
    } else {
      exec(projectRoot, `git worktree add -b "${featureBranch}" "${worktreePath}"`);
    }
  }

  return entry;
}

function extractPlanPath(input: unknown): string | null {
  if (typeof input !== "object" || input === null) return null;
  const args = (input as Record<string, unknown>).args;
  if (Array.isArray(args) && args.length > 0 && typeof args[0] === "string") {
    return args[0];
  }
  const raw = (input as Record<string, unknown>).raw;
  if (typeof raw === "string") {
    const tokens = raw.trim().split(/\s+/);
    if (tokens.length > 1) return tokens[1];
  }
  return null;
}

function isWorktreeCommand(input: unknown): boolean {
  if (typeof input !== "object" || input === null) return false;
  const cmd =
    (input as Record<string, unknown>).command ??
    (input as Record<string, unknown>).name;
  if (typeof cmd === "string") {
    return cmd === "worktree" || cmd === "/worktree";
  }
  const raw = (input as Record<string, unknown>).raw;
  if (typeof raw === "string") {
    return raw.trim().startsWith("/worktree");
  }
  return false;
}

const __dirname = dirname(fileURLToPath(import.meta.url));
const skillPath = join(__dirname, "skills");

export default (async ({ directory }) => {
  const cwd = directory || process.cwd();
  const projectRoot = findProjectRoot(cwd);

  return {
    async config(cfg: Record<string, unknown>) {
      const skills = ((cfg.skills as Record<string, unknown>) ??= {});
      const paths = ((skills.paths as string[]) ??= []);
      if (!paths.includes(skillPath)) {
        paths.push(skillPath);
      }

      const commands = ((cfg.command as Record<string, unknown>) ??= {});
      if (!commands.worktree) {
        (
          commands as Record<string, { description: string; prompt: string }>
        ).worktree = {
          description: "Implement a saved plan in a git worktree",
          prompt:
            "You are running the worktree implementation workflow. Read the plan path from the user's command, then follow the instructions in the worktree skill to implement the plan in the prepared worktree, run verification, ask for acceptance, commit, remove the plan, merge back, and clean up.",
        };
      }
    },
    "command.execute.before": async (
      input: unknown,
      _output: unknown,
    ) => {
      if (!isWorktreeCommand(input)) return;
      if (!projectRoot) {
        throw new Error("Not inside a git repository; cannot use /worktree.");
      }
      const planPath = extractPlanPath(input);
      if (!planPath) {
        throw new Error("Usage: /worktree <plan-path>");
      }
      const absolutePlanPath = join(projectRoot, planPath);
      if (!existsSync(absolutePlanPath)) {
        throw new Error(`Plan file not found: ${planPath}`);
      }
      ensureWorktree(projectRoot, planPath);
    },
  };
}) satisfies Plugin;
