# feat(frontend): game sound effects via AudioServiceImp observer

- **Phase:** 5 — enhancement (UX)
- **Stories:** F1 (reactions decoupled from rules)
- **Blocked by:** 07 (observer-reactions)
- **Traceability:** PRD §F (Epic — reactions audio/UI), §"One Singleton, not three" (ADR-0002)
  · CLAUDE.md Patterns (Observer, Singleton `AudioManager`/`AudioServiceImp`)

> Integrate and **enable** game sound effects. Audio must stay **decoupled from the game
> rules**: the move/scoring use cases emit domain events through `PublicadorEventosJuego`,
> and a registered `ObservadorJuego` — `AudioServiceImp` — reacts by playing sounds. The
> use cases never reference audio directly (PRD §F). `AudioServiceImp` is the project's one
> honest GoF **Singleton** (ADR-0002).

## User Story

> *As a player, I hear feedback — a valid move, hitting a wall/invalid move, collecting a
> bonus, victory, defeat — without the game logic knowing anything about sound.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `domain` (DM-F7) | `EventoJuego` (`tipo: TipoEvento`) + `PublicadorEventosJuego`/`ObservadorJuego` (Observer) — already introduced by ticket 07 |
| `infrastructure` | `AudioServiceImp` implements `ObservadorJuego` (GoF Singleton), maps each `TipoEvento` → a sound asset and plays it; pluggable audio backend (e.g. `audioplayers`) |
| `assets` | sound effect files (move, invalid/wall, collectible, victory, defeat) declared in `pubspec.yaml` |
| `di` | `Inyeccion` registers `AudioServiceImp` as an observer on `PublicadorEventosJuego` |

## Acceptance Criteria

1. Distinct sound effects play for the key events: valid move, invalid/wall move, collectible
   pickup, victory, defeat.
2. Audio is driven **only** through the Observer: domain/use-case code contains **no**
   reference to audio (verified via fakes/spies — PRD §F).
3. `AudioServiceImp` is a single instance (the one sanctioned Singleton, ADR-0002); registered
   once via DI.
4. Sounds can be globally muted/disabled without touching game logic (toggle on the audio
   service), and missing-asset failures degrade gracefully (no crash).

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `infrastructure/audio_service_imp_test.dart` (fake audio backend) —
  `should_play_move_sound_when_notified_of_valid_move`,
  `should_play_defeat_sound_when_notified_of_defeat`, etc.: a `TipoEvento` notification
  triggers the mapped sound (AC1); a mute flag suppresses playback (AC4).
- `domain/observer guard` (covered by ticket 07 / §7.8 language guard) —
  `should_not_reference_audio_in_use_cases` (AC2 — no audio symbol imported in
  domain/application).

### 🟢 GREEN
- Implement `AudioServiceImp` as an `ObservadorJuego` mapping `TipoEvento → asset`; wire it
  into `PublicadorEventosJuego` via DI; declare assets; add the mute toggle.

### ♻️ REFACTOR
- Keep the event→sound mapping data-driven (table), so adding a sound is data, not a new
  branch; keep the audio backend behind an interface for testability.

## Definition of Done
- Sound effects play for the key events, driven purely via the Observer (no audio reference
  in domain/application — guard green).
- Single `AudioServiceImp` instance; global mute works; missing assets degrade gracefully.
- `flutter analyze` clean, suite green.
