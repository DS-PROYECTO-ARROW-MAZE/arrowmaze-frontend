# fix(frontend): restore unlocked levels on login & refresh them on back-navigation

- **Phase:** Hotfix / 6 — regression (progression state sync)
- **Stories:** E4 (restore on login), meta-game progression (ticket 13 regression)
- **Blocked by:** 08 (identity-auth-session), 13 (meta-game loop & progression), 14 (API client)
- **Cross-repo twin:** `arrowmaze-backend` ticket 18 (`GET /progress`) — share one contract.
- **Traceability:** PRD §3 (E-epic) · CLAUDE.md "Puertos / interfaces" (`ConsultaProgresoLocal`,
  `CatalogoNiveles`, `ProveedorSesion`)

> **Two reported bugs in the progression UI:**
>
> 1. **Back-navigation does not refresh unlocked levels.** Returning to Level Select via the
>    **Back** arrow shows stale locks/stars — it only updates when navigating via **Next Level**
>    after a win. The Level Select view must **re-read progression every time it is shown**, not
>    just on the post-victory path.
> 2. **Login does not restore prior progress.** Signing into an existing account starts the
>    frontend from scratch — previously unlocked levels are gone, because the client never reads
>    server-side progress. On login the client must call the new **`GET /progress`** (backend
>    ticket 18), hydrate local progression, and show the player's real unlocked levels.

## User Story

> *As a returning player, when I log in my previously unlocked levels and stars are already
> there; and whenever I press Back to the level menu, what I see is always up to date.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `presentation` (DM-F8) | `SeleccionNivelesViewModel` re-runs `ObtenerNivelesUseCase` on **every** appearance (route re-focus / Back), not only after victory; `SeleccionNivelesView` triggers the refresh on resume |
| `application` | `RestaurarProgresoUseCase` (NEW) — on login, reads remote progress via the API and writes it into `ConsultaProgresoLocal` (merge: keep the **best** stars/score per level) |
| `infrastructure` | API client (ticket 14) gains `GET /progress`; maps the response DTO → local progression records; JWT attached |
| `presentation` | login flow (`AuthViewModel`) awaits restore before routing to Level Select so the first render already reflects server state |

## Acceptance Criteria

1. **Back-nav refresh:** navigating to Level Select by **any** route (Back arrow, Retry→Menu,
   Next Level) shows current locks/stars; the VM re-reads progression on each appearance (no
   stale UI). A level completed in a session is unlocked on the menu without a full app restart.
2. **Login restore:** after a successful login, the client calls `GET /progress`, hydrates
   `ConsultaProgresoLocal`, and Level Select shows the player's real unlocked levels/stars —
   not a from-scratch state.
3. **Merge policy:** restore merges remote into local **keeping the best** per level (a remote
   higher score/stars wins; a locally-better unsynced run is not clobbered).
4. Restore failure (offline/`401`) degrades gracefully: the player still reaches Level Select
   with whatever local progress exists; no crash, no infinite spinner.
5. The contract matches backend ticket 18 exactly (field names + shape); JWT is attached.

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `presentation/seleccion_niveles_viewmodel_test.dart`:
  - `should_reload_progression_when_view_reappears` (AC1 — assert `ObtenerNivelesUseCase` is
    re-invoked on a simulated Back/resume, not only post-victory). Fails today.
- `application/restaurar_progreso_use_case_test.dart` (fake API + fake local store):
  - `should_hydrate_local_progress_from_remote_on_login` (AC2).
  - `should_keep_best_per_level_when_merging_remote_and_local` (AC3).
  - `should_noop_local_state_when_remote_read_fails` (AC4).
- `infrastructure/<api_client>_test.dart`:
  - `should_send_authorization_header_and_parse_get_progress_response` (AC5, golden JSON).

### 🟢 GREEN
- Wire the on-appearance refresh in `SeleccionNivelesViewModel`/View; implement
  `RestaurarProgresoUseCase`; add `GET /progress` to the API client; call restore in the login
  flow before routing.

### ♻️ REFACTOR
- Keep the refresh in the ViewModel layer (Views never call use cases directly); keep restore
  idempotent (re-login does not duplicate or downgrade progress); keep merge a small named policy.

## Definition of Done
- Back-navigation always shows fresh locks/stars; login restores prior unlocked levels via
  `GET /progress`.
- Merge keeps the best per level; offline/`401` degrades gracefully.
- One canonical contract shared with backend ticket 18; `flutter analyze` clean, suite green.

---
**Working agreement (mandatory):** strict **TDD** (🔴→🟢→♻️; a failing regression test first).
**MVVM + Clean Architecture** (CLAUDE.md): Views never call use cases directly; ViewModels never
import `infrastructure/`; `domain`/`application` import **no Flutter**. Keep the read-restore
path **separate** from the offline sync **upload** queue (`IColaSincronizacion`) — different sinks.
