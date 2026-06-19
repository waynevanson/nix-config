---
name: steps
description: >-
  Create a TDD execution plan as a makefile-style dependency graph. Use when the
  user says "create steps", or after a plan has been approved and written to the
  filesystem. Reads the corresponding plan.md and produces steps.md in the same
  plan directory.
---

## Steps workflow

Follow these steps to produce a TDD execution plan for an existing plan
document.

### 1. Locate the plan

- Identify the plan directory the user is referring to under
  `.agents/plans/<timestamp>-<slug>/`.
- Read `plan.md` from that directory to understand the goal, context, and tasks.

### 2. Assess testability

- Determine whether the plan involves code changes that can be verified with
  automated tests.
- If the work is not testable (e.g. documentation-only, config-only, or pure
  infrastructure changes with no programmatic verification), inform the user
  that TDD steps are not applicable and stop. Do not write `steps.md`.

### 3. Decompose into red-green-refactor cycles

- Break the plan's tasks into the smallest testable behaviours.
- Each behaviour becomes one target in the dependency graph.
- Order targets so that each builds on the previous — a target's dependencies
  must pass before it can begin.
- Identify which targets can run in parallel (no dependency between them) and
  which are sequential.

### 4. Write steps.md

- Write the file to `.agents/plans/<timestamp>-<slug>/steps.md`.
- Use the makefile dependency graph format below.

```makefile
# TDD execution order for: <plan title>
# Reference: .agents/plans/<name>/plan.md

# <brief description of what this target tests>
test-<name>:
	# Red:      <what the test asserts>
	# Green:    <minimal implementation to pass>
	# Refactor: <cleanup opportunity after green>

# <brief description of what this target tests>
test-<name>: test-<dependency>
	# Red:      <what the test asserts>
	# Green:    <minimal implementation to pass>
	# Refactor: <cleanup opportunity after green>
```

Format rules:

- Target names use `test-` prefix with kebab-case descriptive names.
- Dependencies are listed after the colon, space-separated.
- Each target has exactly three comment lines: Red, Green, Refactor.
- Red describes what the test asserts (the expected behaviour).
- Green describes the minimal production code to make the test pass.
- Refactor describes what to clean up after the test passes — duplication,
  naming, structure, or extraction opportunities.
- A comment line above each target briefly describes what it covers.
- Targets with no dependencies come first in the file.
- Targets with shared dependencies that are otherwise independent can be
  implemented in any order (they are parallelisable).

### 5. Review with the user

- Present a summary of the dependency graph.
- Ask if any cycles should be added, removed, reordered, or split.
- Apply requested changes and confirm the final version is written.

## Rules

- Never start executing the steps. This skill produces the plan only.
- Always read the corresponding `plan.md` before producing steps.
- If `plan.md` does not exist in the target directory, ask the user which plan
  to use.
- Keep each target as small as possible — one behaviour per test.
- Prefer many small targets over few large ones.
- Every target must include a Refactor line, even if it is "no refactoring
  needed".
