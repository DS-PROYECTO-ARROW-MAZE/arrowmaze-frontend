# AGENTS.md — ArrowMaze Frontend

Leído automáticamente por OpenCode. Respeta todas las secciones.

## Proyecto

Clon Flutter del juego Arrow Maze - Escape Puzzle (SayGames Ltd.).
Cuadrícula: el jugador toca flechas, el rayo recorre la cadena hasta destino
o pared. Proyecto universitario NRC 25783.

## Comandos exactos

```sh
flutter test                          # suite completa (226 tests)
flutter test test/presentation/juego_viewmodel_sync_test.dart  # un archivo
flutter analyze                       # linter — 0 errors / 0 warnings esperado
flutter build web                     # build producción
flutter pub outdated                  # revisar compatibilidades
```

`flutter analyze` **siempre** después de tocar código nuevo; el proyecto
tolera 0 errores. Correr antes del commit.

## Arquitectura: MVVM + Clean Architecture estricta

`lib/domain/`         → Dart puro. CERO imports de Flutter.
`lib/application/`    → Casos de uso. Solo depende de interfaces de `domain/`.
`lib/presentation/`   → MVVM: Views + ViewModels (usa Flutter).
`lib/infrastructure/` → Flutter, HTTP, audio, persistencia.
`lib/core/`           → Tema, configuración de API, utilidades.
`lib/di/`             → `Inyeccion` — composition root único.

Reglas absolutas:
- domain/ y application/ **nunca** importan Flutter
- Views nunca llaman casos de uso — todo pasa por el ViewModel
- ViewModels nunca importan infrastructure/ directamente

Tests espejan la estructura: `test/domain/`, `test/application/`,
`test/infrastructure/`, `test/presentation/`, `test/architecture/`.

## Entidades del dominio (domain/entities/)

`Celda` — sealed class, 4 variantes:
- `CeldaFlecha` — segmento de trayectoria, `bloqueaRayo: true`
- `CeldaPared` — bloquea el rayo
- `CeldaVacia` — transparente
- `Coleccionable` — transparente, `esColeccionable: true`, otorga bonus

Las celdas se crean con `FabricaCeldasEstandar`. **No hay decoradores de celdas**
— el type system sealed + propiedades polimórficas reemplaza al Decorator.

## Puertos/interfaces clave (application/ports/)

| Puerto | Método(s) | Propósito |
|---|---|---|
| `Tablero` (domain/) | `celdaEn`, `trayectoriaEn`, `raycast`, `eliminarTrayectoria`, `restaurarTrayectoria`, `estaVacio` | Board port — OCP |
| `Reloj` | `iniciar(intervalo, tic)`, `detener()` | Timer abstraction |
| `ProveedorSesion` | `obtenerToken`, `guardarToken`, `cerrarSesion` | JWT session |
| `FuenteAutenticacion` | `registrar`, `iniciarSesion`, `obtenerPerfil` | Auth API |
| `IColaSincronizacion` | `encolar`, `obtenerPendientes`, `vaciar`, `cantidadPendientes` | Cola offline |
| `IRepositorioProgreso` | `guardarLote` | Batch upload |
| `IConsultaRanking` | `obtenerTop(nivelId, limite)` | Read-only |
| `ConsultaProgresoLocal` | `nivelesCompletados`, `mejorEstrellas`, `registrarCompletado` | Persistencia local |
| `CatalogoNiveles` | `obtenerIds`, `obtenerNivel` | Catálogo desde assets |
| `IControlAudio` | `muted`, `toggleMute()` | Audio control |
| `CargadorNivel` (deprecated) | `cargar(idNivel)` → `DefinicionNivelDto` | Niveles por archivo |

## Casos de uso (application/use_cases/)

`MoverFlechaUseCase` — central: recibe `Tablero`, `SesionJuego`,
`CommandHistory`, emite eventos vía `PublicadorEventosJuego`.

Otros: `DeshacerMovimientoUseCase` (undo vía Command), `CalcularPuntuacionUseCase`
(Strategy de puntuación), `RegistrarUsuarioUseCase`, `IniciarSesionUseCase`,
`CerrarSesionUseCase`, `SincronizarProgresoUseCase` (offline→batch→flush),
`ConsultarRankingUseCase` (solo lectura), `CrearNivelUseCase`, `ObtenerNivelesUseCase`,
`ObtenerPerfilUseCase`.

