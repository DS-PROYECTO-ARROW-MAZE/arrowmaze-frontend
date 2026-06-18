# 06 · Scoring & Stars (deterministic, data-driven)

- **Phase:** 2 — PARALLELIZABLE
- **Stories:** D1 (deterministic score), D2 (strategy selection), D3 (stars)
- **Blocked by:** 01
- **Unblocks:** 10 (sync uploads puntaje/estrellas)
- **Traceability:** PRD §11 (D1–D3) · tests §7.5

## User Story

> *As a player, my score reflects skill (fewer moves, more time left), and I get a
> 1–3 star rating that the client and backend always agree on.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `domain` (DM-F6) | `EstrategiaPuntuacion` (GoF **Strategy**): `PuntuacionMixta` (timed), `PuntuacionPorMovimientos` (untimed). **`PuntuacionPorTiempo` must NOT exist.** |
| `domain` | `DefinicionNivel` holds tuning **data**: `baseNivel`, `Kmov`, `Ktiempo`, `umbralesEstrellas` (3 thresholds), `limiteTiempo?` |
| `application` | `CalcularPuntuacionUseCase.calcular(...) → ResultadoPuntaje { Puntaje, Estrellas }` — selects strategy from level data; applies star thresholds |
| `presentation` (DM-F8) | `VictoriaViewState` shows `Puntaje` + stars |

## Acceptance Criteria (PRD §3 D1–D3, §7.5)

1. Timed: `Puntaje == max(0, baseNivel − movimientos·Kmov + segundosRestantes·Ktiempo)`.
2. Untimed **drops the time term**; floor at 0 (large `movimientos` → 0, never negative).
3. Strategy selection: timed→`PuntuacionMixta`, untimed→`PuntuacionPorMovimientos`.
4. Stars: boundary correctness at each of the three `umbralesEstrellas` (just below / at / above).
5. **Agreement:** identical inputs → identical `{Puntaje, Estrellas}` on client and backend (shared golden fixtures).

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `domain/puntuacion_mixta_test.dart`:
  - `should_apply_full_formula_when_level_is_timed` (AC1).
- `domain/puntuacion_por_movimientos_test.dart`:
  - `should_drop_time_term_when_level_is_untimed` (AC2).
  - `should_floor_at_zero_when_movimientos_large` (AC2).
- `application/calcular_puntuacion_use_case_test.dart`:
  - `should_select_PuntuacionMixta_when_timed` / `should_select_PuntuacionPorMovimientos_when_untimed` (AC3).
  - `should_return_1_2_3_stars_at_threshold_boundaries` (AC4 — three boundary triplets).
  - `should_match_golden_fixture_scores` (AC5 — same fixtures the backend uses).

### 🟢 GREEN
- Implement both strategies + `CalcularPuntuacionUseCase`. Strategy chosen from `DefinicionNivel` (data), never a subtype/`if` on difficulty.

### ♻️ REFACTOR
- Keep all tuning in `DefinicionNivel` so the algorithm swaps without touching callers.
- Add a `PuntuacionPorTiempo`-absence assertion (covered fully by ticket 12 language guard).

## Definition of Done
- Formula, floor, strategy selection and star boundaries all green; golden-fixture parity scaffolded for cross-repo agreement.
