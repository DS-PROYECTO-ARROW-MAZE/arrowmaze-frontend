# 07 · Observer Reactions (audio/UI decoupled from rules)

- **Phase:** 2 — PARALLELIZABLE
- **Stories:** F1 (events drive reactions, not the domain)
- **Blocked by:** 01
- **Unblocks:** —
- **Traceability:** PRD §11 (F1) · tests §7.6

## User Story

> *As a player, I hear/see reactions to my moves (a sound on arrow exit, a victory
> cue, the HUD updating) — but the game rules must not know anything about audio or UI.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `domain` (DM-F7) | `PublicadorEventosJuego` (Subject: `suscribir/desuscribir/publicar(EventoJuego)`) + `ObservadorJuego` (`alOcurrirEvento`) — GoF **Observer** |
| `application` | `MoverFlechaUseCase` feeds its emitted `List<EventoJuego>` to the publisher and **references no audio/UI** |
| `infrastructure` | `AudioServiceImp` — the **one** honest GoF **Singleton**; observes `FlechaEliminada`/`Victoria` |
| `presentation` | score VM + HUD/board VM register as observers; update on events |
| `di` | register observers with the publisher at composition root |

## Acceptance Criteria (PRD §3 F1, §7.6)

1. After a move, **each** registered `ObservadorJuego` receives the emitted events.
2. The use case has **no** direct reference to audio or UI (verified via fakes/spies).
3. This Observer is **distinct** from MVVM data-binding (`notifyListeners()` is View↔ViewModel only).

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `domain/publicador_eventos_test.dart`:
  - `should_notify_all_subscribed_observers_when_event_published` (AC1).
  - `should_stop_notifying_after_desuscribir` (registry correctness).
- `application/mover_flecha_publishes_events_test.dart` (spy observer via mocktail):
  - `should_feed_emitted_events_to_publisher_when_move_resolves` (AC1).
  - `should_not_reference_audio_or_ui_in_use_case` (AC2 — spy receives events; assert no audio/UI type is imported/called — pair with the dependency-direction lint in ticket 12).
- `infrastructure/audio_service_singleton_test.dart`:
  - `should_return_same_instance_when_accessed_twice` (Singleton).
  - `should_play_on_FlechaEliminada_and_Victoria` (observes, doesn't drive rules).

### 🟢 GREEN
- Implement publisher/observer; subscribe `AudioServiceImp` + VMs; have the use case publish its event list and nothing else.

### ♻️ REFACTOR
- Keep the use case emitting **events** (records of what happened), never commands. Confirm `notifyListeners()` is used only for View↔ViewModel, never described as "the Observer".

## Definition of Done
- Observers all notified; use case audio/UI-free; AudioServiceImp is a single instance reacting to events; Observer vs data-binding kept distinct.
