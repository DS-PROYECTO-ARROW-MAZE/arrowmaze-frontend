# 08 · Identity & Session (client side of register/login)

- **Phase:** 2 — PARALLELIZABLE
- **Stories:** E1 (register — client side)
- **Blocked by:** 01
- **Unblocks:** 10 (sync needs a token), 12 (DecoradorSeguridad reads ProveedorSesion)
- **Traceability:** PRD §11 (E1) · tests §7.7

> **Scope:** server-side `User` persistence + unique-email enforcement (`DM-B2/DM-B3`)
> lives in `arrowmaze-backend`. This ticket is the **client** consumer: register/login
> call, token storage via injected port, Pact consumer shape (shared with ticket 10).

## User Story

> *As a guest, I can create an account and stay signed in across sessions on this
> device, with my session carried by an injected port — never a global token.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `domain`/`application` (DM-F9) | `ProveedorSesion.obtenerToken / guardarToken / cerrarSesion` **port** (DIP — injected, **not** a static singleton, ADR-0002) |
| `application` | `RegistrarUsuarioUseCase` / `IniciarSesionUseCase` depending on an auth port + `ProveedorSesion` |
| `infrastructure` | `ProveedorSesionImpl` (secure token storage); `AuthDataSource` (HTTP) + DTOs/mappers |
| `presentation` | auth ViewModel + `*ViewState`; register/login form view |
| `di` | bind `ProveedorSesion` once at composition root |

## Acceptance Criteria (PRD §3 E1, §7.7 — client portion)

1. Valid credentials → register call issued; on success a token is stored via `ProveedorSesion.guardarToken`.
2. Duplicate email → backend domain exception surfaced as a clean, mapped error in the ViewState (no crash).
3. Session is read through the **injected** `ProveedorSesion`, **never** a static/global accessor.
4. `cerrarSesion` clears the stored token.

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `application/registrar_usuario_use_case_test.dart` (fake auth port + fake `ProveedorSesion`):
  - `should_store_token_via_ProveedorSesion_when_register_succeeds` (AC1).
  - `should_surface_mapped_error_when_email_duplicate` (AC2).
- `infrastructure/proveedor_sesion_impl_test.dart`:
  - `should_clear_token_when_cerrarSesion` (AC4).
- `application/session_is_injected_test.dart`:
  - `should_read_session_through_injected_port_not_static_accessor` (AC3 — construct use case with a fake port; assert no static call path).

### 🟢 GREEN
- Implement the port + impl + use cases + DTO mappers; wire DI so `ProveedorSesion` is a single injected instance.

### ♻️ REFACTOR
- Confirm `ConfiguracionManager`/session are **DI-lifetime**, not Singletons (only `AudioServiceImp` is a Singleton — ADR-0002). Align DTO shapes with the Pact consumer used in ticket 10.

## Definition of Done
- Register/login store/clear token via injected port; duplicate-email error mapped; no static session accessor anywhere.
