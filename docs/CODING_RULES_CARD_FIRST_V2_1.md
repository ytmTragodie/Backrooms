# CODING_RULES.md

> **Phase 11 当前覆盖规则（2026-10-18）**：Scene Rule／临时 Event／可调查 Objective 已分离。Board 为最多 2 Event＋1 Objective＋现有单 Entity；Event 不再使用 Explore 进度。后文 Phase 10 及更早的单 Situation 记录属于历史，不能恢复旧分类。当前完整分类与验证见 [PHASE_11_VALIDATION.md](PHASE_11_VALIDATION.md)。

## 0. Purpose

These rules constrain AI-generated code for the Backrooms card-roguelike project.

They are mandatory unless the developer explicitly overrides them.

When asked to implement a feature, the AI must read:

1. `GDD.md`
2. `ARCHITECTURE.md`
3. `CODING_RULES.md`

before modifying gameplay code.

Current authority: **CARD-FIRST V2.1 (2026-10-17)**. Read `MIGRATION_PLAN.md` as well
when touching legacy Phase 1-8 behavior. The retained v0.4 DOCX is historical,
including its old "canonical" sections. Existing code/tests do not override v2.
The original design-direction revision was documentation-only. Gameplay migration
requires a subsequent user task; REWORK A/B/C are separately authorized slices,
not blanket authorization for later migration or engine/dependency changes.

---

## 1. Environment

- Engine: Godot 4.x
- Renderer: Compatibility
- Language: GDScript only for the demo
- Primary target: Windows PC
- Version control: Git
- Text encoding: UTF-8

Do not add external plugins or packages without explicit approval.

Do not change the renderer, engine architecture, scripting language, or project-wide settings without explaining the reason first.

---

## 2. General Coding Style

Use typed GDScript wherever practical.

Prefer:

```gdscript
var hp: int = 30
var threat: int = 0
func apply_damage(amount: int) -> void:
    ...
```

Avoid unnecessary dynamic typing.

Naming:

- files: `snake_case.gd`
- variables: `snake_case`
- functions: `snake_case`
- signals: `snake_case`
- constants: `UPPER_SNAKE_CASE`
- classes: `PascalCase`
- stable content IDs: lowercase snake_case strings

Use descriptive names. Do not use unclear names such as `tmp`, `mgr2`, `thing`, `data1` except for genuinely tiny local scopes.

---

## 3. File Responsibility

One script should have one clear primary responsibility.

Examples:

Good:

- `turn_manager.gd`
- `rule_resolver.gd`
- `deck_state.gd`
- `entity_instance.gd`

Bad:

- `game_everything.gd`
- `utils.gd` containing unrelated gameplay logic

Avoid files that become dumping grounds.

If a file grows because it handles unrelated domains, split by responsibility.

Do not split tiny logic into dozens of abstract classes purely for architectural appearance.

---

## 4. UI Rules

UI contains presentation and input forwarding only.

UI must not directly mutate gameplay state.

Forbidden examples:

```gdscript
player.hp -= 5
floor.threat += 1
entity.state = "chasing"
```

inside UI button scripts.

Correct pattern:

```text
Player Card in hand + optional target/equipment selection
-> PlayCardCommand
-> RuleResolver/domain system
-> state update
-> signal
-> UI refresh
```

UI may format values, animate changes, and display descriptions.

Independent controls may only perform pure system operations: End Turn, Pause,
read-only deck inspection, settings, viewing already-public details, selecting/cancelling targets.
Investigate/Search, attacks, defense, Run/Stealth, equipment activation, light
switching and cut-out attempts must
be effects of a real NORMAL, EQUIPMENT or FLOOR_TEMPORARY Player Card in the unified hand. A zero-AP gameplay action still
needs a Player Card. A card-styled persistent button is not such a card.
Clicking a World Card may inspect/select it; it must not resolve its own action.
Inspect here means viewing already-revealed information, not revealing a new clue or Insight.
UI must not call a legacy direct gameplay API as a fallback when the hand lacks
an action. Automatic turn/floor/entity effects remain controlled domain rules.

