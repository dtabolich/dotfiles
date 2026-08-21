# global agent instructions

- Agents must **never run `sudo` or any privilege-escalation command** on the user's local machine. If elevated access is needed, stop and ask the user explicitly.
- Any VM access (including read-only) requires **fresh explicit approval** in the current user request: which VM and what action. Prior chat mentions are not standing auth. Approval for one VM/purpose never extends to another. Prefer local workspace. See `~/.cursor/rules/no-vm-code-changes.mdc`.
- Git remotes, fetch, and push: SSH whenever possible. Do not add HTTPS remotes when SSH exists. See `~/.cursor/rules/prefer-git-ssh.mdc`.
- Never use the em dash "—". Use plain dash "-" instead
- When writing commit messages, NEVER auto-add your agent name as co-author
- Never manually modify CHANGELOG.md files or any files that are marked as auto-generated
- When making technical decisions, do not give much weight to development cost.
  Instead, prefer quality, simplicity, robustness, scalability, and long term maintainability.
- For one-off or infrequent operational work, start with the simplest direct end-to-end path. Do not build wrappers, control planes, policy layers, custom verifiers, or automation unless the direct path exposes a concrete blocker or repeated need that justifies the added machinery.
- When doing bug fixes, always start with reproducing the bug in an E2E setting as closely aligned with how an end user would experience it as possible.
  This makes sure you find the real problem so your fix will actually solve it.
- When end-to-end testing a product, be picky about the UI you see and be obsessed with pixel perfection.
  If something clearly looks off, even if it is not directly related to what you are doing, try to get it fixed along the way.
- Apply that same high standard to engineering excellence: lint, test failures, and test flakiness.
  If you see one, even if it is not caused by what you are working on right now, still get it fixed.
- Before using "dynamic workflows", "ultra code" or any harness feature that immediately spawns a large swarm of subagents, always explain the tradeoffs and ask the user for explicit approval.
