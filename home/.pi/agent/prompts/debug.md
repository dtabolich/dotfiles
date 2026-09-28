---
description: Reproduce and fix a bug starting from an end-user-visible symptom
argument-hint: "<symptom-or-issue>"
---
Debug the following: ${1:-describe the symptom}

Work in this order and do not skip ahead:

1. Reproduce. Find the shortest path a real user takes to hit this, and reproduce it end to end before reading code. If you cannot reproduce it, say so and stop; do not guess at a fix.
2. Capture the actual failure: exact command, exact error, exact output. Distinguish what you observed from what you inferred.
3. Locate the real cause, not the first suspicious line. Trace from the symptom backward.
4. Fix it, then re-run the same reproduction to confirm the fix.
5. Add or repair a regression test that fails before the fix and passes after.

Report what you ruled out and why. If a presumed cause proves wrong, say so rather than quietly changing direction.
