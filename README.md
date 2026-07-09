# ArrowMaze

Flutter clone of the game **Arrow Maze — Escape Puzzle** (SayGames Ltd.).
University project in **Desarrollo de Software** course. **NRC 25783**.

**Gameplay:** the player taps cells containing arrows; a arrow traces the full
arrow chain until it hits a wall or reaches an empty destination. The goal is
to clear the board using as few moves as possible.

---

## Development Team — TEAM 01

| Member | ID Number |
|---|---|
| Blanco, Antonio | 20.613.680 |
| Márquez,Jac José | 29.710.631 |
| Fes, Mariana | 30.751.220 |

---

## Theoretical Foundation

The project architecture is grounded in the official
**[Flutter App Architecture Guide](https://docs.flutter.dev/app-architecture/guide)**
and the principles of **Clean Architecture** (Robert C. Martin).

### MVVM + Clean Architecture — 4 Layers

The project separates concerns into four layers with a strict Dependency Rule:
inner layers never import outer layers. `domain/` and `application/` are pure
Dart — **zero Flutter imports**.

| Layer | Directory | Responsibility |
|---|---|---|
| **UI Layer** | `presentation/` | Views (pure widgets, no business logic) + ViewModels (logic, state, commands via `ChangeNotifier`). 1:1 View ↔ ViewModel relationship. |
| **Application Layer** | `application/` | Use cases (interactors), cross-cutting decorators, generation strategies. Depends only on domain interfaces. |
| **Domain Layer** | `domain/` | Entities, value objects, ports (abstract interfaces), session (GoF State). Pure core with no external dependencies. |
| **Data Layer** | `infrastructure/` | Concrete implementations: HTTP, local persistence, audio, haptics. Implement the ports defined in `domain/`. |

**Composition root:** `lib/di/inyeccion.dart` — single point where all
dependencies are instantiated and wired together. Equivalent to a manual DI
container.

### 8 Implemented GoF Design Patterns

| Pattern | Location | Role |
|---|---|---|
| **Factory Method** | `FabricaCeldasEstandar` (`domain/entities/`) | Creates cells and arrow paths from JSON definitions |
| **State** | `EstadoSesion` + `SesionJuego` (`domain/sesion/`) | 4 sealed states: Playing, Paused, Victory, Defeat |
| **Command** | `PlayerMoveCommand` + `CommandHistory` (`application/use_cases/`) | Encapsulates each tap; enables undo |
| **Observer** | `PublicadorEventosJuego` + `ObservadorJuego` (`domain/`) | Decouples audio/UI rules from game logic |
| **Strategy** | `EstrategiaPuntuacion` (`domain/puntuacion/`) + `GeneradorNivelBase` (`application/generadores/`) | Scoring (mixed/move-based) + level generation (random/file) |
| **Singleton** | `AudioServiceImp.instance` (`infrastructure/audio/`) | Single audio service instance |
| **Decorator** | `DecoradorCasoDeUso` + 3 decorators (`application/decoradores/`) | Security → Logging → Metrics stack around any use case |
| **Template Method** | `GeneradorNivelBase` (`application/generadores/`) | Generation skeleton with mandatory `validarSolvencia()` step |

### Key Principles

- **Separation of Concerns**: Views never call use cases directly — everything goes through the ViewModel.
- **Dependency Inversion (DIP)**: `domain/` defines ports (interfaces); `infrastructure/` implements them. Higher layers depend on abstractions, not concretions.
- **Single Composition Root**: the entire object graph is assembled in `Inyeccion`.

---

## Architecture Diagram

![Architecture diagram](docs/arquitectura-arrowmaze.png)

*The diagram shows the 4 layers, their internal components, the direction of
dependencies (→ toward the domain) and the data flow from the UI to the
external services.*

---

## Screens

The game features seven main screens, each with a distinct role in the user flow:

| # | Screen | Image | Function |
|---|---|---|---|
| 1 | **Login** | ![Login](assets/images/1-Login-Screen.png) | User authentication — register or log in with credentials. Entry point for session-based features (progress sync, leaderboard). |
| 2 | **Gameplay** | ![Gameplay](assets/images/2-GamePlay-Screen.png)| Main game screen — grid of arrow cells, ray traversal, move counter, timer, and undo button. |
| 3 | **Level Selection** | ![Level Selection](assets/images/3-LevelSelection-Screen.png) | Level catalog with unlock status — browse levels, see star ratings, and pick a level to play. |
| 4 | **Victory** | ![Victory](assets/images/4-Victoria-Screen.png) | End-of-level success screen — displays score, star rating, and options to replay or go to level selection. |
| 5 | **Defeat** | ![Defeat](assets/images/5-Derrota-Screen.png) | End-of-level failure screen — shown when the timer expires or moves run out, with retry and quit options. |
| 6 | **Pause** | ![Pause](assets/images/6-Pausa-Screen.png) | Pause overlay — freezes the game clock and hides the board, offering resume, restart, and quit controls. |
| 7 | **Settings** | ![Settings](assets/images/7-Setting-Screen.png) | Settings screen — toggle sound effects on/off and switch language between English and Spanish. |

---

## Quick Commands

```sh
flutter test                          # full suite (226 tests)
flutter test test/presentation/juego_viewmodel_sync_test.dart  # single file
flutter analyze                       # linter — 0 errors / 0 warnings expected
flutter build web                     # production build
flutter pub outdated                  # check compatibility
```

Always run `flutter analyze` after touching new code; the project tolerates
0 errors and 0 warnings.

---

## Project Structure

```
lib/
├── main.dart                         # Entry point, routing, _JuegoHost
├── domain/                           # Pure Dart — entities, ports, value objects
│   ├── entities/                     # Celda (sealed, 5 variants), Trayectoria, FabricaCeldasEstandar
│   ├── sesion/                       # EstadoSesion (State pattern, 4 states), SesionJuego
│   ├── puntuacion/                   # EstrategiaPuntuacion, PuntuacionMixta, PuntuacionPorMovimientos
│   ├── niveles/                      # Dificultad, MascaraForma, ReglaDesbloqueo, RepertorioFormas
│   ├── value_objects/                # Posicion, Direccion, Vector3, PresupuestoMovimientos
│   ├── ranking/                      # FilaRanking, RankingDto
│   └── progreso/                     # IColaSincronizacion, RunCompletado
├── application/                      # Use cases + decorators + strategies
│   ├── use_cases/                    # MoverFlecha, DeshacerMovimiento, SincronizarProgreso, etc.
│   ├── decoradores/                  # DecoradorSeguridad → DecoradorRegistro → DecoradorMetricas
│   ├── generadores/                  # GeneracionAleatoriaNivel, GeneracionPorArchivoNivel
│   └── ports/                        # Interfaces: Reloj, ProveedorSesion, CatalogoNiveles, etc.
├── infrastructure/                   # Concrete implementations (Flutter, HTTP, audio)
│   ├── audio/                        # AudioServiceImp (Singleton + Observer)
│   ├── network/                      # ClienteHttpAutenticado (Bearer token interceptor)
│   ├── progreso/                     # ColaSincronizacionLocal, ProgresoLocalPersistente
│   ├── niveles/                      # CatalogoNivelesArchivo, CatalogoNivelesRemoto
│   ├── sesion/                       # ProveedorSesionPersistente (shared_preferences + JWT)
│   ├── reloj/                        # RelojTimer
│   ├── haptica/                      # HapticFeedbackFlutter
│   ├── observabilidad/               # RegistroConsola, MedidorMetricasSimple
│   └── dtos/                         # JSON serialization DTOs for each endpoint
├── presentation/                     # MVVM: Views + ViewModels
│   ├── viewmodels/                   # JuegoViewModel, AuthViewModel, RankingViewModel, etc.
│   └── views/                        # game/, auth/, ranking/, seleccion/, settings/, sync/
├── core/                             # Theme, i18n, configuration, utilities
│   ├── theme/                        # AppTheme (dark), AppColors, AppTypography, GameTheme
│   ├── i18n/                         # Cadenas (ES/EN), LocalizacionesProvider
│   ├── config/                       # ApiConfig (base URL configurable via --dart-define)
│   └── animacion/                    # MuestreadorTrayectoria (ray path animation)
└── di/
    └── inyeccion.dart                # Composition root — wiring of all dependencies
```

Tests mirror the structure: `test/domain/`, `test/application/`,
`test/infrastructure/`, `test/presentation/`, `test/architecture/`.

---

## Assets

- `assets/levels/level_XX.json` — preloaded levels with cell definitions
- `assets/sounds/*.wav` — sound effects: move, invalid, collect, victory, defeat

---

## Backend / API

- **Base URL** configurable via `--dart-define=API_BASE_URL=...` (default: `http://localhost:3000`)
- **Authentication**: JWT persisted in `shared_preferences`, automatically attached to protected requests via `ClienteHttpAutenticado` (`http.BaseClient` subclass)
- **Endpoints**:
  - `POST /auth/register` — user registration
  - `POST /auth/login` — user login
  - `GET /auth/me` — authenticated user profile
  - `POST /progress/sync` — batch offline progress synchronization
  - `GET /leaderboard?nivelId=...&limite=...` — level leaderboard
- **IDs**: local levels use `int`; the API uses `String` (UUID). Conversion in `main.dart`.

---

## Dependencies

| Package | Purpose |
|---|---|
| `http` | HTTP client for backend communication |
| `shared_preferences` | Persistence of JWT, local progress, and user preferences |
| `audioplayers` | Game sound effects |
| `mocktail` | Mocking library for testing (project standard) |