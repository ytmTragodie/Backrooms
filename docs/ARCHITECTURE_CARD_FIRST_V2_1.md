# ARCHITECTURE.md

> **Phase 11 当前覆盖规则（2026-10-18）**：Scene Rule／临时 Event／可调查 Objective 已分离。Board 为最多 2 Event＋1 Objective＋现有单 Entity；Event 不再使用 Explore 进度。后文 Phase 10 及更早的单 Situation 记录属于历史，不能恢复旧分类。当前完整分类与验证见 [PHASE_11_VALIDATION.md](PHASE_11_VALIDATION.md)。

## 0. Purpose

This document defines the technical architecture for the Backrooms card-roguelike demo.

It is a **hard constraint for AI coding**. If generated code conflicts with this document, this document wins unless the developer explicitly changes it.

The current goal is a small, playable vertical slice, not a production-scale framework.

**Authoritative direction: CARD-FIRST V2.1, 2026-10-17.** This revision defines the
migration target. REWORK A/B/C implement the existing demo input migration, including resources,
carried equipment, Smiler and cut-out. See the migration plan for exact scope and remaining unused legacy data.
Read `GDD.md` for design and `MIGRATION_PLAN.md` for KEEP / ADAPT / DEPRECATE /
REMOVE LATER classifications. The retained v0.4 DOCX and legacy README flows do
not override these rules. Repository instruction priority remains as in AGENTS.md.

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
- Primary design source: `docs/GDD.md` — CARD-FIRST V2

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
- `BoardState` (floor-local World Card zone)
- `DeckState` (Player Cards only)
- `EntityInstance`
- `EquipmentInstance`

UI reads state and sends player commands.

UI must not directly change HP, AP, Threat, Cognition, cards, entity HP, equipment durability, or cut-out state.

---

### 2.3 State changes must be traceable

All meaningful game-state modifications must pass through a controlled resolution path.

Preferred flow:

`Player Card + target selection -> PlayCardCommand -> RuleResolver -> ActionResult -> State Mutation -> Signals -> UI Refresh`

Player gameplay commands originate from an actual Player Card in the current hand,
with optional world-target and carried-equipment references. Inspect, Search,
Deep Search, Attack, Guard, Run, Stealth, loot, equipment activation, light switching,
and cut-out attempts are fixed card semantics. Finite resource collection belongs
to Search outcomes; encounter scheduling and preparation gains are automatic world
rules, not player-selected verbs or independent UI commands.

End Turn remains a lifecycle command. Pause, read-only deck inspection, settings,
viewing already-public card details, and choosing/cancelling targets are pure system controls.
They must not grant gameplay effects. Automatic entity/floor/turn triggers are
rule resolution, not additional player inputs. Zero AP is not a system-control exemption.
Revealing new clues/Insight is a gameplay effect, not a free details-view operation.

REWORK C removes ExplorationCommand / UseEquipmentCommand and their public
TurnManager/RuleResolver entry points. Internal domain plan/commit helpers remain;
only PlayCardCommand initiates gameplay, while resolve_end_turn handles the lifecycle.

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
floor_state
depth_band
deck_state
equipment_slots
discovered_knowledge
run_flags
rng_seed
```

`RunState` must not contain UI references.

`RunState` must not implement floor-specific rules.
It owns the current FloorState reference, player DeckState and EquipmentInstances.
A current-floor ID may be a derived read, never another independently writable owner.

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

REWORK B implements one explicit end-turn order: plan all consequences, then commit
Situation Pressure -> Entity intent -> floor overstay -> temporary Guard/light/observation
cleanup. Pressure consumes Guard first; the entity uses only the remainder. Lethal
Pressure skips the entity intent; cleanup still runs and no next turn starts. If alive,
the same TurnManager discards NORMAL cards, removes unretained generated cards,
keeps Retain, advances counters/restores 3 AP and schedules Fresh. CardSystem reserves
floor-card slots, fills the base hand to five and appends at most one eligible equipment
action for that global turn, then observers are notified. Scene-tree signal order never determines effects.

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
Player Card fixed semantic + declared target
-> player modifiers
-> selected equipment requirements/modifiers
-> floor and active Event tag/condition modifiers
-> Entity reactions to actual resolved effects/tags
-> global state modifiers
-> complete ActionResult / planned mutations
-> one synchronous commit
-> signals / UI refresh
```

When a new rule can be represented through existing conditions/effects, add data rather than adding another hard-coded branch.

