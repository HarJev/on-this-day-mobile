# Design Workspace

Working area for the next visual improvement pass. The canonical design rules
still live in [../docs/DESIGN.md](../docs/DESIGN.md); nothing here overrides them
until DESIGN.md is updated.

## Goal

The app works, but the quiz feels visually flat and repetitive, and the rest of
the app can look more polished for what it is. The aim is a refresh, not a
redesign: same identity (warm paper, ink, cobalt, serif/sans), same navigation,
better rhythm, richer feedback, and more variety between quiz question types.
Quiz first, then Today and Event detail.

## Files

| File | Purpose |
| --- | --- |
| [CLAUDE_DESIGN_PROMPT.md](CLAUDE_DESIGN_PROMPT.md) | The prompt to paste into Claude Design, plus which screenshots to attach and what to do with the results |
| [QUIZ_SOURCES_NOTE.md](QUIZ_SOURCES_NOTE.md) | Owner direction: put quiz source links behind one tappable "Sources" control instead of showing them up front |
| [references/](references/) | Screenshots that motivated the work |
| [claude-design/](claude-design/) | Claude Design handoffs: `phase-1/` Quiz, `phase-2/` Today and Event detail, each with a README spec, PNG screens and HTML source |
| [claude-design/REVIEW.md](claude-design/REVIEW.md) | Review of the handoffs and the corrections that win over them |

## Process

Status (2026-09-28): steps 1-4 are done. Both phases were exported, reviewed,
and folded into DESIGN.md section 16. Step 5 is next.

1. Run the prompt in Claude Design (Phase 1: quiz). Save exports to
   `design/claude-design/phase-1/`.
2. Review the exports against DESIGN.md and the sources note; record
   corrections in a `REVIEW.md` beside them.
3. Owner approves; update DESIGN.md.
4. Repeat for Phase 2 (Today and Event detail).
5. Implement both phases as one design and typography pass on a `claude/`
   branch. That pass also closes the tracker's UX-01, UX-02, UX-03, UX-04 and
   UX-53, so they are not done separately.

## Planned features the design must cover (owner-approved 2026-09-28)

- Image credits under Today and Event detail images (tracker P1-07), with the
  full source behind one tap.
- A "Recent days" section on Today: the featured event from each of the
  previous six dates (tracker PR-03). Needs a new backend endpoint.
- A "Test what you learned" link from Event detail into the quiz (PR-02).

All three have shipped in the current style (mobile PRs #4 and #5) and are
restyled in the design pass.
