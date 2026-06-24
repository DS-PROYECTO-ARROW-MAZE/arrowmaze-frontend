# fix(frontend): flush gameplay progress to the backend (Supabase) & show leaderboard

- **Phase:** Hotfix — **Priority 1**
- **Stories:** E2 (client) / E3 (client) — regression
- **Blocked by:** 10 (offline-progress-sync), 11 (leaderboard-read), 14 (API client)
- **Cross-repo twin:** `arrowmaze-backend` ticket 12 — land together; share one contract.
- **Traceability:** PRD §9.4/§9.5 · CLAUDE.md "Puertos / interfaces" (`IRepositorioProgreso`,
  `IColaSincronizacion`, `IConsultaRanking`)

> **Symptom.** Completing a level in the app does **not** persist progress to the backend.
> The database only contains rows inserted by hand via Postman; gameplay never reaches
> Supabase. As a result the **leaderboard appears empty / shows only the Postman seed**.
>
> This is the **client half** of the investigation. The backend twin (ticket 12) proves
> the endpoint persists a correctly-shaped payload; this ticket proves the client actually
> **produces and flushes** that payload on victory, with the agreed field names and a valid
> auth token, and then renders the leaderboard.

## Leading hypotheses (verify against a live backend, do not assume)

1. **Queue never flushes.** Victory enqueues a run into `IColaSincronizacion` but nothing
   ever calls `IRepositorioProgreso.guardarLote(...)` with the pending batch (no flush
   trigger wired into the meta-game loop / app lifecycle).
2. **Contract mismatch.** The client posts `progresos[].tiempoSegundos`, but the backend
   `Progreso`/leaderboard use **`segundosRestantes`** (see ticket 14 API client). A
   whitelist DTO then rejects or drops the field → no row. **Reconcile to one name.**
3. **Auth.** The JWT from login isn't attached (interceptor not applied to `/progress/sync`)
   → `401`, swallowed silently.
4. **Leaderboard read** points at the wrong query params (`nivelId` vs `idNivel`) or never
   refreshes after a sync.

## Investigation checklist (Step 0, before any code)

- [ ] Play a level to victory against a running backend; capture the outbound HTTP request
      (URL, headers, body) and the response status.
- [ ] Confirm a flush is actually invoked on victory (and/or on next app start for the
      offline queue) — trace `JuegoViewModel` victory → queue → repository.
- [ ] Diff the client payload field names against the backend DTO; record the canonical set.
- [ ] Confirm `Authorization: Bearer <token>` is present on the sync + leaderboard calls.

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `presentation` | `JuegoViewModel` — on `EstadoVictoria`, enqueue the completed run **and** trigger a flush (or wire flush into the post-game/app-resume path) |
| `application` | `SincronizarProgresoUseCase` / the flush path over `IColaSincronizacion` + `IRepositorioProgreso.guardarLote` |
| `infrastructure` | the API client (ticket 14): correct endpoint, **reconciled field names**, JWT interceptor; `IConsultaRanking` read for the leaderboard view |
| `presentation` | leaderboard view refreshes after a successful sync |

## Acceptance Criteria

1. Completing a level produces a `POST /progress/sync` that the backend accepts (`201`) and
   that creates a row attributable to the authenticated player.
2. The request body uses the **single canonical contract** agreed with backend ticket 12
   (field names + envelope key) — no divergent `tiempoSegundos`/`segundosRestantes` split.
3. The JWT is attached to both `/progress/sync` and `/leaderboard`.
4. After a sync, the leaderboard view shows the just-played result (not just Postman seed).
5. The offline queue (`IColaSincronizacion`) still drains on the next session if a flush
   failed while offline (no lost runs, no duplicate flush).

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `presentation/juego_viewmodel_test.dart` — on victory, the run is enqueued **and** a flush
  is requested (fake queue + fake repo; assert `guardarLote` is called with the run). This
  should fail today (no flush wired).
- `infrastructure/<api_client>_test.dart` — the serialized sync body matches the agreed
  contract exactly (golden JSON), and the `Authorization` header is present (mocktail).
- `presentation/leaderboard_viewmodel_test.dart` — after a successful sync the VM re-reads
  `IConsultaRanking` and exposes the new entry.

### 🟢 GREEN
- Wire the victory→enqueue→flush path; reconcile the API client field names + envelope to
  the canonical contract; attach the JWT interceptor; refresh the leaderboard post-sync.

### ♻️ REFACTOR
- Keep flush triggering in the ViewModel/use-case layer (Views never call use cases
  directly); keep the queue drain idempotent (no double-send).

## Definition of Done
- A previously-failing victory→sync test is green; real gameplay rows reach the backend.
- One canonical sync contract shared with backend ticket 12 (no field-name split).
- Leaderboard reflects gameplay results; offline queue drains without loss or duplication.
