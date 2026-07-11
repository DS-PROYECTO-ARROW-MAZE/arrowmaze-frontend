# fix(frontend): unlock state must match play history for returning users (no phantom locks)

- **Phase:** 7 — Hotfix (progression state consistency)
- **Stories:** E4 (restore on login), meta-game progression (ticket 13 / 24 regression)
- **Blocked by:** 08 (identity-auth-session), 13 (meta-game loop & progression), 14 (API client),
  24 (restore-on-login & back-nav refresh)
- **Cross-repo twin:** `arrowmaze-backend` ticket 18 (`GET /progress`) — same contract; verify the
  server returns the **full** completed-set (a truncated payload would reproduce this bug too).
- **Traceability:** PRD §3 (E-epic) · CLAUDE.md "Puertos / interfaces" (`ConsultaProgresoLocal`,
  `CatalogoNiveles`) · `regla_desbloqueo.dart` (`ReglaDesbloqueoSecuencial`)

> **Bug — phantom lock on already-earned levels.** When a returning user logs in, some levels
> they have already played render **locked** (padlock) even though *later* levels show earned
> stars. Observed: **Level 6 shows a padlock while Levels 7 and 8 show progress with stars.**
> This is internally contradictory: `ReglaDesbloqueoSecuencial` unlocks level *N* only when
> *N − 1* is completed, so if 7 and 8 are unlocked/completed, 6 **must** be treated as completed.
> The unlock state must consistently reflect the user's real play history.
>
> **Likely root cause (to be confirmed during investigation):** the completed-set that hydrates
> `ConsultaProgresoLocal` on login (ticket 24's `RestaurarProgresoUseCase` + `GET /progress`) is
> **incomplete or mis-keyed** — e.g. missing intermediate ids, id type mismatch (remote UUID vs.
> local ordinal), or a merge that drops levels present remotely but not locally. `ObtenerNivelesUseCase`
> then joins a partial set, so `estaDesbloqueado(6, completados)` returns false while 7/8 still
> read as completed from their own records. Grid rendering faithfully shows a wrong model.

## User Story

> *As a returning player, when I log in every level I have already cleared is unlocked and shows
> its stars — I never see a locked padlock on a level that sits before ones I've already played.*

## Investigation checklist (must be worked, not assumed)

1. **User state logic** — `RestaurarProgresoUseCase` merge: does it write **every** completed id
   from the remote payload into `ConsultaProgresoLocal`? Is the merge keyed on the same id space
   the unlock rule reads (`resumen.id` ordinal)?
2. **Data fetching** — the `GET /progress` response shape vs. backend ticket 18: confirm the server
   returns the complete history (not paginated/most-recent-N) and that every entry maps to a catalog id.
3. **Grid rendering** — `ObtenerNivelesUseCase` / `SeleccionNivelesViewModel` / `SeleccionNivelesView`:
   confirm locks come **only** from `NivelConEstado.desbloqueado` and stars from `completado`, with no
   independent per-cell recompute that could disagree with the rule.

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `application` | `RestaurarProgresoUseCase` (ticket 24) — hydration writes the **complete** completed-set into `ConsultaProgresoLocal`; id mapping remote→local is total and lossless |
| `application` | `ObtenerNivelesUseCase` — join + `ReglaDesbloqueo` is the single source of the lock flag; add a consistency assertion helper only if it clarifies intent |
| `domain` | `ReglaDesbloqueoSecuencial` — unchanged rule; add a **monotonicity invariant** test: an unlocked level implies all prior levels unlocked |
| `infrastructure` | API client `GET /progress` mapper — parses the full history; no silent drop on unknown/extra fields |
| `presentation` | `SeleccionNivelesViewModel` / `SeleccionNivelesView` — locks/stars derive solely from `NivelConEstado`; no divergent local computation |

## Acceptance Criteria

1. **No phantom locks:** after login for a user whose history includes Levels 7–8, Levels 1–6 render
   **unlocked** with their stars; the padlock never appears on a level preceding an unlocked one.
2. **Monotonic unlock invariant:** for the rendered catalog, if level *N* is unlocked then every level
   `< N` is unlocked. A regression test enforces this over any restored completed-set.
3. **Full hydration:** `RestaurarProgresoUseCase` writes **every** completed id from `GET /progress`
   into local progress; a golden remote payload (sparse ids 1–8) round-trips with none dropped.
4. **Id-space integrity:** remote entries map to the exact catalog id the unlock rule reads; a
   UUID/ordinal mismatch is caught by a test, not shipped.
5. **Graceful degrade unchanged:** offline / `401` still reaches Level Select with local progress
   (ticket 24 AC4 preserved); no crash, no infinite spinner.

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `application/obtener_niveles_use_case_test.dart`:
  - `should_never_lock_a_level_before_an_unlocked_one` (AC2 — feed a completed-set `{1..8}` minus a
    middle id to simulate the bug; assert the invariant fails today, passes after fix).
- `application/restaurar_progreso_use_case_test.dart`:
  - `should_hydrate_every_completed_id_from_remote` (AC3, golden sparse payload).
  - `should_map_remote_ids_to_catalog_ids_without_loss` (AC4).
- `presentation/seleccion_niveles_viewmodel_test.dart`:
  - `should_render_level6_unlocked_when_levels_7_and_8_are_completed` (AC1 — the exact reported case).
- `infrastructure/<api_client>_test.dart`:
  - `should_parse_full_progress_history_without_dropping_entries` (AC3/AC4, golden JSON).

### 🟢 GREEN
- Fix the hydration/merge and id mapping so the complete history reaches `ConsultaProgresoLocal`;
  ensure the ViewModel/View read locks only from `NivelConEstado`.

### ♻️ REFACTOR
- Keep the unlock rule the single source of truth; express the monotonicity invariant as a named,
  reusable assertion; keep id mapping in one place (no scattered casts).

## Definition of Done
- The reported case (L6 locked while L7/L8 have stars) is reproduced by a failing test, then fixed.
- Unlock state is monotonic and matches play history after login and on every Level Select appearance.
- Contract matches backend ticket 18; `flutter analyze` clean, full suite green.

---
**Working agreement (mandatory):** strict **TDD** (🔴→🟢→♻️; a failing regression test first).
**MVVM + Clean Architecture** (CLAUDE.md): Views never compute locks; ViewModels never import
`infrastructure/`; `domain`/`application` import **no Flutter**. This is the **read/restore** path
(shared with ticket 24) — keep it separate from the offline upload queue (`IColaSincronizacion`).
