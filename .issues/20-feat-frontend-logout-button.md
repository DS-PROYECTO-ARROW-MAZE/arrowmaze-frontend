# feat(frontend): logout button

- **Phase:** 5 — enhancement (UX)
- **Stories:** E1 (client session — sign-out)
- **Blocked by:** 08 (identity-auth-session)
- **Traceability:** CLAUDE.md "Puertos / interfaces" (`ProveedorSesion.cerrarSesion`)

> Players can sign in but have no way to sign out. The `ProveedorSesion` port already
> exposes `cerrarSesion()`; this ticket surfaces it as a **Logout** button that clears the
> stored token/session and returns the app to the authentication screen.

## User Story

> *As a signed-in player, I can tap Logout to end my session and return to the sign-in
> screen, and my token is cleared so protected calls are no longer authorized.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `application` | `CerrarSesionUseCase` (or reuse the existing session use case) calling `ProveedorSesion.cerrarSesion()` |
| `presentation` | a session/auth ViewModel exposes a `logout()` action and post-logout state; the app host navigates back to the auth screen |
| `presentation` (View) | a Logout button placed in the appropriate screen(s) (e.g. level-selection app bar) — View calls the ViewModel, never the use case directly |

## Acceptance Criteria

1. A visible Logout control exists on the post-login surface (e.g. the level-selection menu).
2. Tapping it calls `ProveedorSesion.cerrarSesion()` (via the ViewModel/use case), clearing
   the persisted token/session.
3. After logout the app returns to the authentication screen; protected routes are no longer
   authorized (no stale token attached).
4. The View never calls the use case directly — it goes through the ViewModel (MVVM rule).

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `application/cerrar_sesion_use_case_test.dart` (fake `ProveedorSesion`) —
  `should_clear_session_when_logout` asserts `cerrarSesion()` is called (AC2).
- `presentation/<auth>_viewmodel_test.dart` —
  `should_expose_logged_out_state_when_logout` (AC3); error path leaves session intact.

### 🟢 GREEN
- Implement the use case + ViewModel action; add the Logout button and post-logout
  navigation back to the auth screen.

### ♻️ REFACTOR
- Keep token clearing entirely behind `ProveedorSesion` (no direct storage access from the
  ViewModel/View, per CLAUDE.md layering).

## Definition of Done
- Logout clears the session and returns to the auth screen; protected calls unauthorized
  afterward.
- MVVM layering respected (View → ViewModel → use case → port); `flutter analyze` clean,
  suite green.
