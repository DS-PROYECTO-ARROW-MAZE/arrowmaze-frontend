# 12 · Use-case Decorator Stack + Architecture Guards

- **Phase:** 3 — DOWNSTREAM
- **Stories:** F1 (app-level cross-cutting via Decorator) + §7.8 architecture guards
- **Blocked by:** 05 (real use cases to wrap), 08 (`ProveedorSesion` for security decorator)
- **Unblocks:** —
- **Traceability:** PRD §11 (F1, all) · tests §7.6, §7.8

## User Story

> *As a maintainer, I want metrics/logging/security added by composition around any
> use case — with no framework leaking into the domain — and automated guards that
> keep the architecture and ubiquitous language honest.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `application` (DM-F9) | `DecoradorCasoDeUso<E,S>` (abstract) + `DecoradorMetricas/Registro/SeguridadCasoDeUso` wrapping `ICasoDeUso<E,S>` — all depend on **ports** (`IMedidorMetricas`, `IRegistro`, `ProveedorSesion`) |
| `infrastructure` | real adapters only here: `RegistroConsola`, `MedidorMetricasSimple` |
| `core`/CI | dependency-direction lint; domain-purity check; ubiquitous-language guard |
| `di` | compose decorator stacks around chosen use cases |

## Acceptance Criteria (PRD §7.6, §7.8)

1. A use case wrapped by the decorators returns the **same** result; metrics/logging/security ports are invoked.
2. **No logging/metrics library imported** in the decorator (dependency-direction lint / static import assertion).
3. `DecoradorSeguridad` reads session via injected `ProveedorSesion`, **never** a static accessor.
4. **Domain purity:** `domain/` imports no Flutter/Nest/Prisma/logging/metrics symbols (ADR-0004).
5. **Language guard:** forbids avoid-list identifiers — `CeldaSalida`, `*Decorator` cells, `Composite`, `NivelFacil/Medio/Dificil`, `PuntuacionPorTiempo`, plural `CargadorNiveles`.

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `application/decorador_caso_de_uso_test.dart` (spy ports via mocktail):
  - `should_return_same_result_when_wrapped_by_decorators` (AC1).
  - `should_invoke_metrics_logging_security_ports_when_executed` (AC1).
  - `should_read_session_via_injected_ProveedorSesion_when_securing` (AC3).
- `architecture/dependency_direction_test.dart`:
  - `should_not_import_logging_or_metrics_library_in_decorator` (AC2).
  - `should_keep_domain_free_of_frameworks` (AC4 — scan `lib/domain` imports).
- `architecture/ubiquitous_language_test.dart`:
  - `should_forbid_avoid_list_identifiers_in_lib` (AC5 — grep the tree, fail on any hit).

### 🟢 GREEN
- Implement the abstract decorator + three concrete decorators against ports. Implement the import/identifier scans as Dart tests (or `dart analyze` custom lint) wired into CI.

### ♻️ REFACTOR
- Compose stacks at the DI root so use cases are edited **never** to add cross-cutting — the "AOP via SOLID, no library" showcase (ADR-0004).
- Add these guards to the CI quality gate alongside the ≥90% coverage and golden-board jobs.

## Definition of Done
- Decorated use cases behave identically while invoking ports; domain-purity, dependency-direction and language guards all green in CI.
