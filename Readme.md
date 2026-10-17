# Backrooms Demo

Godot 4.x project using the Compatibility renderer. Open `project.godot` and run
the main scene with F6 or the project with F5.

New runs start with 30 HP, zero Stress/Threat/Cognition, turn 1 and 3 AP.
The scene-owned TurnManager owns RunState and coordinates turn lifecycle. UI
reads state and sends Play or End Turn commands. Threat and Cognition remain
temporary RunState fields until FloorState is introduced.

Phase 2 adds an ordered nine-card prototype deck: three copies each of Observe
(1 AP), Wait (0 AP), and Struggle (1 AP). The opening hand is Observe, Struggle,
Observe, Struggle, Wait. This temporary deck replaces the canonical GDD starter
content only for Phase 2 validation. The starter list and card definitions are
Resources under `data/cards/`; each copy has a separate runtime CardInstance.

Each turn draws to five. Played cards enter discard; End Turn discards the rest,
restores AP to 3, and draws the next hand. When the draw pile runs out, discard
is shuffled with the run-owned RNG (default seed 1, logged at startup), then
drawing continues. Existing draw cards are consumed before any reshuffle.
Unaffordable and out-of-hand plays are rejected without changing state.

Phase 3 routes plays through a stateless RuleResolver:
UI -> TurnManager.request_play_card -> PlayCardCommand -> RuleResolver ->
ActionResult -> RunState AP / CardSystem location commit -> notifications -> UI.
The resolver receives state explicitly and validates the whole request before
building a result and committing changes. CardSystem still owns draw, discard,
and reshuffle; it has no play-command entry and does not depend on RuleResolver.
All external play requests use TurnManager.request_play_card so both state and
result notifications are delivered consistently. Phase 2 assertions are kept
and migrated to this command entry.

TurnManager exposes a fixed RunState reference; create a new TurnManager for a
new run. CardSystem reads the current DeckState from its bound RunState on each
operation instead of caching a second deck reference.

CardData declares only NO_OP or PLACEHOLDER_DAMAGE. Observe and Wait return
successful no-op results; Struggle returns `damage_requested=2`. No damage is
applied and Observe never grants Cognition. ActionResult includes success,
failure reason, AP spent, played instance, placeholder effect, and trace lines.
The debug status shows the last success or rejection. There are no floors,
events, entities, combat, equipment, cut-out, or polished card UI.

Run deterministic validation from the project directory, replacing `godot` with
the path to your Godot executable if it is not on PATH:

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/phase_1_validation.gd
godot --headless --path . --script res://tests/phase_2_validation.gd
godot --headless --path . --script res://tests/phase_3_validation.gd
godot --headless --path . --quit-after 3
```

Each validation exits with code 1 on a failed check. Phase 1 covers initial
values, AP restoration, repeated turns, independent runs, signals, and UI.
Phase 2 covers draw-to-five, paid/free plays, rejection without mutation,
discard, partial draws and reshuffling, empty/short decks, conservation of every
runtime instance, fixed-seed determinism, unchanged Resources, and UI commands.
Phase 3 verifies transactional failure, structured effects, exactly one AP/card
commit and result notification, invalid commands/state/definitions, unchanged
Resources/RNG, and UI result presentation. Failure snapshots copy instance and
definition identities plus static field values. Regression checks verify that
definition replacement/field changes are detected and that deck operations
never use an outdated DeckState reference.

Manual check: run with F5. Play the first three 1 AP cards to reach zero AP,
then try Struggle: the hand and AP must stay unchanged. Play Wait successfully
at zero AP. End Turn should show turn 2, AP 3 and five cards. Watch the Output
panel for `[COMMAND]`, `[RULE]`, `[AP]`, `[CARD]`, and `[RESULT]` traces.
Successful Struggle reports `damage_requested=2`; the rejected play reports
`insufficient_ap`. Observe must leave Cognition at 0. Turn/discard/reshuffle
behavior remains the same.
