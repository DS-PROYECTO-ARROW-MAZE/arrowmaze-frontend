# 10 · Offline Progress Sync (client queue + upload)

- **Phase:** 3 — DOWNSTREAM
- **Stories:** E2 (sync offline progress — client side)
- **Blocked by:** 04 (victory produces a run), 06 (puntaje/estrellas), 08 (token)
- **Unblocks:** 11 (leaderboard reads synced progress)
- **Traceability:** PRD §11 (E2) · tests §7.7

> **Scope:** the backend's atomic `RepositorioProgreso.guardarLote` + `$transaction`
> (`DM-B3`, ADR-0003) is **out of scope** in this repo. Here: offline queue, batch
> upload call, and the Pact **consumer** contract for the sync DTO.

## User Story

> *As a returning player, my completed offline runs upload as one batch when I sync.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `domain`/`application` | `IRepositorioProgreso`/`ColaSincronizacion` port; `SincronizarProgresoUseCase`; offline-first queue of completed runs (`movimientos`, `segundosRestantes`, `puntaje`, `estrellas`, `completadoEn`) |
| `infrastructure` | local queue datasource (offline) + `ProgresoDataSourceHttp`; DTOs/mappers; **Pact consumer** for the sync request/response shape |
| `presentation` | sync status in a VM/`ViewState` (queued / syncing / synced) |
| `di` | inject the queue + http datasource + `ProveedorSesion` token |

## Acceptance Criteria (PRD §3 E2, §7.7 — client portion)

1. Completed runs are **queued offline** with no network.
2. On sync, the queue uploads as **one batch** request (single call, not N).
3. The sync DTO has a **Pact consumer** contract; CI fails on shape drift.
4. A failed sync leaves the queue intact for retry (no silent data loss).

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `application/sincronizar_progreso_use_case_test.dart` (fake queue + fake http port):
  - `should_queue_run_offline_when_no_network` (AC1).
  - `should_upload_all_queued_runs_as_single_batch_when_sync` (AC2).
  - `should_keep_queue_intact_when_sync_fails` (AC4).
- `infrastructure/progreso_pact_consumer_test.dart`:
  - `should_match_sync_dto_contract` (AC3 — generate consumer pact for provider verification).

### 🟢 GREEN
- Implement queue + use case + http datasource + DTO mappers + Pact consumer.

### ♻️ REFACTOR
- Keep the application layer naming **ports only** — never Prisma, never `$transaction` (those are the backend adapter's concern, ADR-0003).

## Definition of Done
- Runs queue offline; sync sends one batch; queue survives failure; Pact consumer contract published.
