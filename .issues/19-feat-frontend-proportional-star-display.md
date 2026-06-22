# feat(frontend): proportional star rating from final score

- **Phase:** 5 — enhancement
- **Stories:** D3 (refinement)
- **Blocked by:** 06 (scoring & stars), 18 (bonus exemption)
- **Cross-repo twin:** `arrowmaze-backend` ticket 17 — **must agree** via golden fixtures.
- **Traceability:** PRD §3 (D3), §7.5 (agreement) · CLAUDE.md DM-F6

> The 1–3 star rating becomes **proportional to the final `Puntaje`** instead of three
> hand-tuned absolute thresholds: stars are derived from `Puntaje` as a fraction of the
> level's achievable maximum, so the rating scales smoothly and consistently across levels.
> The client and backend (ticket 17) must compute **identical** stars for identical inputs.

## User Story

> *As a player, my stars reflect how close my score got to the level's maximum, and the
> client always agrees with the backend.*

## Design decision (shared with backend ticket 17)

- Stars map from `Puntaje / referencia` (the level's achievable maximum, derived from
  `DefinicionNivel`) onto 1/2/3 via fixed **proportional bands** (exact cut points pinned
  in the shared golden fixtures).
- `umbralesEstrellas` are reinterpreted as proportional cut points (or derived from the
  proportion) rather than absolute scores.
- **Bonus levels produce no stars** (ticket 18 short-circuits before star calculation).

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `domain` (DM-F6) | `CalcularPuntuacionUseCase` star step → proportional mapping over `Puntaje`; strategy selection (timed/untimed/bonus) unchanged |
| `domain` | shared golden-score fixtures regenerated for the proportional model (parity w/ backend) |
| `presentation` (DM-F8) | `VictoriaViewState` renders the proportional 1–3 stars (and omits them on bonus) |

## Acceptance Criteria (PRD §3 D3, §7.5)

1. Stars are a proportional function of `Puntaje` relative to the level maximum; boundary
   correctness at each proportional band (just below / at / above).
2. `Puntaje` of 0 → minimum stars; near-maximum `Puntaje` → 3 stars.
3. Bonus levels yield **no** stars (not 0★).
4. **Agreement:** identical inputs → identical `{Puntaje, Estrellas}` on client and backend
   (shared golden fixtures, regenerated in lockstep with backend ticket 17).

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `application/calcular_puntuacion_use_case_test.dart`:
  - `should_return_1_2_3_stars_at_proportional_band_boundaries` (AC1).
  - `should_return_min_stars_when_puntaje_zero` / `should_return_3_stars_near_maximum` (AC2).
  - `should_return_no_stars_when_level_is_bonus` (AC3).
  - `should_match_golden_fixture_scores` (AC4 — same fixtures the backend uses).

### 🟢 GREEN
- Implement the proportional star mapping; derive `referencia` from `DefinicionNivel`.

### ♻️ REFACTOR
- Keep all tuning in `DefinicionNivel` so the band model swaps without touching callers;
  coordinate the fixture bump with backend ticket 17 so both repos flip together.

## Definition of Done
- Proportional star bands boundary-tested; bonus → no stars.
- Golden-score fixtures regenerated and agreeing with the backend (§7.5 agreement green).
- `VictoriaViewState` shows the proportional stars; `flutter analyze` clean, suite green.
