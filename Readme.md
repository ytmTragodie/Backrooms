# Backrooms Demo

Godot 4.x project using the Compatibility renderer. Open `project.godot` and run
the main scene with F6 or the project with F5.

Phase 1 provides a run with 30 HP, zero Stress/Threat/Cognition, turn 1 and 3 AP.
End Turn advances one turn and restores AP to 3. The scene-owned TurnManager
owns RunState; UI reads it and forwards the End Turn command. There are no card,
floor, or entity systems. Threat and Cognition are temporary RunState fields
until FloorState is introduced; ending turns does not change them in this phase.

Run deterministic validation from the project directory, replacing `godot` with
the path to your Godot executable if it is not on PATH:

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/phase_1_validation.gd
godot --headless --path . --quit-after 3
```

The validation exits with code 1 on a failed check. It covers initial values,
AP restoration from zero and partially spent AP, repeated turns, independent
runs, notification timing, and the main scene's End Turn button and UI refresh.