---

## 5. No Content-Specific Hard Coding

Do not write long content-specific `if/elif` chains such as:

```gdscript
if floor_id == "level_6":
    ...
elif floor_id == "level_37":
    ...
```

or:

```gdscript
if card_id == "observe":
    ...
elif card_id == "run":
    ...
```

when the behavior can be expressed as reusable:

- tags
- conditions
- effects
- modifiers
- state transitions
- data resources

Some unique boss/set-piece behavior may require bespoke scripts later, but this must be deliberate and documented.

---

## 6. Stable IDs

All content must use stable IDs.

Examples:

```text
card_observe
card_run
equip_flashlight
entity_hound
floor_level_0
event_level6_footsteps
insight_level6_light_attracts
```

Gameplay references must use IDs or Resource references, not UI display names.

Display names may change or be localized.

---

## 7. State Mutation Rule

Never modify important game state from arbitrary scripts.

Important state includes:

- player HP
- Stress
- Threat
- Cognition
- AP
- deck/hand/discard
- board membership and Event Explore progress/milestones
- Guard and light state
- equipment durability
- entity HP/state/intent
- resource node state
- discovered Insight state
- cut-out state
- floor progression

Mutations must occur through the responsible domain system / rule-resolution path.

Every nontrivial mutation should have a clear reason for debug logging.

---

## 8. Rule Resolution

Before applying an action:

1. validate that the action is legal,
2. calculate cost,
3. evaluate conditions,
4. apply modifiers in documented order,
5. build result,
6. mutate state,
7. emit relevant signals,
8. log the result.

Do not partially mutate state before discovering that an action is invalid.

Calculate a complete plan before committing nontrivial actions. Validate the
Player Card's actual hand membership, current floor visit, runtime target kind /
identity / availability, captured card semantic, fixed equipment source and final AP cost.
AP, card movement, Explore progress, milestones, HP/Guard, Threat, equipment uses,
unique Insight/preparation rewards, board changes and RNG must commit together.
Notify observers only after the complete commit. An invalid command cannot
consume any of those resources or leave partial effects in ActionResult.

A card's single semantic and contextual legality must be declared in content. This is
not permission to silently retarget stale/removed targets or to mark no-op
placeholder effects as successful gameplay. Avoid parallel UI and resolver cost
formulas. Domain systems own their plan/commit work; RuleResolver owns order.

---

## 9. Cards

Cards should be data-driven.

A card should define data such as:

```text
id
display_name
cost
tags
conditions
effects
upgrade_data
description
```

Do not put most individual card logic in separate scripts.

Cards do not directly search the scene tree for player/entity/floor nodes.

CardData / CardInstance describe Player Cards only. Use reusable Explore, Damage,
Guard, Threat, Draw, Discard effects and add Retain/Exhaust only as needed.
Normal cards must be broadly reusable across recurring situations and must not be
keys whose only purpose is one named Event/Entity. This does **not** mean every card
must resolve meaningfully on every BoardState. Attack cards may lack a valid target in
a pure-environment encounter; investigation cards may be weak in a pure-entity turn.
Do not invent nonsensical fallback effects or successful no-ops to hide this. Control
dead-hand rate through explicit deck composition, draw/discard, single-semantic card combinations and
encounter composition. Explicit burden/curse cards must be distinguished in design.

Persistent physical equipment and World Cards must not be mixed into normal
player draw/discard behavior. World Cards keep EventData/EventInstance or
EntityData/EntityInstance; do not build one giant universal CardData type.

---

## 10. Equipment

Equipment belongs in the carry-slot system.

Equipment should normally define:

```text
id
display_name
tags
max_durability_or_charges
use_cost
effects
requirements
```

Durability/charge values belong to runtime equipment instances, not shared Resource definitions.

Do not mutate a shared `EquipmentData` Resource to store per-run durability.

