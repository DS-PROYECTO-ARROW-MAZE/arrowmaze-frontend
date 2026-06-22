# ArrowMaze Frontend — Kanban DAG (Tracer Bullets / Vertical Slices)

> Each ticket is a **vertical slice** crossing every layer of *this* repo
> (`domain → application → presentation → infrastructure`, plus `core`/`di`),
> not a horizontal layer. Every slice ends with a runnable, testable behaviour.
>
> **Scope note:** This is `arrowmaze-frontend`. Backend-only stories — **C3**
> (author/server-gate) and the *server* side of **E1/E2/E3** (`DM-B1…DM-B7`) —
> live in `arrowmaze-backend` and are **out of scope here**. What remains on the
> client is the *consumer / contract* side of auth, sync and leaderboard.

## Dependency graph

```
PHASE 1 — BLOCKING (the spine; nothing ships before it)
┌─────────────────────────────────────────────┐
│ 01 · core-move-mechanic   (A1, A3)           │
│    DM-F1 Tablero/GrafoTablero/raycast        │
│    DM-F2 MoverFlechaUseCase                   │
│    DM-F8 JuegoViewModel/JuegoViewState (thin) │
└───────────────┬─────────────────────────────┘
                │ (every Phase-2 ticket depends on 01)
   ┌────────────┼───────────────┬──────────────┬───────────────┬───────────────┬──────────────┐
   ▼            ▼               ▼              ▼               ▼               ▼              ▼
PHASE 2 — PARALLELIZABLE (each depends only on 01)
02 invalid-     03 collectible-  04 session-     05 level-gen-    06 scoring-     07 observer-   08 identity-
   move-history    passthrough      state-machine   solvability      and-stars       reactions      auth-session
   (A2)            (A4)             (B1,B2,B3)      (C1,C2)          (D1,D2,D3)      (F1)           (E1 client)
   DM-F2+History   DM-F1/F2         DM-F5           DM-F3,F4,F9      DM-F6           DM-F7          DM-F9 ProveedorSesion

PHASE 3 — DOWNSTREAM (depend on Phase-2 results)
09 undo                ← 02, 04
10 offline-progress-   ← 04, 06, 08
   sync (E2 client)
11 leaderboard-read    ← 10
   (E3 client)
12 decorator-stack-&-  ← 05, 08   (cross-cutting Decorator + §7.8 guards)
   arch-guards
```

## Strict blocking dependencies

| Ticket | Phase | Blocked by | Unblocks |
|---|---|---|---|
| 01 core-move-mechanic | 1 | — | 02,03,04,05,06,07,08 |
| 02 invalid-move-history | 2 | 01 | 09 |
| 03 collectible-passthrough | 2 | 01 | — |
| 04 session-state-machine | 2 | 01 | 09,10 |
| 05 level-generation-solvability | 2 | 01 | 12 |
| 06 scoring-and-stars | 2 | 01 | 10 |
| 07 observer-reactions | 2 | 01 | — |
| 08 identity-auth-session | 2 | 01 | 10,12 |
| 09 undo | 3 | 02, 04 | — |
| 10 offline-progress-sync | 3 | 04, 06, 08 | 11 |
| 11 leaderboard-read | 3 | 10 | — |
| 12 decorator-stack-&-arch-guards | 3 | 05, 08 | — |

## Grab order

- **Sprint 0:** one pair takes **01** to green before anything else starts.
- **Sprint 1:** 02–08 can all be picked up in parallel by independent owners.
- **Sprint 2:** 09–12 unlock as their parents merge.

Story→module→test traceability mirrors PRD §11 / §7.

## Phase 5 — Enhancement batch (tickets 15–21)

> Added after the MVP graph above. Ticket **15 is Priority 1** (hotfix) and pairs with backend
> ticket 12. Diagram deltas are planned in `DIAGRAM-RECONCILIATION.md §11`.

| Ticket | Phase | Blocked by | Backend twin | Priority |
|---|---|---|---|---|
| 15 fix flush gameplay progress & leaderboard | Hotfix | 10, 11, 14 | backend 12 | **1** |
| 16 dynamic board shapes + arrow-length-≥2 | 5 | 01, 05 | backend 14 | — |
| 17 level catalog of 15+ levels (scaling) | 5 | 05, 13, 16 | backend 16 | — |
| 18 timer rules — timed ≥10, bonus exemption | 5 | 04, 06, 17 | backend 15 | — |
| 19 proportional star display | 5 | 06, 18 | backend 17 | — |
| 20 logout button | 5 | 08 | — | — |
| 21 audio sound effects (Observer) | 5 | 07 | — | — |

- **Grab first:** 15 (P1, with backend 12). 16/20/21 are independent off their parents. 17 needs
  16 + ticket 13; 18 needs 17; 19 needs 18.
- **Cross-repo agreement:** 16 (shaped golden boards), 17 (`PerfilDificultad`), 19 (golden scores)
  stay in lockstep with their backend twins.
