# feat(frontend): invalid-move feedback — single red alert (no spam) + haptic vibration

- **Phase:** 6 — enhancement (UX / feedback)
- **Stories:** A2 (invalid move — feedback refinement)
- **Blocked by:** 01 (core-move-mechanic), 02 (invalid-move-history)
- **Traceability:** PRD §3 (A2) · §8 (NFR) · CLAUDE.md MVVM

> When a player taps a **blocked** arrow (invalid move — head ray hits a wall/another path), the
> feedback must be **crisp and non-spammy**: the **red visual alert fires exactly once per
> interaction**, even if the player taps rapidly (no flicker/visual spam), **and** the device
> emits a short **haptic vibration**. The rule itself (invalid still costs a move, board
> unchanged) is unchanged — this is feedback only.

## User Story

> *As a player, when I tap an arrow that can't move I feel a small buzz and see a single clean
> red flash — not a strobing mess when I tap quickly.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `presentation` (DM-F8) | `JuegoViewModel` exposes a transient `alertaInvalida` pulse on an invalid `ResultadoMovimiento`; it is **debounced** so repeated invalid taps within a short window do not re-trigger overlapping flashes |
| `infrastructure` | a `HapticFeedbackPort` adapter wrapping Flutter `HapticFeedback` (e.g. `mediumImpact`/`vibrate`), fired on an invalid move via the Observer/VM — domain stays haptics-free |
| `presentation` | the red-alert widget animates once per pulse and self-clears; rapid pulses coalesce |
| `domain` (DM-F7, read-only) | the invalid outcome already emits an event (`MovimientoInvalido`/no-delta) — reused, not changed |

## Acceptance Criteria (PRD §3 A2)

1. An invalid tap triggers the red visual alert **exactly once per interaction**; rapid repeated
   invalid taps within the debounce window do **not** stack/strobe (single clean pulse).
2. An invalid tap emits **haptic feedback** (vibration) via a port; on devices without haptics it
   degrades gracefully (no crash, no error).
3. Haptics/visual are **decoupled from rules**: `domain`/`application` contain no haptic or UI
   symbol; the invalid-move rule (move still counts, board unchanged — ticket 02) is unchanged.
4. A **valid** move triggers neither the red alert nor the invalid haptic.

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `presentation/juego_viewmodel_test.dart`:
  - `should_emit_single_invalid_alert_pulse_when_tapped_rapidly` (AC1 — N rapid invalid taps
    within the window → 1 pulse).
  - `should_request_haptic_feedback_when_move_invalid` (AC2 — fake `HapticFeedbackPort` invoked).
  - `should_not_alert_or_buzz_when_move_valid` (AC4).
- `infrastructure/haptic_feedback_port_test.dart`:
  - `should_noop_gracefully_when_haptics_unavailable` (AC2).

### 🟢 GREEN
- Add the debounced `alertaInvalida` pulse to the VM; introduce `HapticFeedbackPort` + adapter;
  fire haptics on invalid; animate the alert once and self-clear.

### ♻️ REFACTOR
- Keep haptics behind the port (DIP); keep the debounce window a single named constant; ensure the
  pulse clears so it can't bleed into later frames.

## Definition of Done
- One red alert + one haptic per invalid interaction; rapid taps don't spam; valid moves are quiet.
- Haptics behind a port; graceful on devices without vibration; rule unchanged.
- No haptic/UI symbol in `domain`/`application`; `flutter analyze` clean, suite green.

---
**Working agreement (mandatory):** strict **TDD** (🔴→🟢→♻️). **MVVM + Clean Architecture**
(CLAUDE.md): feedback flows View ← ViewModel; haptics behind an injected port; `domain`/
`application` import **no Flutter**. Ubiquitous language per PRD §4 (the move count still
increments on an invalid tap — do not "fix" it).
