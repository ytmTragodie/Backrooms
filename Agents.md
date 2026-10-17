# AGENTS.md

## Project

This repository contains a Godot 4.x card-roguelike game prototype set in the Backrooms.

**Current authoritative direction: CARD-FIRST V2 (2026-10-17).**
Phase 1-8 is the existing legacy prototype, not proof that v2 is implemented.
The design-direction task changes documentation only. Do not migrate gameplay,
content Resources, scenes, tests, or project settings without a subsequent task.

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

## Card-First v2 constraints

- Player-initiated gameplay actions must originate from Player Cards drawn from
  the player's deck. Only pure system controls such as End Turn, Pause, read-only
  deck inspection, and settings may remain independent controls.
- Inspect, Search, Deep Search, Attack, Guard, Run, Stealth, active equipment use,
  light switching, looting, landmark investigation, encounter interaction,
  cut-out preparation and cut-out attempts are gameplay actions, even at zero AP.
  They must not gain a parallel standalone gameplay-button path.
- Every normal deck card needs useful baseline behavior using reusable mechanics
  such as Explore, Damage, Guard, Threat, Draw and Discard. Retain/Exhaust may be
  added when needed. A missing specific Event, Entity or equipment item must not
  turn a normal card into a dead card or a successful no-op.
- Events and Entities are World Cards in a separate board zone. They never enter
  the player's hand, draw pile or discard pile.
- Introduce a small, floor-local BoardState concept: one active Event slot and
  zero to two active Entities. This is a design capacity, not authorization to
  implement multi-entity combat or a universal board framework in this task.
- Keep EventData/EventInstance and EntityData/EntityInstance. CardData describes
  Player Cards; do not merge all domains into one universal CardData hierarchy.
- Three physical equipment slots remain run-persistent and outside the deck.
  Cards express how equipment is used; owning equipment does not grant an
  independent active-use button. Failed resolution cannot consume its uses.
- Keep one exploration/combat turn loop, unique Insight rewards, finite resources,
  common entity HP with behavioral solutions, and an anti-soft-lock exit route.
  Exit availability must be solved within the card rules, not by restoring a
  gameplay-button exception.
- Player-facing text defaults to Simplified Chinese; internal identifiers remain
  English. Preserve typed GDScript, Compatibility renderer and no unapproved plugins.

## Required context

Before modifying gameplay code, read:

- `docs/GDD.md`
- `docs/ARCHITECTURE.md`
- `docs/CODING_RULES.md`
- `docs/MIGRATION_PLAN.md` when assessing or migrating the legacy implementation

These documents are authoritative.

Priority when instructions conflict:

1. Current user task
2. `AGENTS.md`
3. `docs/ARCHITECTURE.md`
4. `docs/CODING_RULES.md`
5. `docs/GDD.md`
6. Existing implementation assumptions

`docs/GDD.md` is the current Card-First v2 design source. The retained
`docs/Backrooms_Card_Roguelike_GDD_v0.4_Demo_Baseline.docx` is historical reference;
its old claims of being canonical do not override these Markdown documents.
Readme.md describes the legacy build and does not authorize deprecated mechanics.
Unresolved choices in MIGRATION_PLAN.md are not approved implementation rules.

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
- Player Cards are the gameplay action entry; World Cards are board content/targets.
- Keep one owner for runtime state; board rendering must not duplicate it.
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
