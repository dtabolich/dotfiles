---
description: Review staged or uncommitted changes for bugs, security, and error handling
argument-hint: "[path-or-ref]"
---
Review the current changes in this repository.

Scope: ${1:-all uncommitted changes (staged and unstaged)}. If a path or git ref was given, restrict to it.

Gather context first:

- `git diff` and `git diff --cached` for the change under review
- `git status` to catch files that were added, deleted, or renamed but not staged

Then report, ordered by severity:

1. Bugs and logic errors, with the concrete input or state that triggers each
2. Security problems (injection, path traversal, secret handling, unsafe deserialization)
3. Error-handling gaps and unhandled failure paths
4. Missing or weakened tests for the changed behavior

For each finding give the file, the line, why it is wrong, and a specific fix. Do not report style preferences as defects. If you find nothing at a given severity, say so explicitly instead of padding. Do not modify files; this is a review.