Validate card ownership/hand membership, floor visit, target identity and lifecycle,
selected equipment, final costs and complete effect legality before any gameplay
write. Context may modify the same semantic, never choose an unrelated action.
An explicit stale/invalid target is rejected, never silently redirected.
AP, card movement, Explore, HP/Guard, equipment uses, Insight rewards, entity
transitions and RNG advancement commit together. Failure changes none of them.
Domain systems plan/commit their own effects; RuleResolver coordinates order.
Do not replace this boundary with a new UI rule engine or a giant generic interpreter.

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

CardData / CardInstance represent Player Cards with NORMAL / EQUIPMENT / FLOOR_TEMPORARY sources.
DeckState.hand is their single authoritative hand collection. Only NORMAL participates
in draw/discard/reshuffle and permanent deck counts. CardSystem owns pile operations, not Event
or Entity resolution. RuleResolver performs authoritative play/cost validation.

Use small reusable effects: Explore, Damage, Guard, Threat, Draw, Discard;
Retain/Exhaust only as needed. Normal cards must serve a recurring class of situations
and must not be single-event/single-entity keys. They do **not** need to be effective
against every BoardState: an attack may legitimately have no target during a pure
environment turn. Do not fake universality with successful no-ops, placeholder values
or nonsensical target conversions. Dead-hand mitigation belongs to explicit deck
composition, draw/discard rules, single-semantic card combinations and encounter composition.

World Cards never enter or count toward the player's draw/hand/discard/exhaust
zones. Do not generalize CardSystem to shuffle EventInstances or EntityInstances.

Persistent equipment does **not** belong in the normal draw pile. EquipmentData.action_card
declares a generated CardData; its CardInstance references the actual EquipmentInstance.
CardSystem rotates eligible carry slots deterministically, at most one generation per
global turn (start of turn, or floor entry if the budget is unused). It is an explicit
extra slot beyond the five-card base target, so the current hand maximum is six.
Unplayed equipment actions expire at end turn; Crowbar/Water are removed after use without discard.
Flashlight uses two separate definitions in one opportunity: LIGHT off exposes Lighting,
LIGHT on replaces it with Extinguish. Neither replacement adds an instance or generation
budget. Extinguish uses AP and no battery; last-battery Lighting still exposes Extinguish.
The same equipment may generate a new instance on a later turn while usable.
Floor-generated retained exit cards occupy the five base slots; temporary shortages
defer generation until space is available. Start-of-turn reserves them before normal draw.

---

### 4.5 EquipmentSystem

Equipment occupies the carry slots.

Demo baseline:

- 3 carry slots
- equipment may use durability, charges, battery, or consumable count
- active equipment use is requested by a Player Card effect
- equipment generates an action CardInstance in the same visible hand; no normal-card equipment menu branch remains
- the final card cost includes declared equipment-related cost; do not blindly
  add the old standalone-use AP charge a second time

Examples:

- flashlight
- crowbar
- recorder

Equipment state belongs to the run, not the hand.

