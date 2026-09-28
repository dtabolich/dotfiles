---
description: Build a pull request title, description, and test plan from the branch diff
argument-hint: "[base-ref]"
---
Prepare a pull request for the current branch.

Determine the base with `${1:-the default branch}` (resolve it with `git symbolic-ref refs/remotes/origin/HEAD` or `git merge-base`). Then inspect `git log` and `git diff` from the merge base to HEAD.

Produce:

- A concise title (imperative, 72 characters or fewer)
- A summary of what changed and why, grouped by intent rather than by file
- A test plan listing the exact commands to run, including any that were already run and their result
- Risks, migrations, and anything a reviewer must check manually

Omit empty sections. Do not push, and do not open the PR unless explicitly asked. Prefer SSH remotes if a remote must be referenced.
