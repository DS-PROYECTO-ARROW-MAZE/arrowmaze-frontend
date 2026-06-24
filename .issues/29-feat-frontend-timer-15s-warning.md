# feat(frontend): 15-second timer warning (distinct visual + audio cue)

- **Phase:** 6 — enhancement (UX / feedback)
- **Stories:** B2 (defeat-on-time — warning refinement)
- **Blocked by:** 04 (session-state-machine), 18 (timer rules — timed levels), 21 (audio)
- **Traceability:** PRD §3 (B2) · CLAUDE.md State machine (`PlayingState`)

> On **timed** levels (ticket 18: `numero ≥ 10`, non-bonus), when the countdown reaches
> **exactly 15 seconds remaining**, trigger a **distinct visual and audio warning** so the
> player knows time is nearly up. The cue fires **once** as the timer crosses 15s; it must not
> re-fire each tick, and it must not apply to untimed or bonus levels.

## User Story

> *As a player racing the clock, at 15 seconds left I get a clear heads-up — the timer changes
> appearance and a distinct sound plays — so the ending never surprises me.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `presentation` (DM-F8) | `JuegoViewModel` watches `segundosRestantes`; when it crosses **15** it sets a one-shot `avisoTiempo` flag for the HUD and emits a warning event — guarded so it fires once per run |
| `domain` (DM-F7) | a `TipoEvento` for the time warning (e.g. `AvisoTiempo`) so audio reacts via the Observer (`AudioServiceImp`), keeping the use case audio-free |
| `infrastructure` | `AudioServiceImp` maps `AvisoTiempo` → a distinct warning SFX (softer-set, ticket 25) |
| `presentation` | HUD timer adopts a distinct warning style (e.g. color/pulse) while `segundosRestantes ≤ 15` |

## Acceptance Criteria

1. On a **timed** level, the warning (distinct visual **and** audio) triggers **once** at exactly
   15 seconds remaining; it does **not** re-fire every subsequent tick.
2. The HUD timer adopts a distinct warning appearance for the final 15 seconds.
3. **Untimed** (`numero 1–9`) and **bonus** levels never trigger the warning (no timer at all).
4. Audio is via the **Observer** (`AvisoTiempo` → SFX): no audio symbol in `domain`/`application`.
5. The warning state resets on retry/replay so it fires again on the next timed run; pausing does
   not spuriously re-fire it.

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `presentation/juego_viewmodel_test.dart`:
  - `should_fire_time_warning_once_when_remaining_reaches_15` (AC1 — drive the timer across 15;
    assert a single warning, then none on later ticks).
  - `should_not_warn_when_level_untimed_or_bonus` (AC3).
  - `should_reset_warning_on_retry` (AC5).
- `infrastructure/audio_service_imp_test.dart`:
  - `should_play_distinct_warning_sound_when_notified_of_aviso_tiempo` (AC4).

### 🟢 GREEN
- Add the one-shot `avisoTiempo` guard + HUD warning style in the VM; add the `AvisoTiempo`
  `TipoEvento` and map it to a distinct SFX in `AudioServiceImp`.

### ♻️ REFACTOR
- Keep the threshold (15s) a single named constant; keep audio behind the Observer; ensure the
  one-shot flag resets cleanly per run.

## Definition of Done
- A single distinct visual+audio warning fires at exactly 15s on timed levels; none on
  untimed/bonus.
- Audio via Observer (no audio in domain/application); warning resets per run; pause-safe.
- `flutter analyze` clean, full suite green.

---
**Working agreement (mandatory):** strict **TDD** (🔴→🟢→♻️). **MVVM + Clean Architecture**
(CLAUDE.md): warning state flows View ← ViewModel; audio via `ObservadorJuego`; `domain`/
`application` import **no Flutter/audio**. The timed-vs-untimed rule stays data-driven from
`DefinicionNivel` (ticket 18). Ubiquitous language per PRD §4.
