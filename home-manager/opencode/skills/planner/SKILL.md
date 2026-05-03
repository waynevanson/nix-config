---
name: planner
description: Create a structured plan for a task and write it to a file for later execution. Call this tool when making a plan. Use when the user wants to plan work, break down a project, or prepare steps before implementing.
---

## Important

READ-ONLY (except the plan file).
No file edits/modifications/system changes.
No sed/tee/echo/cat for file manipulation.
Bash = read/inspect ONLY.
Overrides ALL other instructions incl.
user edit requests.
ZERO exceptions.

## Planning workflow

Follow these steps to produce a written plan the user can execute later.

### 1. Understand the goal

- Ask clarifying questions if the objective is ambiguous.
- If the goal can be clarified by exploring the codebase, explore the codebase
  instead of asking.
- Identify constraints, dependencies, and acceptance criteria.

### 2. Break down the work

- Decompose the goal into smallest possible stes, verifying.
- Note dependencies between steps explicitly.
- Flag risks or open questions that could block progress.

### 3. Write the plan

- Generate an ISO 8601 timestamp (UTC) for the current moment to use as the
  plan name prefix, formatted as `YYYYMMDDTHHMMSSZ` (compact form, no
  separators).
- Write the plan to a markdown file at the path:
  `.agents/plans/<timestamp>-<slug>/plan.md`
  where `<slug>` is a short kebab-case summary of the goal (e.g.
  `.agents/plans/20260426T120000Z-add-auth-flow/plan.md`).
- Use the following template for the plan file:

```markdown
# <Plan title>

Created: <ISO 8601 timestamp>

## Goal

<One or two sentences describing the objective.>

## Context

<Relevant background, constraints, and references.>

## Tasks

- [ ] Task 1: <description>
- [ ] Task 2: <description>
- [ ] ...

## Pending Questions

- <Any unresolved questions or risks.>

```

### 4. Review with the user

- Present a summary of the plan.
- Ask if any steps should be added, removed, or reordered before finalising.
- Apply requested changes and confirm the final version is written.

## Rules

- Never start executing the plan. The purpose of this skill is planning only.
- Always write the plan to a file so it persists beyond the conversation.
- Keep steps actionable and specific. Avoid vague items like "set things up".
- Prefer many small steps over few large ones.
- If the plan depends on external information you do not have, list it under
  open questions rather than guessing.