Keep three run-persistent physical slots outside the deck. Active use is requested
by a Player Card effect through RuleResolver/EquipmentSystem; the carry UI only
reads or selects an item for that card. Missing/empty gear must leave a normal
card's declared semantic independent; invalid generated-card requests
fail without spending. Card/equipment cost is calculated once in the final cost,
not by independently charging both old and new input paths.
Only complete successful resolution consumes battery/durability/charges.
Passive modifiers may resolve automatically under their declared conditions;
they do not create a new active-use control.

---

## 11. Events

Events must support conditions and render as EVENT World Cards in BoardState; player-facing UI should treat them as **环境牌／局势牌 (Situation)** rather than popup event minigames.

Static EventData defines ID, name/description/tags, Objective (Explore threshold first),
Pressure/end-turn consequences, clue milestones, tag-based modifiers and reward/Insight
outcomes. Runtime EventInstance owns progress, reached milestones, known clues, Pressure
state and resolved state. Normal Player Cards advance/mitigate them through reusable
effects; no Event-owned Inspect/Search/Defend execution buttons. Rewards/milestones trigger
once even if one action crosses multiple thresholds. Never store runtime progress in
EventData or a UI copy. Unresolved Situation cards may coexist with Entities and normally
persist until resolved or invalidated by declared world rules.

Do not assume every event can always happen.

Event selection must:

1. filter invalid events,
2. apply once/repeat rules,
3. apply weights,
4. choose using controlled RNG,
5. resolve through gameplay effects.

A narrative event must not contradict known runtime state.

Example:

If the only Hound is dead and an event explicitly refers to that same Hound as alive, that event must be invalidated.

---

## 12. Cognition / Insights

Cognition is 0-5 per current FloorInstance.

Never implement `Observe -> Cognition +1` as a universal rule.

Instead:

`Observe / experiment / combat / event -> confirm unique Insight -> Cognition +1`

The same Insight can never increase Cognition twice.

An important Insight needs reachable alternative discovery paths, expressed
through Player Cards and domain consequences, to avoid soft locks. Multiple
routes must reference the same stable Insight ID. Explore itself does not add
Cognition; only a confirmed unique Insight does. Entity withdrawal and Event
completion must not duplicate an already-earned Insight or preparation reward.

---

## 13. Threat

Threat must not blindly increase every turn.

Demo principle:

- player risk-taking is the primary source,
- overstay/time pressure is a secondary source,
- floor/entity rules may modify it.

Every Threat change must include a reason.

Example log:

```text
[THREAT] +1 reason=deep_search
```

Do not hide unexplained Threat changes inside unrelated code.

---

## 14. Combat

Combat remains inside the exploration turn loop.

Do not create a separate battle scene/state that disables floor systems unless explicitly redesigned later.

The same AP, hand, equipment, Threat, Stress, and floor modifiers continue to apply.

A Situation/Event may remain active while an Entity is present. Event Pressure and Entity
Intent must resolve in the same deterministic TurnManager lifecycle. Do not add an Event
Mode, Combat Mode, second hand, second AP pool, or UI action bar for either case.

Entity behavior must be based on:

- state
- intent
- triggers
- conditions

Avoid purely random attack selection where readable intent is part of the design.
All entities keep the common runtime HP/state/intent model. Smiler may have high
HP/mitigation and resolve alive as WITHDRAWN through actual LIGHT/no-LIGHT rule
interactions. Keep this inside EntitySystem and the shared turn pipeline.
Do not infer actual LIGHT from a printed tag or failed Lighting card.
Card-mediated evasion/control/observation must not require a separate combat mode.

---

## 15. Randomness

Do not use scattered calls to global random functions for gameplay outcomes.

Use the project RNG service/state.

Every run should be able to expose a seed in debug mode.

Tests requiring deterministic outcomes must set the seed.

Visual-only randomness may be handled separately.

---

## 16. Signals

Use signals to notify, not to hide rule execution.

Good:

```text
threat_changed(old_value, new_value)
entity_state_changed(entity_id, old_state, new_state)
```

Bad:

A chain of signals where listening to one signal silently performs several unrelated game rules.

Avoid signal loops.

---

## 17. Error Handling

Fail loudly in development for invalid content.

