# feat(frontend): conditional Hint button (Medium+ only, unlocked at ≤ 25 s remaining)

- **Phase:** 7 — enhancement (assist / difficulty-gated UX)
- **Stories:** B-epic (timer rules), assist feature
- **Blocked by:** 01 (core-move-mechanic), 04 (session-state-machine), 18 (timer rules — timed levels),
  17 (level catalog / difficulty metadata)
- **Traceability:** PRD §3 (B-epic) · CLAUDE.md State machine (`PlayingState`) ·
  `dificultad.dart` (`Dificultad.{facil,medio,dificil}`) · `juego_view_model.dart`
  (`tiempoRestante`/`segundosRestantes`, `avisoTiempo`)

> Add a **Hint** button to the game board HUD, governed by **two strict rules**:
>
> - **Rule A — difficulty gate.** The Hint button exists **only** on levels of difficulty **Medium
>   or higher** (`Dificultad.medio` or `Dificultad.dificil`). On **Easy** (`Dificultad.facil`)
>   levels it **does not render at all**.
> - **Rule B — time gate.** On eligible levels the button is **hidden/disabled at the start** and
>   becomes **enabled/visible only when the timer reaches exactly 25 seconds or fewer remaining**
>   (`segundosRestantes ≤ 25`). Before that threshold it must not be usable.
>
> Both rules are **AND-ed**: an Easy level never shows a hint regardless of the clock; a Medium/Hard
> level shows it only inside the final-25 s window. This composes cleanly with the existing 15 s
> warning (ticket 29) — the hint window (≤ 25 s) opens before the warning window (≤ 15 s).

## User Story

> *As a player on a Medium or Hard level who's running low on time, a Hint button appears in the
> final 25 seconds so I can get unstuck — but easy levels never offer it, and it stays away until
> I actually need it.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `presentation` | `JuegoViewModel` exposes a derived `pistaDisponible` (Rule A `&&` Rule B): `dificultad ∈ {medio, dificil}` **and** `segundosRestantes ≤ 25` and the session is still `Playing`; recomputed on each tick alongside `avisoTiempo` |
| `presentation` | `JuegoViewState` gains `bool pistaDisponible` (+ a stable `bool pistaHabilitadaEnNivel` for Rule A alone, so the button can render disabled vs. be absent — pick per UX below) |
| `presentation` | `_Hud` (`game_view.dart`) renders the Hint button; **absent** on Easy (Rule A), and disabled/hidden until the state flips at ≤ 25 s (Rule B) |
| `domain`/`application` | the hint's *content* (what to suggest) is out of scope here if not already available; this ticket delivers the **gated button + trigger**. If a hint action exists, wire it; otherwise the button emits a `pedirPista` intent the VM handles (a follow-up can enrich the suggestion) |

> **Rule A rendering choice:** on Easy the button is **not built** (never in the tree). On Medium/Hard
> it is built but **disabled** until Rule B unlocks it (clearer affordance than popping in). Confirm
> this reading in the PR; both satisfy the brief ("hidden **or** disabled at start").

## Acceptance Criteria

1. **Rule A:** on an **Easy** level the Hint button is **never rendered** — not disabled, absent —
   at any time on the clock.
2. **Rule A (positive):** on **Medium** and **Hard** levels the button participates in the HUD.
3. **Rule B (locked):** at level start and while `segundosRestantes > 25`, the button is
   **hidden or disabled** and cannot be activated.
4. **Rule B (unlock):** the button becomes **enabled/visible exactly when `segundosRestantes ≤ 25`**
   (boundary: at 25 it is available; at 26 it is not).
5. **Composition:** both rules AND together — an Easy level never shows it even below 25 s; a
   Medium/Hard level shows it only below 25 s.
6. **State hygiene:** availability resets on retry/replay; on untimed levels (if any Medium/Hard were
   untimed) with no countdown the time gate is treated as *not met* (button stays locked) — the gate
   is data-driven from the same timer source as ticket 18/29, no divergent clock.

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `presentation/juego_viewmodel_test.dart`:
  - `should_never_expose_hint_on_easy_levels` (AC1 — drive time down to 0; `pistaDisponible` stays false).
  - `should_expose_hint_only_at_or_below_25_seconds_on_medium` (AC3/AC4 — assert false at 26, true at 25).
  - `should_expose_hint_on_hard_levels_in_window` (AC2/AC4).
  - `should_reset_hint_availability_on_retry` (AC6).
  - `should_keep_hint_locked_when_no_countdown` (AC6).
- `presentation/game_view_test.dart` (widget):
  - `should_not_build_hint_button_on_easy_level` (AC1).
  - `should_render_hint_button_disabled_then_enabled_across_25s_boundary` (AC3/AC4).

### 🟢 GREEN
- Add the derived `pistaDisponible` (+ Rule-A flag) to `JuegoViewModel`/`JuegoViewState`; render the
  gated button in `_Hud`; wire the tap to the existing hint action or a `pedirPista` VM intent.

### ♻️ REFACTOR
- Keep the **25 s** threshold a single named constant (sibling to the 15 s warning constant); express
  the gate as one pure predicate combining difficulty + remaining seconds + `Playing` state; keep the
  View free of the rule (it only reads booleans).

## Definition of Done
- Hint button obeys both rules exactly: absent on Easy; on Medium/Hard locked until `≤ 25 s`, then
  available; resets per run; boundary at 25 s verified.
- `flutter analyze` clean, full suite green.

---
**Working agreement (mandatory):** strict **TDD** (🔴→🟢→♻️). **MVVM + Clean Architecture**
(CLAUDE.md): the gate lives in the **ViewModel** as a derived boolean; the View never evaluates
difficulty or time; `domain`/`application` import **no Flutter**. Difficulty is **data**
(`Dificultad`, never subtypes); the timer source is the same one ticket 18/29 use — no second clock.
