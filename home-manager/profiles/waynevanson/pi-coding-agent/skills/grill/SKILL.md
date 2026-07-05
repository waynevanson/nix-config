---
name: grill
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
---

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

## Before asking questions

Analyze the plan and identify all questions you need to ask. Map out which questions depend on the answers to other questions. Display this as a dependency graph in Makefile format before asking anything.

Each target is a question. Dependencies are other questions whose answers affect this one. Add a brief comment above each target explaining what it resolves.

Example:

```makefile
# How do we handle auth tokens?
auth-token-storage: transport-protocol
# Do we use REST or gRPC?
transport-protocol:
# How do we handle token refresh?
token-refresh: auth-token-storage session-lifetime
# How long do sessions last?
session-lifetime:
```

After displaying the graph, begin asking questions in dependency order (leaves first). Update and redisplay the graph as answers reveal new questions or eliminate branches.

## While asking questions

Ask as many questions as possible, using the dependency graph to decide which questions to ask in parallel.

If a question can be answered by exploring the codebase, explore the codebase instead.

If a question can't be answered after exploring the codebase, ask a question to the user using the question tool.

## After each round of questioning

Once a round of questions has been completed

1. Reevaluate understanding of plan.
2. Recalculate dependency graph.
3. If the plan was read from a file, apply these changes to the plan.
4. Show the new dependency graph
   - highlighting in bold the new questions
   - strikethrough deleted questions
5. Ask the next round of questions.
