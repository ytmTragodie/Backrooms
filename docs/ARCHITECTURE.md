# ARCHITECTURE.md

## 0. Purpose

This document defines the technical architecture for the Backrooms card-roguelike demo.

It is a **hard constraint for AI coding**. If generated code conflicts with this document, this document wins unless the developer explicitly changes it.

The current goal is a small, playable vertical slice, not a production-scale framework.

---

## 1. Technical Baseline

- Engine: Godot 4.x
- Renderer: Compatibility
- Language: GDScript
- Target platform: Windows PC first
- Presentation: 2D UI + static/animated environment presentation
- Persistence: local save files only
- Networking: none
- Mod support: none for the demo
- Primary design source: current GDD Demo Baseline

Do not introduce C#, native extensions, ECS frameworks, third-party dependency injection frameworks, or external runtime dependencies unless explicitly requested.

---

## 2. Core Architectural Principles

### 2.1 Data-driven content

Cards, equipment, floors, entities, events, insights, rewards, and floor modifiers must be represented as data wherever practical.

Do not hard-code content-specific logic into UI scenes or global managers.

Preferred model:

- `CardData`
- `EquipmentData`
- `FloorData`
- `EventData`
- `EntityData`
- `InsightData`
- `EffectData`
- `ConditionData`

Godot custom `Resource` files (`.tres`) are the preferred authoring format.

Core rule:

> Code defines how a rule works. Data defines which content uses that rule.

---

### 2.2 State and presentation are separate

UI must never be the source of truth.

Game state lives in domain state objects such as:

- `RunState`
- `FloorState`
- `CombatState`
- `DeckState`
- `EntityInstance`
- `EquipmentInstance`

UI reads state and sends player commands.

UI must not directly change HP, AP, Threat, Cognition, cards, entity HP, equipment durability, or cut-out state.

---

### 2.3 State changes must be traceable

All meaningful game-state modifications must pass through a controlled resolution path.

Preferred flow:

`PlayerCommand -> RuleResolver -> EffectResult -> State Mutation -> Signals -> UI Refresh`

Examples of `PlayerCommand`:

- play card
- use equipment
- inspect
- search
- loot
- retreat
- attempt cut-out
- end turn

Examples of `EffectResult`:

- damage dealt
- HP lost
- AP spent
- Threat changed
- Stress changed
- Cognition changed
- entity state changed
- insight discovered
- equipment durability changed
- card moved
- cut-out result

Avoid arbitrary cross-system state edits.

---

## 3. High-Level Module Layout

Recommended structure:

```text
res://
├── scenes/
│   ├── main/
│   ├── run/
│   ├── floor/
│   ├── cards/
│   ├── entities/
│   └── ui/
│
├── scripts/
│   ├── core/
│   ├── run/
│   ├── turns/
│   ├── rules/
│   ├── cards/
│   ├── equipment/
│   ├── floors/
│   ├── events/
│   ├── entities/
│   ├── combat/
│   ├── cutout/
│   ├── save/
│   └── ui/
│
├── data/
│   ├── cards/
│   ├── equipment/
│   ├── floors/
│   ├── events/
│   ├── entities/
│   └── insights/
│
├── tests/
│
├── docs/
│   ├── GDD.md
│   ├── ARCHITECTURE.md
│   └── CODING_RULES.md
│
└── project.godot
```

Do not create deeply nested folders without a concrete need.

---

## 4. Core Runtime Objects

### 4.1 RunState

Owns the persistent state for one run.

Typical fields:

```text
player_hp
player_max_hp
stress
supply
current_floor_id
depth_band
deck_state
equipment_slots
discovered_knowledge
run_flags
rng_seed
```

`RunState` must not contain UI references.

`RunState` must not implement floor-specific rules.

---

### 4.2 TurnManager

Owns turn lifecycle only.

Responsibilities:

1. Start turn.
2. Restore AP.
3. Draw hand to target hand size.
4. Trigger start-of-turn effects.
5. Accept actions while AP/rules allow.
6. Resolve end-turn effects.
7. Resolve entity intents.
8. Resolve floor/Threat/time effects.
9. Advance turn counter.

It must not contain card-specific or floor-specific `if` chains.

---

### 4.3 RuleResolver

`RuleResolver` is the primary gameplay rule-resolution boundary.

Responsibilities:

