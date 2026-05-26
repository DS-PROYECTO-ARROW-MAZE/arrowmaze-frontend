# AGENTS.md — ArrowMaze Frontend
# Este archivo es leído automáticamente por OpenCode y agentes de IA compatibles.
# Si usas Gemini, pega este contenido completo al inicio de cada conversación.

## Proyecto
Clon del juego Arrow Maze - Escape Puzzle (SayGames Ltd.).
Juego de cuadrícula: el jugador sigue una cadena de flechas hasta llegar a la celda de salida.
Proyecto universitario NRC 25783 — Desarrollo de Software.

## Arquitectura: MVVM + Clean Architecture (ESTRICTO)

lib/domain/         → Capa 1. Dart puro. CERO imports de Flutter.
lib/application/    → Capa 2. Casos de uso. Solo depende de interfaces de domain/.
lib/presentation/   → Capa 3. MVVM: Views + ViewModels.
lib/infrastructure/ → Capa 4. Flutter, SQLite, HTTP.
lib/core/           → Utilidades compartidas.

REGLA ABSOLUTA: domain/ y application/ nunca importan Flutter.
REGLA ABSOLUTA: Las Views nunca llaman casos de uso directamente, todo pasa por el ViewModel.
REGLA ABSOLUTA: Los ViewModels nunca importan infrastructure/ directamente.

## MVVM en este proyecto

View      → Widget Flutter en presentation/views/. Solo dibuja, cero lógica.
ViewModel → Clase en presentation/viewmodels/. Llama casos de uso, expone estado.
Model     → Entidades en domain/entities/. Dart puro.

Flujo correcto:
GameView → observa GameViewModel → llama MovePlayerUseCase → usa ILevelRepository
→ InfrastructureRepository implementa ILevelRepository

## Principios SOLID

SRP: una clase, una razón de cambio.
OCP: nuevas funciones via nuevas clases que implementan interfaces, nunca modificar las existentes.
LSP: ArrowCell, WallCell, EmptyCell, ExitCell son intercambiables donde se use ICell.
ISP: interfaces pequeñas (IRenderable, ICollidable separadas).
DIP: casos de uso reciben ILevelRepository por constructor, nunca instancian la clase concreta.

## Patrones de diseño en uso

Factory Method → CellFactory.create(json) retorna el ICell correcto
State          → GameStateMachine (MenuState, PlayingState, PausedState, VictoryState, GameOverState)
Command        → PlayerMoveCommand para undo/redo
Observer       → ViewModel con ChangeNotifier notifica a las Views
Builder        → LevelBuilder construye Board desde JSON
Strategy       → ILevelGenerationStrategy (FileBasedLevelStrategy, RandomLevelStrategy)
Singleton      → AudioManager, una sola instancia
Decorator      → LockedCellDecorator, CollectableCellDecorator

## Entidades del dominio (lib/domain/entities/)

ICell       → interfaz base: position(row, col), cellType
ArrowCell   → implementa ICell, Direction (UP/DOWN/LEFT/RIGHT), rotate()
WallCell    → implementa ICell, bloquea movimiento
EmptyCell   → implementa ICell, pasable sin flecha
ExitCell    → implementa ICell, condición de victoria
Board       → cuadrícula rows x cols, List<List<ICell>>
Player      → posición actual (row, col)
Level       → Board + playerStart + exitPosition + metadata

## Casos de uso (lib/application/use_cases/)

MovePlayerUseCase     → sigue cadena de flechas desde posición del jugador
RotateArrowUseCase    → rota ArrowCell en posición (row, col)
LoadLevelUseCase      → carga Level desde ILevelRepository
SaveProgressUseCase   → persiste nivel completado y puntuación
GetLeaderboardUseCase → obtiene top scores desde API remota

## Interfaces del dominio (lib/domain/repositories/)

ILevelRepository    → getLevelById(int id), getAllLevels()
IProgressRepository → getCompletedLevels(), saveScore(int levelId, int score)

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

- Dart null safety obligatorio. No usar late sin justificación.
- Preferir final y const siempre que sea posible.
- dartdoc en todas las clases y métodos públicos.
- Tests nombrados: should_[resultado_esperado]_when_[condicion]
- Patrón AAA en todos los tests: Arrange / Act / Assert
- Usar mocktail para mocks, nunca mockito.
- No usar dynamic en ningún lado.

## Convención de commits (Conventional Commits)

feat(domain): add ArrowCell entity
fix(player): correct movement when hitting wall
test(use-case): add unit tests for MovePlayerUseCase
docs(readme): update architecture diagram
chore(config): add commitlint setup
refactor(board): apply Factory Method to cell creation

## Nunca hacer

- Importar flutter/material.dart dentro de domain/ o application/
- Usar BuildContext fuera de presentation/views/
- Mezclar UI + lógica + persistencia en una misma clase
- Hacer que una View llame directamente a un caso de uso
- Escribir tests que prueben detalles de implementación