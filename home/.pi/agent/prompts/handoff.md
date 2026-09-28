---
description: Summarize the current session for the next agent to continue
---
Write a handoff note for whoever picks this up next.

Cover only what they cannot recover from the repository or the diff:

- The goal, and the current state relative to it
- What has been completed and verified, with the exact commands used
- What is in progress, in flight, or half-applied
- Blocked items and the specific decision or access needed to unblock them
- Dead ends already explored, so they are not retried
- The single next action

Be concrete and terse. Name files and commands. Do not restate the obvious from `git status`. Write to the conversation, not to a file, unless a path was requested: ${1:-none}.