- validate commands
- calculate costs
- resolve conditions
- apply modifiers
- construct effect results
- enforce resolution order
- produce structured logs

Example resolution order:

```text
base action/card/equipment rule
-> player modifiers
-> equipment modifiers
-> floor modifiers
-> entity reactions
-> global state modifiers
-> final result
```

When a new rule can be represented through existing conditions/effects, add data rather than adding another hard-coded branch.

---

### 4.4 CardSystem

Responsibilities:

- deck
- draw pile
- hand
- discard pile
- exhaust/remove-for-floor/run if later needed
- draw
- discard
- reshuffle
- play validation

Cards represent actions, techniques, memories, and other draw-based opportunities.

Persistent equipment does **not** belong in the normal draw pile.

---

### 4.5 EquipmentSystem

Equipment occupies the carry slots.

Demo baseline:

- 3 carry slots
- equipment may use durability, charges, battery, or consumable count
- using equipment normally costs AP
- equipment can modify card effects or unlock actions

Examples:

- flashlight
- crowbar
- recorder

Equipment state belongs to the run, not the hand.

Cards may reference equipment requirements through tags/conditions.

---

### 4.6 FloorSystem

Owns the current `FloorState`.

A floor definition and a floor instance are different concepts.

`FloorData` describes the level archetype.

`FloorState` describes the current generated visit.

Typical FloorState fields:

```text
floor_id
turn_count
threat
cognition
fresh_event_deck
residual_event_pool
resource_nodes
active_entities
discovered_insights
landmarks
cutout_state
floor_flags
```

Returning to the same Level usually creates a new FloorState unless a landmark is explicitly persistent.

---

### 4.7 EventSystem

Events are conditional content, not unconditional scripts.

Every event must be able to define:

```text
id
conditions
weight
once_per_instance
repeatable
effects
tags
```

Demo flow:

- generate 5 Fresh Events from a floor's 6-event candidate pool
- Fresh Events are no-repeat during that floor instance
- when exhausted, use Residual Events
- Residual Events may repeat and generally provide lower rewards / higher pressure

An event whose conditions are false must not be selectable.

---

### 4.8 Insight / Cognition System

Cognition is one floor-local value from 0 to 5.

It means:

> how well the player understands the current situation.

Cognition does not automatically increase from repeatedly playing an Observe card.

Cognition increases when a unique `Insight` is confirmed.

Rules:

- each FloorInstance has up to 5 major insight slots
- each insight can have multiple discovery paths
- the same insight cannot increase Cognition twice
- killing, missing, or bypassing one event/entity must not permanently soft-lock required understanding
- Cognition 5 is optional mastery, not a requirement to leave the floor

---

### 4.9 EntitySystem

All entities share a common runtime model.

Recommended base fields:

```text
entity_id
hp
max_hp
state
intent
distance_state
tags
status_effects
alive
```

Entities may be:

- normally killable
- elite
- rule-focused / practically unkillable
- boss

HP is a common technical model, but HP reaching zero is not the only valid solution.

Entity behavior must be modeled through state + intent + triggers.

Do not implement each entity as an unrelated monolithic script if reusable state/condition/effect components can express the behavior.

---

### 4.10 CombatSystem

Combat does not switch to a separate game mode.

Entities remain inside the exploration turn loop.

The player continues to use the same:

- AP
- hand
- equipment
- Threat
- Stress
- floor rules
- cut-out system

The presence of an entity changes action priorities but does not freeze exploration systems.

Demo numeric anchors:

```text
Player HP: 30
AP per turn: 3
Hand target: 5

basic attack: 2-4 damage
strong/conditional attack: 5-9 damage
normal block: 4-6

weak entity HP: 8-12
standard entity HP: 16-24
elite HP: 30-45
boss/special: higher or rule-gated
```

These are tuning anchors, not architectural constants.

---

### 4.11 CutOutSystem

Cut-out is the primary floor-transition mechanic.

Internally, it may track:

- cut-out stability
- destination knowledge
- destination candidates
- forced-cut risk
- discovered exits / landmarks

The UI should present this narratively rather than exposing raw debug values by default.

Examples:

- no spatial response
- unstable
- viable
- stable
- destination partially identified
- destination confirmed

Critical anti-soft-lock rule:

