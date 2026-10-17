# CODING_RULES.md

## 0. Purpose

These rules constrain AI-generated code for the Backrooms card-roguelike project.

They are mandatory unless the developer explicitly overrides them.

When asked to implement a feature, the AI must read:

1. `GDD.md`
2. `ARCHITECTURE.md`
3. `CODING_RULES.md`

before modifying gameplay code.

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
UI action
-> gameplay command
-> RuleResolver/domain system
-> state update
-> signal
-> UI refresh
```

UI may format values, animate changes, and display descriptions.

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

When feasible, calculate first and commit second.

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

Persistent equipment must not be mixed into normal draw/discard behavior.

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

---

## 11. Events

Events must support conditions.

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

An Insight should have alternative discovery paths when reasonable to avoid soft locks.

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

Entity behavior must be based on:

- state
- intent
- triggers
- conditions

Avoid purely random attack selection where readable intent is part of the design.

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





## Player-facing language

All player-facing game UI text should default to Simplified Chinese.

Internal code identifiers, stable IDs, filenames, class names, logs, and resource keys should remain in English unless there is a specific reason otherwise.

Examples:

- internal ID: `card_observe`
- player-facing name: `观察`

Do not use internal IDs directly as visible UI text.
