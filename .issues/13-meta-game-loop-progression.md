# 13 · Meta-Game Loop & Progression

- **Phase:** 4 — UX / META-GAME
- **Stories:** the playable loop — Level Selection, progression locks, post-game navigation
- **Blocked by:** 05 (level generation/loading), 06 (scoring & stars)
- **Unblocks:** —
- **Traceability:** DIAGRAM-RECONCILIATION.md §10 (FRONTEND-03) · CLAUDE.md "Puertos / interfaces"

> **Scope:** front-end only. End-to-end review found the meta-game loop broken in
> three ways: (1) no Level Selection screen, (2) no progression locks / completion
> persistence, (3) Victory/Defeat overlays were dead ends. This ticket builds the
> selection UI, the unlock engine with local persistence, and the post-game
> Next/Retry/Menu navigation.
>
> **Not in scope / explicitly preserved:** Ticket 05's `SeleccionNivelViewModel`
> (single-board loader) is **left untouched** — this ticket adds a new
> `SeleccionNivelesViewModel` rather than retrofitting a closed ticket. No backend
> changes; progression is offline-local (the §9.4 HTTP read path is deferred).

## User Story

> *As a player, after signing in I pick a level from a menu that shows my stars and
> locks levels I haven't reached yet; when I win or lose I can go to the next level,
> retry, or return to the menu — never a dead end.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `domain` | `Dificultad` enum; `ResumenNivel`; `ReglaDesbloqueo` + `ReglaDesbloqueoSecuencial` (Strategy) |
| `application` | ports `CatalogoNiveles`, `ConsultaProgresoLocal`; `NivelConEstado`; `ObtenerNivelesUseCase` (joins catalog + progress + rule) |
| `infrastructure` | `ProgresoLocalPersistente` (`shared_preferences`); `CatalogoNivelesArchivo` (asset manifest) |
| `presentation` | `SeleccionNivelesViewModel` + `SeleccionNivelesViewState` (`NivelResumenUI`); `SeleccionNivelesView`; `GameView` post-game buttons; `JuegoViewModel` records completion on victory |
| `di` / root | `Inyeccion` wires the new ports/use case; `main.dart` Auth→Select→Game host with Next/Retry/Menu |
| `assets` | `level_02.json`, `level_03.json` (sequential content) |

## Acceptance Criteria

1. After Auth (or guest), the app opens the **Level Selection** menu, not the board.
2. Levels render in order with their **best stars**; level 1 is always open and level
   *N* is **locked** until level *N − 1* is completed.
3. Completing a level **persists** (survives app restart) via `shared_preferences`
   and **unlocks** the next level (a 0-star clear still counts as completed).
4. The **Victory** overlay offers **Next Level** (hidden on the last level), **Retry**,
   and **Level Select**; the **Defeat** overlay offers **Retry** and **Level Select**.
5. Progression read is **decoupled** from the offline-sync upload path
   (`IRepositorioProgreso` / `IColaSincronizacion` are unchanged).
6. Lock logic lives in the application/domain (`ReglaDesbloqueo` + use case), never in a
   View; the GoF session State machine is **unchanged** (Retry/Next rebuild a fresh
   `SesionJuego` — they are navigation, not new states).

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `domain/regla_desbloqueo_test.dart` — first level open; level N locked until N−1 done (AC2).
- `application/obtener_niveles_use_case_test.dart` (fake ports) — lock gating, star carry-over,
  0-star completion unlocks next (AC2/AC3).
- `infrastructure/progreso_local_persistente_test.dart` (`SharedPreferences.setMockInitialValues`)
  — persist completion + best stars, keep best on replay, survive a new instance (AC3).
- `presentation/seleccion_niveles_viewmodel_test.dart` — maps use-case output to card state;
  error path (AC1/AC2).

### 🟢 GREEN
- Implement ports, rule, use case, the two adapters, the VM/View, post-game buttons, and the
  Auth→Select→Game host navigation.

### ♻️ REFACTOR
- Keep the unlock rule a Strategy so a future star-gated policy needs no use-case/View change.
- Confirm `ConsultaProgresoLocal` stays separate from the sync queue (different sinks).

## Design notes / divergences from DM §10

- `ConsultaProgresoLocal.registrarCompletado({idNivel, estrellas})` takes the two fields it
  needs rather than a `RunCompletado` (DM §10.1 sketch), keeping progression decoupled from the
  sync value object.
- `level_02/03.json` reuse level 01's proven-solvable interlocking layout (distinct id/name/
  difficulty) so the catalog has sequential content now; authoring genuinely distinct boards
  that pass the solvability gate is follow-up content work.
- Per-level scoring still comes from `Inyeccion.definicionNivelInicial` (DM §9.4: scoring isn't
  in level files yet) — the offline default, not debt.

## Definition of Done
- Auth → Level Select → Game → (Next/Retry/Menu) flows end-to-end; locks + stars persist across
  restart; no dead-end overlays; Ticket 05 files untouched; `flutter analyze` clean (info only),
  full suite green, web build succeeds.
