# AGENTS.md

## Project

This repository contains a Godot 4.x card-roguelike game prototype set in the Backrooms.

Current goal:
Build a playable vertical slice proving the core loop:

Level 0
-> explore
-> gain insight/resources
-> prepare cut-out
-> Level 6
-> entity encounter
-> fight / evade
-> cut out
-> run result

## Required context

Before modifying gameplay code, read:

- `docs/GDD.md`
- `docs/ARCHITECTURE.md`
- `docs/CODING_RULES.md`

These documents are authoritative.

Priority when instructions conflict:

1. Current user task
2. `AGENTS.md`
3. `docs/ARCHITECTURE.md`
4. `docs/CODING_RULES.md`
5. `docs/GDD.md`
6. Existing implementation assumptions

If the implementation conflicts with the documents, do not silently choose a new design.

## Tech stack

- Godot 4.x
- Compatibility renderer
- GDScript
- Windows PC first
- Git

## Development principles

- Work in small, testable increments.
- Do not implement unrelated features.
- Avoid speculative abstractions.
- Prefer data-driven content.
- UI is never the source of truth.
- Gameplay state changes must follow the architecture.
- Do not hard-code floor/card/entity-specific behavior if reusable data can express it.
- Do not introduce plugins or dependencies without approval.

## Task workflow

Before coding:

1. Inspect the relevant existing files.
2. State the intended minimal change.
3. Identify files to modify.
4. Check architectural compatibility.

After coding:

1. Run relevant tests/checks.
2. Run the project if possible.
3. Inspect errors.
4. Report changed files.
5. Report verification performed.
6. Report known limitations.

## Scope

Current Phase A only includes:

- M.E.G.
- Level 0
- Level 6
- Hound
- Smiler
- 18-24 cards
- 3-4 equipment items
- Threat
- Cognition / Insight
- Fresh / Residual Events
- basic combat
- cut-out
- simple run result

Do not implement later-scope content unless explicitly requested.