## Decorate stack (application/decoradores/)

GoF Decorator via `DecoradorCasoDeUso` base:
`DecoradorSeguridad → DecoradorRegistro → DecoradorMetricas → caso real`.
Compuesto en `Inyeccion` para `consultarRankingDecorado`. **Cero** imports de
librerías de logging/metrics dentro de los decoradores (solo puertos).

## Sesión (domain/sesion/)

GoF State: `EstadoSesion` sealed con `EstadoJugando`, `EstadoPausado`,
`EstadoVictoria`, `EstadoDerrota`. `ContextoSesion` interface rompe el ciclo
circular con `SesionJuego`.

## Patrones de diseño verificados en código

- **Factory Method**: `FabricaCeldasEstandar` crea celdas desde JSON
- **State**: `EstadoSesion` + `SesionJuego`
- **Command**: `PlayerMoveCommand` + `CommandHistory` (undo)
- **Observer**: `PublicadorEventosJuego` + `ObservadorJuego` (desacopla reglas de audio/UI)
- **Strategy**: `ILevelGenerationStrategy` (random/file), `EstrategiaPuntuacion` (movimientos/mixta)
- **Singleton**: `AudioServiceImp.instance`
- **Decorator**: `DecoradorCasoDeUso` para metrics/logging/security (NO decoradores de celdas)
- **Template Method**: `GeneradorNivelBase` con `validarSolvencia`

## Convenciones de código

- Dart null safety obligatorio; preferir `final` y `const`
- Tests: `should_[resultado]_when_[condicion]`, patrón AAA
- Tests usan **inline fakes** (clases `_FooFake`) o `mocktail` para spies (5 archivos en `test/application/`)
- **No usar `dynamic`** en ningún lado
- **Nunca importar** `flutter/material.dart` en `domain/` o `application/`
- **Nunca usar** `BuildContext` fuera de `presentation/views/`
- **Nunca** hacer que una View llame un caso de uso directamente

## Architecture tests (test/architecture/)

3 tests que fallan si se violan reglas:
- `dependency_direction_test` — domain/application sin Flutter, decoradores sin logging libs
- `ubiquitous_language_test` — prohíbe identificadores del avoid-list (`CeldaSalida`, `*Decorator` celdas, `Composite`, `NivelFacil/Medio/Dificil`, `PuntuacionPorTiempo`, `CargadorNiveles` plural)
- `ranking_is_read_only_test` — `IConsultaRanking` no tiene método `publicar`

Ejecutar con `flutter test`.

## Nombres reales vs. documentación obsoleta

El código usa español para todo el dominio (`MoverFlechaUseCase`, `FabricaCeldasEstandar`,
`GrafoTablero`, `SesionJuego`, etc.). Los commits siguen Conventional Commits en inglés.
**NO existen** en el código: `ICell`, `ArrowCell`/`WallCell`/`ExitCell`/`EmptyCell`/`Board`/`Player`/`Level`,
`MovePlayerUseCase`, `RotateArrowUseCase`, `LoadLevelUseCase`, `SaveProgressUseCase`,
`ILevelRepository`, `LockedCellDecorator`, `CollectableCellDecorator`,
`GameStateMachine`, `AudioManager`, `CellFactory`.

## Assets

- `assets/levels/level_XX.json` — niveles precargados
- `assets/sounds/*.wav` — efectos de sonido (move, invalid, collect, victory, defeat)

## API / Backend

- Base URL configurable vía `--dart-define=API_BASE_URL=...` (default localhost:3000)
- Token JWT persiste en `shared_preferences`, adjuntado automáticamente a requests
  protegidos via `ClienteHttpAutenticado` (subclase de `http.BaseClient`)
- Niveles locales usan `int` como id; la API usa `String` (UUID). Conversión en `main.dart`
- Endpoints: `/auth/register`, `/auth/login`, `/auth/me`, `/progress/sync`,
  `/leaderboard?nivelId=...&limite=...`