Examples:

- missing card ID
- missing event Resource
- impossible effect target
- invalid equipment durability
- duplicate content ID

Prefer assertions / clear error logs in development over silently ignoring corrupted state.

Do not crash the game for normal player-invalid actions; return a validation result instead.

---

## 18. Comments

Comments should explain **why**, invariants, or non-obvious rule behavior.

Do not comment every obvious line.

Good:

```gdscript
# Fresh events are never reshuffled. Once exhausted,
# the floor switches permanently to its residual pool.
```

Bad:

```gdscript
# Increment threat by one.
threat += 1
```

---

## 19. Functions

Prefer small, clear functions.

A function should normally perform one conceptual task.

Avoid deeply nested conditionals.

Prefer early returns:

```gdscript
if not action.is_valid:
    return result
```

Do not create one-line wrapper functions with no semantic value purely to satisfy an abstraction pattern.

---

## 20. Performance

Do not prematurely optimize.

The demo is turn-based and content-light.

Prioritize:

1. correctness,
2. clarity,
3. determinism,
4. debuggability.

Avoid per-frame gameplay rule evaluation when the rule only needs to run on state changes or turns.

Use `_process()` only for presentation or systems that truly require frame updates.

---

## 21. Scene Tree Access

Avoid fragile scene-tree traversal.

Do not repeatedly use paths such as:

```gdscript
get_node("../../../../../Player")
```

Prefer:

- exported references
- composition
- explicit initialization
- controlled managers/services
- signals

Gameplay data objects should not depend on scene paths.

---

## 22. Autoloads

Use Autoload sparingly.

Allowed candidates may include:

- app-level game flow
- content database
- RNG service
- audio service

Do not turn every manager into a global singleton.

Run-specific state should not automatically become global if it can be owned by the active run scene/controller.

---

## 23. Shared Resources

Remember that Godot Resources are shared references.

Never store mutable per-instance runtime state in shared data Resources.

Bad:

```text
CardData.current_cost
EquipmentData.current_durability
EntityData.current_hp
```

Good:

```text
CardData.base_cost
CardInstance.current_cost

EquipmentData.max_durability
EquipmentInstance.current_durability
```

---

## 24. Tests

Every implemented gameplay rule should include or update tests when practical.

At minimum test:

- normal path
- one invalid path
- one edge case

Examples:

- play card with enough AP
- reject card without enough AP
- reject duplicate Insight trigger

When fixing a gameplay bug, add a regression test if feasible.

For future v2 migration, add or adapt tests for:

- cards are not single-named-content keys; temporary missing targets are handled honestly rather than through fake no-op success;
- card tags modifying Situation/Event Objective progress and thresholds/rewards firing once;
- Situation Pressure resolving through the same TurnManager as Entity Intents;
- Situation-only, Entity-only and mixed boards using the same AP/hand pipeline;
- Event/Entity World Cards never entering player piles;
- one authoritative BoardState owner and no UI/runtime shadow state;
- stale, foreign-visit, resolved and removed target rejection without any spending;
- card + equipment AP/charge + domain effects committing before notification;
- card-based Smiler withdrawal and shared unique Insight alternative routes;
- card-mediated exit access despite bad draws, exhausted resources and missing events;
- no independent gameplay-button or direct-command bypass after the cutover.

Classify existing Phase 1-8 assertions before changing them: preserve invariants,
adapt callers, explicitly retire deprecated button/no-op expectations. Do not
rewrite tests to legitimize an accidental regression or claim v2 complete merely
because the legacy suite passes. Documentation-only tasks use documentation/scope
checks; they do not imply gameplay migration or require new gameplay tests.

---

## 25. AI Task Protocol

Before coding, the AI must:

1. read relevant sections of GDD, Architecture, and Coding Rules,
2. inspect existing related files,
3. state the smallest implementation scope,
4. identify files that will be changed or created,
5. avoid unrelated refactors.

After coding, the AI must report:

### Changed
Exact files added/modified.

### Behavior
What now works.

### Validation
Exact steps/tests used to verify it.

