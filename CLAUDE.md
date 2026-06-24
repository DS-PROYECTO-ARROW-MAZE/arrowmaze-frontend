# CLAUDE.md — ArrowMaze Frontend
# Lee este archivo completo antes de escribir cualquier línea de código.

## Proyecto
Clon del juego Arrow Maze - Escape Puzzle (SayGames Ltd.).
Juego de cuadrícula: el jugador sigue una cadena de flechas hasta llegar a la celda de salida.
Proyecto universitario NRC 25783 — Desarrollo de Software.
Dev A (este repo): dominio + motor del juego + entidades.

## Arquitectura: MVVM + Clean Architecture (ESTRICTO)

Las capas son:

domain/         → Capa 1. Dart puro. CERO imports de Flutter. CERO imports de infrastructure/.
application/    → Capa 2. Casos de uso. Solo depende de interfaces definidas en domain/.
presentation/   → Capa 3. Aquí vive MVVM: Views + ViewModels. Depende de application/.
infrastructure/ → Capa 4. Flutter, SQLite, HTTP. Implementa las interfaces de domain/.
core/           → Utilidades compartidas. Sin lógica de negocio.

REGLA ABSOLUTA: domain/ y application/ nunca importan Flutter.
REGLA ABSOLUTA: Las Views nunca llaman casos de uso directamente — todo pasa por el ViewModel.
REGLA ABSOLUTA: Los ViewModels nunca importan infrastructure/ directamente.

## MVVM explicado para este proyecto

View     = Widget Flutter en presentation/views/. Solo dibuja. No tiene lógica.
ViewModel = Clase en presentation/viewmodels/. Llama casos de uso, expone estado a la View.
Model    = Entidades en domain/entities/. Dart puro.

Ejemplo de flujo correcto:
GameView (widget) → observa GameViewModel → GameViewModel llama MovePlayerUseCase
→ MovePlayerUseCase usa ILevelRepository → InfrastructureRepository implementa ILevelRepository

## Principios SOLID — aplicar siempre

SRP: cada clase tiene una sola razón de cambio.
     MAL: GameViewModel que también guarda en base de datos.
     BIEN: GameViewModel solo maneja estado de UI. SaveProgressUseCase guarda datos.

OCP: abierto a extensión, cerrado a modificación.
     MAL: if (type == 'arrow') / else if (type == 'wall') en código cliente.
     BIEN: CellFactory.create(json) devuelve el ICell correcto sin que el cliente sepa el tipo.

LSP: cualquier ICell debe poder usarse donde se espera ICell sin romper nada.
     ArrowCell, WallCell, EmptyCell, ExitCell son intercambiables donde se use ICell.

ISP: interfaces pequeñas y específicas.
     MAL: una interfaz ICell gigante con métodos que no todas las celdas usan.
     BIEN: IRenderable, ICollidable, IInteractable separadas.

DIP: depender de abstracciones, no de implementaciones.
     MAL: MovePlayerUseCase crea un SQLiteLevelRepository() internamente.
     BIEN: MovePlayerUseCase recibe un ILevelRepository por constructor.

## Patrones de diseño en uso

Factory Method : CellFactory.create(Map json) → retorna el ICell correcto según 'type'
State          : GameStateMachine con estados MenuState, PlayingState, PausedState, VictoryState, GameOverState
Command        : PlayerMoveCommand encapsula cada movimiento para soporte de undo/redo
Observer       : ViewModel usa ChangeNotifier o Riverpod para notificar a las Views
Builder        : LevelBuilder construye un Board desde un archivo JSON
Strategy       : ILevelGenerationStrategy (FileBasedLevelStrategy, RandomLevelStrategy)
Singleton      : AudioManager, una sola instancia durante toda la ejecución
Decorator      : LockedCellDecorator, CollectableCellDecorator sobre celdas base

## Entidades del dominio (lib/domain/entities/)

ICell         → interfaz base: position(row, col), cellType
ArrowCell     → implementa ICell, tiene Direction (UP/DOWN/LEFT/RIGHT), método rotate()
WallCell      → implementa ICell, bloquea movimiento
EmptyCell     → implementa ICell, no tiene flecha, es pasable
ExitCell      → implementa ICell, condición de victoria
Board         → cuadrícula rows x cols, contiene List<List<ICell>>
Player        → posición actual (row, col) en el Board
Level         → Board + playerStart + exitPosition + metadata (id, name, difficulty)

