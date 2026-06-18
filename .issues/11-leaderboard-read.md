# 11 · Leaderboard (read-only projection — client)

- **Phase:** 3 — DOWNSTREAM
- **Stories:** E3 (leaderboard read projection — client side)
- **Blocked by:** 10 (leaderboard reads synced progress)
- **Unblocks:** —
- **Traceability:** PRD §11 (E3) · tests §7.7

> **Scope:** the server projection `IConsultaRanking` + `InterceptorCacheRanking`
> (~60s TTL, `DM-B5`) lives in `arrowmaze-backend`. Here: the **read-only** client
> consumer and the Pact contract. `RankingRepository.publicar()` is **dead weight**
> under the read-only model (PRD §9.5) — do **not** add a client write path.

## User Story

> *As a player, I see top scores per level — read-only, no client publish path.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `domain`/`application` | `IConsultaRanking.obtenerTop(idNivel, limite) → RankingDto` port (**read-only**; no `publicar()`) |
| `infrastructure` | `RankingDataSourceHttp`; DTO/mapper; **Pact consumer** for the ranking response keyed by `(idNivel, limite)` |
| `presentation` | `RankingViewModel` + `RankingViewState` (list of `NivelResumenUI`/score rows) |
| `di` | inject the read port |

## Acceptance Criteria (PRD §3 E3, §7.7 — client portion)

1. Leaderboard returns **top-N** per `(idNivel, limite)`.
2. The client is **read-only** — there is **no** write path / **no** `RankingRepository.publicar` usage.
3. The ranking DTO has a **Pact consumer** contract.

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `application/consulta_ranking_test.dart` (fake read port):
  - `should_return_top_n_for_level_when_obtenerTop_called` (AC1).
- `presentation/ranking_viewmodel_test.dart`:
  - `should_expose_ranking_rows_in_viewstate_when_loaded`.
- `architecture/ranking_is_read_only_test.dart`:
  - `should_have_no_publicar_method_on_ranking_port` (AC2 — assert the port surface; lint forbids `publicar`).
- `infrastructure/ranking_pact_consumer_test.dart`:
  - `should_match_ranking_dto_contract` (AC3).

### 🟢 GREEN
- Implement the read port, http datasource, VM, and Pact consumer. No write methods anywhere.

### ♻️ REFACTOR
- Confirm caching is the backend interceptor's concern, invisible to this read port (the client just calls `obtenerTop`).

## Definition of Done
- Top-N per level renders; no client write path; `publicar` absent; Pact consumer published.
