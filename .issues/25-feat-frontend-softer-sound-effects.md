# feat(frontend): softer, gentler sound effects (SFX tuning)

- **Phase:** 6 — enhancement (UX / audio)
- **Stories:** F1 (reactions decoupled from rules — refinement)
- **Blocked by:** 21 (audio sound effects via `AudioServiceImp` observer)
- **Traceability:** PRD §F (Epic — reactions audio/UI), ADR-0002 (one Singleton) · CLAUDE.md
  Patterns (Observer, Singleton `AudioServiceImp`)

> The current SFX feel **harsh and rigid**. Replace or retune them so the audio is **softer,
> more pleasant, and less abrasive** — gentler attack, lower harshness, comfortable level — while
> keeping the **exact same Observer wiring**: sounds still play only as `ObservadorJuego`
> reactions to `TipoEvento`s, never referenced by game logic (PRD §F). This is an **asset +
> mapping** change, not a rule change.

## User Story

> *As a player, the game's sounds are soft and pleasant — a gentle tap, a mellow exit, a warm
> victory chime — never sharp or jarring, even when I play fast.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `assets` | replace/retune SFX files (move, invalid/wall, collectible, victory, defeat) with softer samples; declare in `pubspec.yaml` |
| `infrastructure` | `AudioServiceImp` — the `TipoEvento → asset` table points at the new softer assets; optional gentle defaults (per-SFX gain/volume, no clipping) |
| `presentation`/`infrastructure` | rapid repeated triggers do not pile up into harsh overlapping bursts (debounce/limit polyphony for the same event) — pairs with the invalid-move single-alert rule (ticket 28) |

## Acceptance Criteria

1. All key event SFX are replaced/retuned to **softer** samples; the event→sound mapping table
   is updated, with no change to the Observer contract (sounds remain `ObservadorJuego` reactions).
2. Audio stays **decoupled from rules** (PRD §F): no audio symbol appears in `domain`/
   `application` (guard from ticket 07 / §7.8 stays green).
3. Per-SFX playback level is comfortable and non-clipping; rapid repeats do not produce harsh
   overlapping spam (bounded polyphony / debounce for the same `TipoEvento`).
4. Mute/disable still works globally (ties into the Settings sound toggle, ticket 27) without
   touching game logic; missing-asset failures degrade gracefully (no crash).

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `infrastructure/audio_service_imp_test.dart` (fake audio backend):
  - `should_play_softened_asset_for_each_event_type` (AC1 — the mapping resolves to the new
    asset keys for every `TipoEvento`).
  - `should_debounce_rapid_repeats_of_same_event` (AC3 — N rapid identical notifications do not
    trigger N overlapping plays beyond the configured limit).
  - `should_suppress_playback_when_muted` (AC4).

### 🟢 GREEN
- Swap the asset table to the softer files; add per-SFX gain + same-event debounce/polyphony cap;
  keep the mute path.

### ♻️ REFACTOR
- Keep the event→sound mapping **data-driven** (a table), so swapping a sample is data, not a
  branch; keep the audio backend behind its interface for testability.

## Definition of Done
- SFX are audibly softer/pleasant; mapping updated with the Observer contract intact.
- No audio reference in `domain`/`application` (guard green); rapid repeats are bounded; mute and
  missing-asset degradation work.
- `flutter analyze` clean, full suite green.

---
**Working agreement (mandatory):** strict **TDD** (🔴→🟢→♻️). **Clean Architecture / MVVM**:
audio lives in `infrastructure` behind the Observer; `domain`/`application` import **no audio**.
Use the **ubiquitous language** (`ObservadorJuego`, `TipoEvento`, PRD §4). `AudioServiceImp`
remains the **one** sanctioned Singleton (ADR-0002).