### Known limitations
Anything intentionally not implemented.

Do not claim a feature is complete without verification.

---

## 26. AI Change Scope

For one task, prefer the smallest coherent patch.

Do not:

- rename unrelated files,
- reformat the whole repository,
- rewrite working systems without need,
- change public APIs casually,
- add speculative features,
- expand the GDD scope,
- create multiple alternative implementations.

If a requested change requires architectural modification, explain the conflict before changing the architecture.

---

## 27. No Silent Design Decisions

If implementation requires choosing between materially different game behaviors that the GDD does not specify, do not silently invent permanent rules.

For minor implementation details, choose the simplest reasonable behavior and mark it clearly.

For major gameplay behavior, surface the unresolved decision to the developer.

Examples of major design decisions:

- adding a new resource
- changing AP economy
- changing deck reshuffle rules
- making Cognition mandatory to leave
- making all equipment cards
- creating a separate combat mode

---

## 28. Definition of Done

A gameplay task is done only if:

- it runs,
- the implemented behavior matches the current GDD,
- no unrelated feature was broken,
- relevant debug logs exist,
- relevant test(s) pass or manual validation steps are documented,
- no obvious duplicated rule implementation was introduced.

Visual polish is not required unless the task is specifically visual.

---

## 29. Current Demo Priority

Always optimize decisions for the current playable loop:

```text
Enter Level 0
-> draw / act / explore
-> gain knowledge/resources
-> prepare and perform cut-out
-> enter Level 6
-> interact with threat/entity
-> fight / evade / explore
-> cut out again
-> show run result
```

If a proposed abstraction or feature does not help this loop, defer it.





## 30. Board ownership and World Card presentation

Use the minimum floor-local BoardState in ARCHITECTURE.md: one active Situation/Event slot
and zero to two active Entities as design capacity. Support Situation-only, Entity-only,
and mixed Situation+Entity board compositions without mode switching. BoardState owns the active
EventInstance/EntityInstance references. FloorState keeps pools, flags, resources,
cut-out and floor-local temporary defense/light. DeckState owns Player Cards only.
A temporary legacy alias must return the same board instances, never a second
writable collection or copied HP/progress/intent.

Keep shared rendering/targeting small: world kind, floor-scoped runtime instance
key, display information and a read-only domain reference. Definition ID alone is
not a runtime target identity. Do not introduce WorldCardData mega-resources,
parallel WorldCardInstance state, a second combat state, or future board types
just to make unlike domain objects inherit the same card base class.

## 31. Deprecated pre-v2 assumptions

The old basic-interaction fallback, direct equipment use, direct landmark/
encounter/light-switch and cut-out buttons are deprecated design, even while
still executable in the Phase 1-8 build. Their internal domain planning can be
reused; their public bypass paths are REMOVE LATER after card equivalents and
failure/anti-soft-lock tests exist. See MIGRATION_PLAN.md, not old tests or
v0.4 wording, for the retirement conditions.

## Player-facing language

All player-facing game UI text should default to Simplified Chinese.

Internal code identifiers, stable IDs, filenames, class names, logs, and resource keys should remain in English unless there is a specific reason otherwise.

Examples:

- internal ID: `card_observe`
- player-facing name: `观察`

Do not use internal IDs directly as visible UI text.

## Single-Semantic Card Rule

One playable card has one clear primary gameplay semantic. Contextual numeric modifiers,
conditional rewards and legal target selection are allowed; unrelated action/mode lists
are not. Different verbs require separate CardData definitions. UI never presents a verb
selector or reinterprets a card into a different subsystem. Right-click is read-only.

## Current interaction constraints

- Remove CardData.actions and generic mode/branch interpreters. PlayCardCommand may identify
  a real card, captured definition, visit Board and Event/Entity target; it cannot select
  a mode, arbitrary equipment item or resource node. Reject stale definition replacements.
- Search integrates finite collection into its normal resolution, without discovery/loot
  mode inputs. Preserve once-only node rewards and failure atomicity with Explore/Threat/AP.
