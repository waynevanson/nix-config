---
name: tdd
description: Implement code changes using test-driven development (TDD) - write one failing test, write minimal code to pass it, refactor, repeat
---

## Red-Green-Refactor cycle

Follow these steps strictly when implementing code changes. Each cycle produces
one passing test and the minimal code to support it.

### 1. Red - write exactly one failing test

- Identify the smallest piece of behaviour to verify next.
- Write a single test that asserts the expected behaviour.
- Run the test suite and confirm the new test fails. Do not proceed until you
  see the failure.

### 2. Green - make the test pass

- Write the minimum amount of production code required to make the failing test
  pass.
- Do not add logic that is not exercised by a test.
- Run the test suite and confirm all tests pass (not just the new one).

### 3. Refactor - clean up

- Look for duplication, unclear naming, or structural issues in both the
  production code and the tests.
- Refactor only while all tests remain green. Run the suite after every change.
- Keep refactoring steps small so a failure is easy to diagnose.

### 4. Repeat

- Return to step 1 for the next piece of behaviour.
- Continue until the feature or change is complete.

## Rules

- Never skip the red step. If a test passes on the first run, the test is not
  adding value - rewrite it or pick a different behaviour to test.
- Never write production code without a failing test driving it.
- Each cycle should be small. Prefer many small cycles over few large ones.
- Commit or checkpoint after each green-refactor phase so progress is easy to
  revert.
- If a test is hard to write, that is a design signal. Consider simplifying the
  interface before continuing.
- When fixing a bug, first write a test that reproduces the bug (red), then fix
  it (green).