Cards may reference equipment requirements through tags/conditions.
EquipmentData remains a static physical-item definition and EquipmentInstance
owns remaining battery/durability/charges. EquipmentSystem validates and plans
uses during card resolution; it has no independent UI active-use pathway.
Only a fully successful action decrements uses. Missing or empty optional gear
cannot invalidate a normal card's entire baseline.
The carry-slot UI may inspect/select gear for the current card; rendering an item
as a card-like tile does not make it an actual generated CardInstance in DeckState.hand.

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
board_state
discovered_insights
landmarks
cutout_state
floor_flags
```

Returning to the same Level usually creates a new FloorState unless a landmark is explicitly persistent.
BoardState belongs to this floor visit and owns the active Event/Entity instances
as specified in section 4.12. FloorState must not retain a second writable copy
of current_event or active_entities after migration. Legacy properties may only
be temporary derived aliases to the exact same instances, with removal recorded.
Event candidate pools/seen IDs remain floor-local scheduling state, not a second
board of active instances. Resource and cut-out state remain in their domains.

---

### 4.7 EventSystem / ObjectiveSystem / Scene Rules (Phase 11)

These three domains replace the old progress-Situation contract. EventData defines a temporary DEBUFF, OMEN or OPPORTUNITY. EventInstance owns remaining_turns, matching_actions, checked_turn and retired only: no Explore HP or target actions. EventChange is a private typed mutation plan in ActionResult.

EventSystem validates definitions/board, sums active tag AP modifiers, plans successful-card conditions and actual LIGHT/NOISE reactions, plans end-turn pressure/countdown/expiration, then commits current-instance changes. Rewards/Insight use existing systems and the same private RNG/result. No UI-driven effect chains. Invalid cards do not tick or satisfy Events.

FloorData.events is an ordered finite candidate list. BoardState.active_events holds at most two instances in insertion order. fill_slots runs on entry/start turn, defers overflow without overwriting, and uses floor-local seen_event_ids to prevent repeats. A ready Omen waits for the single Entity slot; it cannot replace an active entity. Spawning is planned into the existing ActionResult and committed by EntitySystem. Newly spawned entities do not execute an immediate intent.

The former progress engine is ObjectiveData/ObjectiveInstance/ObjectiveSystem, with one active_objective on Board. Exact visit/instance identity is required for targeting; Explore/milestones/Insight/finite search rewards remain atomic. Objective pressure fields remain for historical content and explicitly declared future objectives, not for ordinary Event HP. Production Objectives currently declare no neglect pressure.

SceneRuleData holds compact display declarations. Persistent darkness/Threat/overstay mechanics stay in FloorData and FloorState, with no duplicate mutable rule owner. Scene Rules cannot be targeted.

End-turn planning order is Event insertion order → Objective pressure → current Entity intent → overstay. Aggregate pressure spends Guard first; Entity receives the remainder. Commit synchronously, retire completed instances, then cleanup; TurnManager advances the existing lifecycle and fills slots. No new AP, deck or combat mode.

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
EntityData / EntityInstance remain domain types; an Entity World Card is their
board presentation. HP/state/intent are read from the instance, not a UI copy.
Player Cards apply Damage/Guard or interact via tags, conditions and additional
effects. NOISE may affect Hound behavior, LIGHT may escalate Smiler behavior.
Read actual resolved exposure, not merely a printed LIGHT tag on a failed action.
High HP/mitigation is compatible with behavioral WITHDRAWN outcomes. Do not route
Smiler through a separate system outside EntitySystem.

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
A Situation/Event and one or more Entities may coexist on BoardState. Event Pressure and
Entity Intents resolve through the same TurnManager lifecycle. No `event_mode` / `combat_mode`
flag may fork the game into separate action economies.

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

Cut-out attempts use dedicated floor-temporary cards. Preparation derives automatically
from declared Situation clues and unique Insight rewards; no Prepare card/command remains.
Search collection is part of the same search resolution; no separate loot input remains.
The old zero-AP forced-cut button is deprecated; a later Exit World Card, if ever
introduced, would be a target/presentation, not a free command exception.

Critical anti-soft-lock rule:

> The player must always retain some possible route to leave a normal floor, even if safe preparation failed. A rushed or forced cut-out may be dangerous, but the run must not become permanently stuck because one event did not appear.

This guarantee holds through a retained FLOOR_TEMPORARY card, independent of normal
draw/reshuffle. It appears when stability is positive or the visit reaches turn two,
without requiring any specific Event/Insight/resource. Safe conditions replace the
existing instance's definition in place. Rushed failure keeps that instance in hand
with the original paid risk semantics; success removes it and all old-floor temporary
cards. Next floor creates its own opportunity. No forced branch or independent exit
control remains. Availability does not promise survival or zero-AP escape.

---

### 4.12 BoardState and targeting (Phase 11)

FloorState owns BoardState for one visit. Board owns `active_events: Array[EventInstance]` (capacity two), nullable `active_objective: ObjectiveInstance`, and the existing nullable `entity: EntityInstance`. No shadow world-card state is introduced.

RunState owns HP/Stress/AP, DeckState, three physical equipment instances, current floor and RNG. FloorState owns Threat/Cognition, seen/candidate scheduling facts, finite resources, cut-out and temporary Guard/LIGHT. UI owns only selection/presentation references.

PlayCardCommand identifies the actual hand card, captured definition, visit Board and optional Objective/Entity instance. `TargetKind.OBJECTIVE` retains the previous numeric mask value. Events and Scene Rules are not legal targets. Stale/resolved/removed/foreign references fail before spending; no silent redirection.

SceneRule/Event/Objective/Entity are separate concepts. CardData remains Player-only. This task authorizes neither multiple simultaneous entities nor a generic board framework.

### 4.13 Replaceable assets

`assets/asset_manifest.json` maps stable IDs to project-relative paths; `docs/ASSET_MANIFEST.md` documents usage/status/dimensions. AssetCatalog validates the res://assets/ prefix, probes existence before load, provides imported SVG fallbacks for textures and null/silence for audio. ObjectiveData.asset_id explicitly separates retained historical content IDs from art IDs. UI consumes textures/frames and AssetAudio consumes ambience/cues; neither changes gameplay. No external plugin or absolute machine path is used. Export packaging has not yet been validated.

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
The existing Phase 1-8 suite validates the legacy build. Keep state/transaction
invariants, adapt their callers to Player Cards, and explicitly retire tests
requiring deprecated buttons/no-op baselines. Passing legacy tests alone does
not establish v2 compliance; see MIGRATION_PLAN.md for the acceptance matrix.

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
- normal Player Cards are not keyed exclusively to one named Event/Entity; temporary target absence is allowed without fabricated effects.
- Event modifiers match tags, Situation Objective thresholds/rewards trigger exactly once, and Pressure resolves through TurnManager.
- Situation-only, Entity-only and mixed Situation+Entity boards all use the same AP/hand/turn pipeline.
- World Cards never enter player zones; instances have one authoritative owner.
- stale/removed/foreign-visit targets fail without spending AP, cards or equipment.
- direct legacy gameplay commands/buttons cannot bypass the hand-card requirement.
- Smiler can withdraw alive through card-mediated correct behavior; Insight remains unique.
- bad draws/exhaustion/depleted equipment retain a card-based exit route.

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

## 14. Deprecated interaction assumptions (historical reference only)

The pre-v2 architecture listed use equipment, inspect, search, loot, retreat and
attempt cut-out as independent PlayerCommands. That input model is deprecated.
Those domain effects remain useful internally, but their player-facing execution
must come from Player Cards. The old rule "equipment unlocks actions" now means
equipment-generated hand actions, never a permanent active-use button.
The old single FloorState.current_event / entity fields describe Phase 1-8 only;
they are not an alternative authority beside BoardState.

## Single-Semantic Card Rule

Every playable card has one clear primary semantic. Conditional modifiers and legal
world-target selection are allowed. Unrelated verb lists, generic branch selectors,
per-card action popups and mode parameters are forbidden. Different verbs require
separate CardData definitions. Right-click may show read-only details only.

## Current interaction implementation

CardData.effect_type plus declared numeric/tag fields define the card's one semantic.
CardData.actions, CardActionData/CardActionSystem and mode-selection resources are removed.
PlayCardCommand contains the actual hand instance, its definition identity at request
creation, current Board and optional Objective/Entity target. It cannot choose equipment,
resource nodes or action modes. Equipment source is fixed by CardInstance.source_equipment.
Definition replacement invalidates pending requests with a different captured semantic.
RuleResolver validates and plans, domain systems commit, CardSystem performs source
lifecycle changes, TurnManager notifies only after the complete result and destination
are synchronized. No UI rule engine or additional turn loop exists.

Search/Deep Search declare finite resource collection and resolve it alongside Explore
and Threat. Discovered rewards are collected in the same atomic action. An empty/resolved
Situation permits environment search only while an eligible finite reward exists; explicit
resolved/stale targets are rejected. Observe remains investigation/analysis only.

EventData declares one-time clue preparation gains and optional clue Insight. InsightSystem
merges unique rewards in the same draft, capped by CutOutState. No supply-spending Prepare
card/template/generator/API remains. Only rushed/safe templates are floor-owned.

FloorData.followup_on_light declares the prototype follow-up condition: resolved entry
entity plus actual LIGHT. EntitySystem plans replacement automatically. Old entity damage,
state and defeat commit before replacing the board slot, so Hound's lethal damage cannot
be written to a newly spawned Smiler. The existing Smiler state machine is reused.
The Level 6 Situation clue confirms the same light Insight as behavioral withdrawal,
providing a non-Smiler route without a manual landmark action.

Source-specific normal/equipment/floor lifecycles remain in CardSystem. Retained exits
occupy a base slot, upgrade in place and survive failed attempts; successful transition
cleans old-visit cards. Floor opportunity fallback at visit turn two remains independent
of event/Insight/resource draws. Run/deck/equipment/AP persist through transitions.

LegacyMain, direct gameplay commands and generic card-mode interpreters are removed.
Early floorless NO_OP/PLACEHOLDER tests and unused legacy event fields remain test/data debt,
not a player action boundary. See the migration plan §0.5 and cleanup audit for retired rules.

## Phase 9: deckbuilding boundary

`CardData.target_kinds`, `requires_active_target`, `target_entity_states` and analysis capability
declare legal World Card routes. RuleResolver validates kind, visit, exact instance, lifecycle and
state restrictions; UI forwards explicit selection unchanged and queries the same validator.
Self/player effects ignore world selection. No UI-only legality or automatic incompatible retargeting.

ObjectiveData.completion_reward and EntityData.resolution_reward reference small CardRewardData Resources.
CardRewardSystem plans opportunities from newly completed/resolved facts in the same action draft,
using a private copy of RunState RNG. RuleResolver commits RNG, rewards and original costs/effects
before notifying. EntitySystem commits final HP/state and retires inactive instances; FloorState retains
resolved_entity_ids as scheduling facts, never copies of entity runtime state. LIGHT follow-up reads
those facts after Hound retirement, including same-action defeat/light compatibility.

RunState.pending_rewards is the sole FIFO owner of CardReward opportunities. Options contain static
NORMAL definitions, not card instances. Three distinct choices are sampled from validated content.
CardRewardCommand must reference the actual first opportunity and offered choice or an eligible owned
instance; the captured definition invalidates stale upgrade requests. CardRewardSystem validates the
entire choice before CardSystem adds one instance to discard, swaps one definition in place, or removes
one NORMAL instance. Removing the queue entry consumes the opportunity exactly once. No extra AP,
turn, shuffle, draw or RNG cost occurs on claim. UI never edits zones or definitions.

TurnManager only forwards reward commands through RuleResolver and publishes post-commit signals.
Pending rewards pause card play/end turn. An empty upgrade/removal opportunity can close; otherwise
exactly one eligible choice is required. Minimum removal size is five NORMAL cards. Generated equipment
and floor cards are excluded from all persistent deck modifications. This explicit earned-reward command
does not grant a second exploration/combat/equipment/cut-out action path.

The prototype uses three base-to-upgrade Resource references and three simple numeric bonus conditions
(existing Guard, high Threat, revealed target knowledge). No generic effects DSL or branch/menu system
is introduced. Phase 9 tests exercise production reward content; fixed-inventory legacy suites use
explicit no-reward fixtures without mutating production Resources.

## Phase 10: historical content, preserved safe points and run facts

Production FloorData declares five fresh candidates, optional intro Event, one SafePointData,
exit timing/progress fallback, overstay pacing and Threat damage scaling. Compatibility defaults
preserve earlier rule fixtures. Current balancing never introduces another hand/AP/turn manager.

SafePointState belongs to FloorState for the visit. Completion count reaches its configured
opportunity; the current board must be clear of active entities and pending rewards to use it.
SafePointCommand carries exact Board/point references, rest/remove/upgrade choice and optional
owned NORMAL instance with captured definition. SafePointSystem validates everything before
one commit consumes the point and changes HP/Stress or delegates deck mutation to CardSystem.
RuleResolver/TurnManager publish only complete results. UI opening, candidate selection, back
and postpone are read-only; no arbitrary rest/deck-edit API without a real opportunity exists.
The previous reward kind helpers remain for historical regression, not ordinary production triggers.

ResourceNodeData may declare equipment_id/uses_reward alongside Supply. ResourceNodeSystem
selects a finite useful cache and plans the exact instance/capped amount; EquipmentSystem owns
physical use-counter mutation. Full/missing equipment does not consume a cache with no benefit.
Search progress, reward, uses, AP/card movement and RNG remain one synchronous transaction.

ObjectiveSystem commits real applied Explore into floor-local total_explore and increments the visit
completion count once. Production clears the resolved active reference after its rewards/facts
are committed; Fresh replacement remains at next turn start. ObjectiveData clue_light_exposure is a
declared automatic world consequence of the card milestone, using the same actual LIGHT reaction
and follow-up path as equipment. It does not create a free light/encounter command.

RunMetrics belongs to RunState and records already committed facts: deck changes, plays, unique
Insight names/IDs, Situation durations, entity outcomes, floor-exit snapshots and hand quality.
History is never an alternative live world/HP owner. Snapshot exit Threat/deck size before floor
replacement so the terminal floor's zero values cannot erase run results. The summary panel reads
facts only; new run is a pure application-flow reset. Debug logs remain local and debug-only.

Phase 1–9 tests use frozen Phase 9 content in tests/fixtures/phase9, retaining transaction/source/
state invariants and the old balance assertions explicitly. Phase 10 tests use real production
resources, multiple seeds and actual UI commands. Separate windowed validation captures viewport
textures; headless geometry checks are never presented as graphical verification.
