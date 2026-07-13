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

## Phase 6 — Enhancement batch 2 (tickets 22–30)

> Added 2026-06-24 from the second requirements batch (PRD §12). Ticket **24 is Priority 1**
> (progress-sync regression) and pairs with backend ticket 18.

| Ticket | Phase | Blocked by | Backend twin | Priority |
|---|---|---|---|---|
| 22 path-following (snake-like) exit animation | 6 | 01, 16 | — | — |
| 23 endless generation + aggressive difficulty scaling | 6 | 05, 16, 17 | (PerfilDificultad ~ BE 14/16) | — |
| 24 restore unlocked levels on login & refresh on back-nav | Hotfix | 08, 13, 14 | backend 18 | **1** |
| 25 softer sound effects | 6 | 21 | — | — |
| 26 render irregular board shapes | 6 | 16 | backend 14 | — |
| 27 settings menu — sound toggle + EN/ES i18n | 6 | 08, 21 | — | — |
| 28 invalid-move single alert + haptics | 6 | 01, 02 | — | — |
| 29 timer 15s warning (visual + audio) | 6 | 04, 18, 21 | — | — |
| 30 move countdown + Game Over + undo cap (3) | 6 | 01, 04, 09, 13 | — | — |
| 31 shape-mask rotation on authored catalog (retrofit) | 6 | 16, 23, 26 | — (frontend-only) | — |

- **Grab first:** 24 (P1, with backend 18). 22/25/26/28 are independent off their parents.
  23 needs 16+17; 27 needs 08+21; 29 needs 18; 30 needs 09+13; **31 needs 23** (consumes its
  `RepertorioFormas`) + 16 + 26.
- **Ticket 31 (retrofit):** tickets 17 / backend 16 are already done; 31 regenerates the 15 authored
  `level_XX.json` assets via `tool/generar_niveles.dart` so the shape rotation starts at Level 1 and
  is continuous into 23's endless tail. Frontend-only (boards are frontend assets; backend boards are
  never rendered).
- **Invariant change (ticket 30):** untimed levels **can now lose** via move-budget exhaustion —
  the §7.3 "untimed never reaches `EstadoDerrota`" test is superseded (PRD §12). Update, don't
  work around.

## Phase 7 — Enhancement batch 3 (tickets 32–35)

> Added 2026-07-11 from the third requirements batch. Ticket **32 is Priority 1** (progression
> state-consistency hotfix) and builds directly on ticket 24 / backend ticket 18. All four are
> frontend-only (the `GET /progress` contract already exists on the backend).

| Ticket | Phase | Blocked by | Backend twin | Priority |
|---|---|---|---|---|
| 32 fix unlock-state consistency on login (no phantom locks) | Hotfix | 08, 13, 14, 24 | backend 18 (verify full history) | **1** |
| 33 initial splash screen + fade-out into menu | 7 | 08, 14 | — | — |
| 34 victory confetti on Level Complete (+ cleanup) | 7 | 06, 13, 19 | — | — |
| 35 conditional Hint button (Medium+ & ≤ 25 s) | 7 | 01, 04, 17, 18 | — | — |

- **Grab first:** 32 (P1 — regression of 24; pair by re-checking the backend-18 payload is complete).
  33/34/35 are independent off their parents and can proceed in parallel.
- **Interaction note (35):** the hint time-gate (≤ 25 s) opens **before** the ticket-29 warning
  window (≤ 15 s); both read the **same** timer source (ticket 18) — no second clock. Keep the 25 s
  and 15 s thresholds as sibling named constants.
- **Assets note (33):** `assets/images/` (splash + logo) is **not yet registered** in `pubspec.yaml`
  (only `assets/levels/` and `assets/sounds/` are); ticket 33 adds it.
