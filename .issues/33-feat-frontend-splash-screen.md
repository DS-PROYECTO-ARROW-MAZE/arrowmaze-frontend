# feat(frontend): initial splash screen with fade-out into the level menu

- **Phase:** 7 — enhancement (app shell / first-run UX)
- **Stories:** app bootstrap / branding
- **Blocked by:** 08 (identity-auth-session — the auth state we wait on), 14 (API client — resource load)
- **Traceability:** PRD §3 (app shell) · CLAUDE.md "composition root" (`main.dart`, `Inyeccion`)
- **Assets:** `assets/images/ArrowMaze_splash.png` (+ `.svg`), `assets/images/ArrowMaze_icon.png`
  (+ `.svg`). **Note:** `assets/images/` is **not yet registered** in `pubspec.yaml`
  (only `assets/levels/` and `assets/sounds/` are) — this ticket must add it.

> On launch the app shows a **splash screen** immediately (branded with
> `assets/images/ArrowMaze_splash.png`). It stays visible for a short minimum (~2 s) **and** until
> the initial bootstrap finishes — configuration hydration (already awaited in `main`), the initial
> **auth-state** resolution, and any first-run resources — then performs a **smooth fade-out
> transition** into the main **Level Selection** menu (or the login screen when no session exists).
> The splash must never block on a hung network call: the "resources ready" wait is bounded by a
> timeout so a slow/offline start still transitions cleanly.

## User Story

> *As a player opening ArrowMaze, I'm greeted by the game's logo for a beat while it gets ready,
> and it fades gracefully into the menu — never a blank white frame or an abrupt jump.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `presentation` | `SplashView` (NEW) — full-screen branded image + `AnimatedOpacity`/`FadeTransition`; owns the fade-out and calls back when done. No business logic. |
| `presentation` | `SplashViewModel` (NEW, thin) — exposes a `Future<void> listo` that completes when `max(minimoVisible, bootstrap)` resolves; `bootstrap` = config (done) + auth-state probe + optional resource warm-up, each bounded by a timeout |
| `application` | reuse the existing session probe (`ProveedorSesion`, ticket 08) to decide the post-splash route; no new domain concept |
| `core` | `main.dart` composition root routes `SplashView → (AuthView | SeleccionNivelesView)`; `home:` becomes the splash instead of `AuthView` directly |
| `assets` | `pubspec.yaml` — register `assets/images/` so the splash/logo load |

## Acceptance Criteria

1. On launch the splash renders **on the first frame** (no blank/white flash before it).
2. It stays visible for a **minimum ~2 s** *and* until bootstrap (config + auth-state + resources)
   completes — whichever is longer.
3. Bootstrap waits are **bounded by a timeout**: a slow/offline start still transitions (does not
   hang on the splash forever).
4. The transition to the menu is a **smooth fade-out** (opacity animation), not an instant cut.
5. Post-splash routing respects session: existing session → **Level Selection**; none → **login**.
6. The fade controller is disposed on unmount (no ticker leak); the splash is not re-shown on
   in-app navigation (it is a one-time launch screen).

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `presentation/splash_viewmodel_test.dart`:
  - `should_complete_after_minimum_visible_even_if_bootstrap_is_instant` (AC2).
  - `should_wait_for_bootstrap_when_slower_than_minimum` (AC2).
  - `should_complete_within_timeout_when_resources_hang` (AC3, fake clock + never-resolving probe).
  - `should_route_to_menu_when_session_present_and_login_otherwise` (AC5).
- `presentation/splash_view_test.dart` (widget):
  - `should_render_branded_image_on_first_frame` (AC1).
  - `should_fade_out_and_invoke_completion_callback` (AC4).
  - `should_dispose_fade_controller_on_unmount` (AC6).

### 🟢 GREEN
- Add `SplashView` + thin `SplashViewModel`; register `assets/images/`; wire `main.dart` to show the
  splash first and route on completion using the session probe.

### ♻️ REFACTOR
- Keep the minimum-visible duration and bootstrap timeout as single named constants; keep the View
  free of routing/DI (composition root routes); reuse `ProveedorSesion` (no duplicate auth logic).

## Definition of Done
- Splash shows on frame 1, honors the min-visible + bootstrap wait with a timeout, fades smoothly
  into the correct screen by session state, and disposes cleanly.
- `assets/images/` registered; `flutter analyze` clean, full suite green.

---
**Working agreement (mandatory):** strict **TDD** (🔴→🟢→♻️). **MVVM + Clean Architecture**
(CLAUDE.md): the View holds no routing/DI; the ViewModel imports **no Flutter widgets** for its
timing logic; `domain`/`application` import **no Flutter**. Reuse `ProveedorSesion` (ticket 08) for
the auth probe — do not re-implement session detection.