> The player must always retain some possible route to leave a normal floor, even if safe preparation failed. A rushed or forced cut-out may be dangerous, but the run must not become permanently stuck because one event did not appear.

---

## 5. Floor Network and Run Progression

The run uses a controlled-random floor network rather than a fixed linear sequence.

Conceptual depth bands:

```text
Band 0 - entrance / edge
Band 1 - stable survival spaces
Band 2 - anomalous deep spaces
Band 3 - terminal / highly unstable spaces
```

The player can move laterally, deeper, and occasionally backward.

Floor transition weights may depend on:

- current floor
- depth band
- cut-out preparation
- discovered knowledge
- run flags
- special items
- story conditions

Do not hard-code a fixed `Level0 -> Level1 -> Level6` progression outside of tutorial/demo scaffolding.

---

## 6. Endings

Demo code should support the idea that a run can end for multiple reasons.

Do not couple `RunEnd` exclusively to defeating a final boss.

Possible end categories:

- death
- reality escape
- faction/settlement ending
- assimilation ending
- special/hidden ending

For the demo, an explicit placeholder run-complete condition is acceptable.

Keep the `RunResult` model generic enough for multiple endings later.

---

## 7. Signals and Communication

Use Godot signals for event notification, not for arbitrary hidden business logic.

Good examples:

```text
hp_changed
stress_changed
threat_changed
cognition_changed
hand_changed
entity_intent_changed
entity_defeated
equipment_changed
floor_changed
turn_started
turn_ended
```

Signals announce that something happened.

They should not become a second invisible rule engine.

Avoid circular signal chains.

---

## 8. Randomness

All gameplay randomness should route through one controlled RNG service or state-owned RNG.

Do not call random functions throughout unrelated scripts.

Reasons:

- reproducible bugs
- seeded runs
- deterministic tests
- easier AI debugging

A bug report should ideally be reproducible from an RNG seed.

---

## 9. Save / Serialization Boundary

Do not serialize scene-node references.

Persist only data/state needed to reconstruct the run.

Prefer stable IDs:

```text
card_id
equipment_id
floor_id
entity_id
event_id
insight_id
```

Content files resolve IDs back to Resources.

Save format is not a current demo priority, but architecture must not make later serialization impossible.

---

## 10. Logging and Debugging

Gameplay systems must produce readable structured logs in debug builds.

Examples:

```text
[TURN] start turn=4 ap=3
[CARD] play observe cost=1
[INSIGHT] level6_light_behavior discovered cognition=3
[THREAT] +1 reason=deep_search total=5
[ENTITY] hound state WATCHING -> CHASING reason=player_ran
[EQUIPMENT] crowbar durability 3 -> 2
[CUTOUT] attempt stability=2 result=unstable_success
```

Do not rely on scattered print statements with no category or context.

---

## 11. Testing Boundaries

At minimum, game rules should be testable without polished UI.

High-priority tests:

- AP resets to expected amount.
- hand draws to target size.
- Fresh Events do not repeat.
- Residual Events begin after Fresh Events are exhausted.
- an Insight cannot trigger twice.
- Cognition cannot exceed 5.
- resource nodes cannot be looted after depletion.
- Hound enters the correct state after trigger actions.
- equipment durability decreases correctly.
- a broken/empty equipment item cannot be used improperly.
- cut-out always retains an anti-soft-lock path.
- entity conditions invalidate impossible events.
- HP reaching 0 ends the run.
- seeded RNG reproduces the same result.

---

## 12. Demo Scope Boundary

Phase A should prove the core loop, not content quantity.

Target content:

- 1 playable faction: M.E.G.
- 2 floors: Level 0 and Level 6
- 2 entities: Hound and Smiler
- about 18-24 cards
- about 3-4 equipment items
- Fresh + Residual events
- Insight/Cognition
- Threat
- combat
- equipment carry slots
- cut-out
- simple run result

Out of scope unless explicitly added:

- all five factions
- full meta progression
- full multi-ending story content
- dozens of floors
- elaborate crafting
- procedural 3D environments
- multiplayer
- online services
- mod support
- final visual polish

---

## 13. Architecture Decision Rule

When uncertain, choose the option that is:

1. easiest to understand,
2. easiest to test,
3. least coupled,
4. data-driven where content variation is expected,
5. sufficient for the current demo.

Do not design for hypothetical scale before the demo proves the core loop.
