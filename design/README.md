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

## Process

1. Run the prompt in Claude Design (Phase 1: quiz). Save exports to
   `design/claude-design/phase-1/`.
2. Review the exports against DESIGN.md and the sources note; record
   corrections in a `REVIEW.md` beside them.
3. Owner approves; update DESIGN.md; implement on a `codex/` or `claude/` branch.
4. Repeat for Phase 2 (Today and Event detail).