- Smiler spawns through declared world conditions in EntitySystem, not pursuit input.
  Commit old target damage/state before follow-up slot replacement. Shared HP and alive
  withdrawal behavior remain unchanged; Situation clue is an alternate unique Insight route.
- Lighting and Extinguish are distinct equipment definitions. Replace the same opportunity
  according to actual LIGHT, never open a toggle menu or add another hand slot. Lighting
  success spends one battery; Extinguish spends none, including after the last battery.
- Crowbar and Water remain dedicated generated cards. Physical counters stay exclusively
  on EquipmentInstance. At most one new equipment opportunity per global turn; a flashlight
  definition replacement is not another generated instance. No normal pile pollution.
- Remove preparation card/template/generator and player-selected Prepare. Declared clue and
  unique Insight rewards improve CutOutState automatically, capped and triggered once.
- Retained rushed exit appears at minimum availability, upgrades in place to safe, survives
  failure and is removed only after successful transition. Next floor creates its own visit
  opportunity. Preserve one AP pool, hand, RNG and lifecycle throughout.
- Every validation/planning failure preserves all gameplay state, card definition/position,
  source budgets, equipment uses and RNG; failure result contains no partial effects.

Old menu, loot/pursuit/landmark/preparation and forced-branch contracts are retired.
Snapshot positions and exact old sentences are recorded in CARD_INTERACTION_CLEANUP_AUDIT.md;
quoted history never authorizes restoring those paths.

## Phase 9 earned rewards

- All active world targets remain exact visit-scoped references. Card target kinds/states are data;
  incompatible explicit selections must be disabled and rejected, never redirected.
- Retire inactive entities only after final state/reward commit; keep resolved IDs for scheduling,
  not a second HP owner or dead selectable board card.
- Reward opportunities are data-triggered and run-owned. Plan deterministic choices before mutation.
  The reward UI sends CardRewardCommand to consume an actual pending opportunity, not a free deck editor.
- Only validated NORMAL definitions/instances enter add/upgrade/remove flows. Add to existing discard;
  upgrade the selected instance by definition replacement; remove from its existing zone. Never mutate
  shared CardData or rebuild the deck. Invalid/stale/double claims preserve state/RNG/notifications.
- Pending choice pauses normal lifecycle. Empty upgrade/removal candidates can continue; removal keeps
  at least five normal cards. No shop, currency or Phase 10 content is implied by this foundation.

## Phase 10 constraints

- Ordinary production Situation definitions cannot offer routine upgrades/removals; those consume
  one optional visit-local Safe Point. Every final choice requires exact current visit/point and
  instance identity. Preview/postpone never consume state; failed choices preserve everything.
- Rare card rewards stay explicit in major content; do not add a global hard-coded reward budget.
- Resource search plans restoration; EquipmentSystem commits physical counters. Never consume a
  finite cache with no useful reward or create material/crafting clutter.
- Content timing, exit fallback and Threat danger are floor data; UI uses domain damage/legality.
  Retain fallback remains independent of specific events/resources/Insight and survives bad hands.
- Run summary/debug metrics record committed facts before transitions, never scene signal chains.
- Preserve earlier coverage using explicit historical balance fixtures and verify current production
  separately. A windowless run is not evidence of rendered-window/manual visual validation.

## Phase 11 current constraints (supersedes progress-Event passages)

- EventData/Instance are temporary category/timer/condition models. Explore/milestones belong to ObjectiveData/Instance/System, never Event HP.
- Board uniquely owns up to two Events, one Objective and the existing single Entity. Target commands accept only actual Objective/Entity instances; Event row and Scene Rules are read-only.
- EventChange planning must not mutate state; failed card resolution cannot change timers, condition counts or rewards. Aggregate environmental damage spends shared Guard before existing entity intent.
- Omen spawning must use EntitySystem and defer occupied slots. Current six-layer production uses Omen; historical scheduling fixtures are not a second player input.
- Assets use stable manifest IDs and res:// paths. Missing textures fall back, missing audio is silent. No UI asset loader may mutate domain state or require gameplay edits to swap art.
