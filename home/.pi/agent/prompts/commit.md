---
description: Draft a commit message from the staged diff
argument-hint: "[scope]"
---
Write a commit message for the staged changes.

Read `git diff --cached` and `git log --oneline -10` for the repository's message conventions.

Constraints:

- Subject line: imperative mood, 72 characters or fewer
- Body: explain why the change is needed, not a line-by-line restatement
- Never add a co-author, "Generated with", or any agent attribution
- Never use an em dash; use a plain hyphen
- If nothing is staged, stop and say so rather than guessing

Return the message in a fenced block. Do not run `git commit`.
