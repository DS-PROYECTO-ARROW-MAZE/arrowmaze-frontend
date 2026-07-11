# feat(frontend): victory confetti effect on Level Complete (with proper cleanup)

- **Phase:** 7 — enhancement (UX / celebration feedback)
- **Stories:** D-epic (victory feedback), pairs with the existing `_VictoriaOverlay`
- **Blocked by:** 06 (scoring-and-stars), 13/19 (victory overlay + star display)
- **Traceability:** PRD §3 (D-epic) · CLAUDE.md State machine (`EstadoVictoria`) ·
  `game_view.dart` (`_VictoriaOverlay`, rendered when `estado.victoria != null`)

> When the player **wins / completes a level**, a **confetti** burst plays automatically. The effect
> triggers **exactly when the `Level Complete` UI renders** — i.e. the frame `_VictoriaOverlay`
> first appears (`JuegoViewState.victoria != null`) — and **not** on defeat, pause, or replays of the
> same state. It must **clean up on unmount** (dispose its animation controller / cancel timers) so
> leaving the screen mid-burst leaks no ticker or memory.
>
> **Dependency review first:** the project currently ships **no** animation/particle package
> (`pubspec.yaml`: `http`, `shared_preferences`, `audioplayers`, `cupertino_icons`). Prefer a
> **self-contained Flutter `CustomPainter` + `AnimationController`** confetti (zero new deps, matches
> the existing hand-rolled painters like `_RelojHud`). If a package is chosen instead, use a small,
> well-maintained standard (e.g. `confetti`); `canvas-confetti` is JS/web-only and is **not** a Flutter
> option here — treat the brief's mention as "install a lightweight standard" and pick the Flutter
> equivalent. Justify the choice in the PR.

## User Story

> *As a player, the moment I clear a level, confetti rains over the win screen — a satisfying
> celebration — and it never lingers or leaks when I move on.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `presentation` | `ConfettiOverlay` (NEW, `StatefulWidget`) — owns an `AnimationController` (via a `TickerProvider`); paints particles with a `CustomPainter`; **fires once** in `initState` |
| `presentation` | `_VictoriaOverlay` (`game_view.dart`) — hosts `ConfettiOverlay` behind the win text/stars so confetti sits under the panel content |
| `presentation` | `_GameViewState` — already `TickerProviderStateMixin` with a `dispose()` chain; the confetti controller is disposed there (or self-disposed in the overlay's own `dispose`) |

## Acceptance Criteria

1. Confetti triggers **automatically** on the first render of the victory overlay
   (`estado.victoria != null`) — no user tap needed.
2. It **does not** trigger on defeat (`_DerrotaOverlay`), pause, or while merely rebuilding an
   already-shown victory state (fires **once per win**, not every `notifyListeners`).
3. On **bonus** levels (win with `mostrarPuntuacion == false`) confetti still plays — winning is
   winning.
4. **Cleanup on unmount:** the animation controller is disposed and any timer cancelled; a widget
   test asserts no active ticker remains after the overlay is removed (no leak).
5. The effect is purely visual and non-blocking: it never intercepts the Next / Retry / Menu buttons
   and never delays their availability.

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `presentation/confetti_overlay_test.dart` (widget):
  - `should_start_animation_when_first_mounted` (AC1).
  - `should_fire_only_once_across_rebuilds` (AC2 — pump extra frames/rebuilds, assert a single start).
  - `should_dispose_controller_on_unmount` (AC4 — pump then remove; assert no active ticker /
    `debugAssertNotDisposed`-safe).
- `presentation/game_view_test.dart`:
  - `should_show_confetti_when_victoria_present_and_not_on_derrota` (AC1/AC2).
  - `should_show_confetti_on_bonus_victory` (AC3).

### 🟢 GREEN
- Implement `ConfettiOverlay` (self-contained painter preferred; else the chosen package); mount it
  inside `_VictoriaOverlay`; ensure the controller lifecycle is tied to the overlay's mount.

### ♻️ REFACTOR
- Keep particle params (count, duration, gravity) as named constants; keep the overlay purely
  presentational (no VM/domain imports); if a package is added, isolate it behind the overlay so the
  rest of the View is package-agnostic.

## Definition of Done
- Confetti fires once, exactly when the Level Complete UI appears (incl. bonus wins), never on
  defeat, and disposes cleanly with a leak-check test.
- Dependency choice documented; `flutter analyze` clean, full suite green.

---
**Working agreement (mandatory):** strict **TDD** (🔴→🟢→♻️). **MVVM + Clean Architecture**
(CLAUDE.md): confetti is **presentation-only** — no confetti symbol in `domain`/`application`; the
overlay reads victory from `JuegoViewState`, never drives game logic. Follow the existing
hand-rolled-painter idiom (`_RelojHud`) and the established `dispose()` discipline in `_GameViewState`.
