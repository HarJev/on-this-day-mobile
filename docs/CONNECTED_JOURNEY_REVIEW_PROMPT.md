# Parallel Worker: Connected Journey Review

This task can run alongside backend C1-C3 editorial research. It must not run
concurrently with a database import or canonical promotion without coordination.
Copy the prompt below into a separate mobile task.

```text
Work in the canonical on-this-day-mobile repository, on a fresh isolated
codex/connected-journey-review worktree based on current main. Read AGENTS.md,
CLAUDE.md, docs/QUIZ_EVENT_INTEGRATION_PROGRESS.md, docs/DESIGN.md and
design/claude-design/REVIEW.md. Read the backend API contract without editing it.

The connected-quiz feature is merged. Verify its real mobile journey; do not
implement new features or redesign screens. First inspect available iOS/Android
targets and existing local API/database processes. Reuse a healthy existing
API where possible. Start only local tooling needed for verification; report
missing data or environment problems rather than approving/importing content.

Own only docs/CONNECTED_JOURNEY_NATIVE_REVIEW.md plus ignored local captures
and logs. Record IN_PROGRESS before beginning, then PASS/FAIL/PENDING per gate.
Do not edit shared PROPOSED_CHANGES.md, the integration handoff, backend files,
canonical content, other workers' editorial batches, dependencies or native
configuration. Do not import, delete/regenerate Daily assignments, deploy,
change Firebase/AWS resources or upload assets.

Use the matching merged backend with relatedEvents/hasRelatedQuizQuestions.
Choose an existing supported date and actual linked questions; do not fake
current-day availability or require every random Quick Play to contain links.
Existing Daily assignments may predate links and remain immutable. If live
data cannot exercise a gate, mark it PENDING and separate fake/widget evidence.

Check on available simulators/emulators:
- Today/current-day eligible Event Detail -> Quiz Hub/setup, with honest copy
  and no promise that a particular story is guaranteed in every Daily size.
- Daily/Quick Play -> completed Results -> Full Review -> Related history
  -> Event Detail -> Back, preserving result, disclosure and scroll context.
- No related story titles or semantic answer clues before completion.
- Old saved results/unlinked questions remain usable without placeholders.
- Linked story load failure does not invalidate a saved result.
- Normal phone and enlarged text: wrapping, reachable controls, safe areas.
- Real owned images prepare before timing; cached repeat load works where
  observable. Never mistake a widget capture for native evidence.
- No notification permission is needed to enter this flow; do not change
  permission policy. Report platform accessibility limitations honestly.

Capture screenshots and concise logs. A route/lifecycle issue is a finding,
not permission to edit code: report the defect and proposed scoped fix first.
Do not rerun full test suites for a report-only task; use focused checks when
they add evidence. Stop only processes you started. Never print tokens/secrets.

Finish the report with exact evidence, device/API version, reproducible steps,
remaining gates and blockers. Commit and push only this report on the review
branch; no merge, deployment or PR. Ask the owner before any application fix.
```
