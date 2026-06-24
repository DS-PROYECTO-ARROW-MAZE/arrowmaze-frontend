# feat(frontend): level catalog of 15+ integer-identified levels with scaling complexity

- **Phase:** 5 — enhancement
- **Stories:** C1/C2 + meta-game progression (extends ticket 13)
- **Blocked by:** 05 (generation), 13 (meta-game loop), 16 (shapes)
- **Cross-repo twin:** `arrowmaze-backend` ticket 16 (catalog endpoint / seed)
- **Traceability:** DR §10 (FRONTEND-03) · §11 (FRONTEND-04) · CLAUDE.md "Formato JSON"

> Ticket 13 built the selection menu + unlock engine but shipped with only a couple of
> near-duplicate levels (flagged as content debt). This ticket delivers the real
> progression: **at least 15 levels identified by an integer ordinal (1, 2, 3 …)** where
> **complexity (cells, arrows) increases with the level number**, surfaced in the existing
> `SeleccionNivelesView`. Levels load from the backend catalog (backend ticket 16) when
> online, falling back to bundled assets offline.

## User Story

> *As a player, I can choose from 15+ ordered levels that get progressively harder, see my
> best stars on each, and unlock them in sequence.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `domain` | `ResumenNivel`/`NivelConEstado` carry the integer `numero`; ordering is by `numero` |
| `domain`/`application` (DM-F3) | a complexity profile (`numero → target cells/arrows`) the generator honours, mirroring backend ticket 16's `PerfilDificultad` for agreement |
| `application` | `CatalogoNiveles` port (reserved in ticket 13) gains a **remote** implementation; `ObtenerNivelesUseCase` lists ≥15 ordered levels with unlock state |
| `infrastructure` | `CatalogoNivelesRemoto` (calls `GET /levels`, ticket 16) with `CatalogoNivelesArchivo` (bundled assets) as offline fallback |
| `presentation` | `SeleccionNivelesViewModel`/`View` render a scrollable 15+ catalog with stars + locks |
| `assets` | bundled `level_01.json … level_15.json` (offline fallback, scaling complexity) |

## Acceptance Criteria

1. The selection menu lists **≥15 levels ordered by integer `numero`**, each showing best
   stars and lock state (level 1 open; level *N* locked until *N−1* completed — ticket 13).
2. Complexity **increases with `numero`** (more cells/arrows), agreeing with the backend
   profile (cross-repo consistency, not just visually plausible).
3. Levels load from the backend catalog when authenticated/online; bundled assets are used
   as an offline fallback without crashing.
4. Boards may be shaped (ticket 16) and respect the arrow-length-≥2 invariant.
5. The unlock/progression engine and persisted best-stars from ticket 13 are reused
   unchanged (this ticket adds content + the remote catalog, not a new lock model).

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `application/obtener_niveles_use_case_test.dart` — returns ≥15 entries ordered by `numero`
  with correct unlock state from fake `CatalogoNiveles` + progress (AC1).
- `domain/perfil_dificultad_test.dart` — monotonic non-decreasing cells/arrows over 1…15;
  level 10 ≥ level 1 (AC2).
- `infrastructure/catalogo_niveles_remoto_test.dart` (fake http) — maps `GET /levels` to
  `ResumenNivel`; falls back to assets on network error (AC3).

### 🟢 GREEN
- Implement the remote catalog adapter + fallback; add the complexity profile; author the
  15 bundled fallback levels (each solvable, length-≥2, scaling).

### ♻️ REFACTOR
- Keep the catalog source behind the `CatalogoNiveles` port (remote/asset swap with no VM
  change); keep the profile pure data shared in spirit with backend ticket 16.

## Definition of Done
- ≥15 ordered, integer-`numero` levels selectable with stars + locks (ticket 13 reused).
- Complexity scales with `numero`, agreeing with the backend profile.
- Remote catalog with offline asset fallback; `flutter analyze` clean, suite green.