## Casos de uso (lib/application/use_cases/)

MovePlayerUseCase    → sigue la cadena de flechas desde la posición del jugador
RotateArrowUseCase   → rota una ArrowCell en la posición (row, col) dada
LoadLevelUseCase     → carga un Level desde ILevelRepository
SaveProgressUseCase  → persiste nivel completado y puntuación
GetLeaderboardUseCase → obtiene top scores desde la API remota

## Puertos / interfaces (lib/application/ports/ y lib/domain/)

Estos son los puertos que EXISTEN en el código (DIP: los casos de uso dependen
de ellos, nunca de implementaciones concretas):

CargadorNivel        → cargar(idNivel)                         (carga la definición de un nivel)
Tablero              → celdaEn(pos), raycast(...), trayectoriaEn(pos), eliminarTrayectoria(id)  (puerto OCP; lo realiza GrafoTablero)
IConsultaRanking     → obtenerTop(idNivel, limite)            (leaderboard de solo lectura)
IRepositorioProgreso → guardarLote(runs)                      (subida batch — SOLO escritura)
IColaSincronizacion  → encolar / obtenerPendientes / vaciar  (cola de subida offline, en memoria)
ProveedorSesion      → obtenerToken / guardarToken / cerrarSesion
FuenteAutenticacion  → registrar(...), iniciarSesion(...)

NO existe ninguna lectura de "niveles completados" ni lógica de bloqueo todavía.
Eso lo introduce el Ticket 13 - Meta-Game Loop & Progression, que añadirá los
puertos `ConsultaProgresoLocal` (niveles completados/estrellas, persistido con
`shared_preferences`) y `CatalogoNiveles` (listado ordenado de niveles).
Ver DIAGRAM-RECONCILIATION.md §10.

## Formato JSON de niveles (assets/levels/level_XX.json)

{
  "id": 1,
  "name": "Level 1",
  "difficulty": "easy",
  "rows": 5,
  "cols": 5,
  "player_start": {"row": 0, "col": 0},
  "exit": {"row": 4, "col": 4},
  "cells": [
    {"row": 0, "col": 0, "type": "arrow", "direction": "RIGHT"},
    {"row": 0, "col": 1, "type": "arrow", "direction": "DOWN"},
    {"row": 1, "col": 1, "type": "wall"},
    {"row": 4, "col": 4, "type": "exit"}
  ]
}

## Reglas de código

- Dart null safety obligatorio en todo el proyecto. No usar late sin justificación.
- Preferir final y const siempre que sea posible.
- dartdoc en TODAS las clases y métodos públicos.
- Tests nombrados: should_[resultado_esperado]_when_[condicion]
- Patrón AAA en todos los tests: Arrange / Act / Assert
- Usar mocktail para mocks, nunca mockito.
- No usar dynamic en ningún lado.

## Convención de commits (Conventional Commits — obligatorio)

feat(domain): add ArrowCell entity
fix(player): correct movement when hitting wall
test(use-case): add unit tests for MovePlayerUseCase
docs(readme): update architecture diagram
chore(config): add commitlint setup
refactor(board): apply Factory Method to cell creation

## Lo que SIEMPRE debes hacer

- Agregar dartdoc a toda clase y método público que generes
- Generar tests unitarios junto a cada caso de uso o entidad
- Verificar que las nuevas clases de celda implementen ICell
- Separar el algoritmo (caso de uso) del dato (entidad)

NO actualices AI_USAGE.md automáticamente. La documentación de uso de IA la
hace la persona usuaria de forma manual con el skill `ai-usage-doc`, cuando
ella decide que el issue está completado. No crees ni modifiques AI_USAGE.md a
menos que se te pida explícitamente.

## Lo que NUNCA debes hacer

- Importar flutter/material.dart dentro de domain/ o application/
- Usar BuildContext fuera de infrastructure/ui/ o presentation/views/
- Crear clases que mezclen UI + lógica + persistencia
- Escribir tests que prueben detalles de implementación en vez de comportamiento
- Hacer que una View llame directamente a un caso de uso sin pasar por el ViewModel