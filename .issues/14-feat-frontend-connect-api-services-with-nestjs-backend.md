# feat(frontend): Connect API services with NestJS backend

# Context
We need to connect our frontend to the newly finished NestJS backend for the ArrowMaze game. This issue tracks the creation of a robust API client/service in TypeScript to handle the communication based on the validated Postman tests.

## Base Configuration
- **Base URL:** `http://localhost:3000` (must be configurable via an environment variable).
- **Auth mechanism:** JWT Bearer tokens. We need logic to store the token securely and an interceptor to automatically attach `Authorization: Bearer <token>` to all protected routes.

## API Contract & Endpoints

### 1. Auth - Register (Public)
- **POST** `/auth/register`
- **Body:** `{ "email": "user@example.com", "password": "secure" }`
- **Returns:** `{ "message": "...", "user": { "id": "uuid", "email": "...", "createdAt": "date" } }`

### 2. Auth - Login (Public)
- **POST** `/auth/login`
- **Body:** `{ "email": "user@example.com", "password": "secure" }`
- **Returns:** `{ "token": "jwt_string" }` *(Must save this token)*

### 3. Auth - Profile (Protected 🔒)
- **GET** `/auth/me`
- **Returns:** `{ "principal": { "id": "uuid", "email": "user@example.com" } }`

### 4. Levels - Create (Protected 🔒)
- **POST** `/levels`
- **Body:** ```json
{
  "nombre": "Nivel 1 - El Despertar",
  "dificultad": "FACIL",
  "ancho": 3,
  "alto": 1,
  "baseNivel": 1000,
  "kmov": 10,
  "ktiempo": 5,
  "umbralEstrella1": 300,
  "umbralEstrella2": 600,
  "umbralEstrella3": 900,
  "celdas": [[ { "x": 0, "y": 0, "tipo": "inicio" } ]]
}
```
- **Returns:** `201 Created` with `{ "id": "uuid", "nombre": "...", ... }`

### 5. Progress - Sync Batch (Protected 🔒)
- **POST** `/progress/sync`
- **Body:** ```json
{
  "progresos": [
    {
      "nivelId": "uuid",
      "estrellas": 3,
      "movimientos": 12,
      "tiempoSegundos": 35,
      "completadoEn": "2026-06-21T20:30:00Z"
    }
  ]
}
```
- **Returns:** `201 Created` with `{ "guardados": 1 }`

### 6. Leaderboard - Get (Protected 🔒)
- **GET** `/leaderboard?nivelId=<UUID>&limite=10`
- **Returns:** `{ "entradas": [ { "puntaje": 880, "estrellas": 3, "movimientos": 12, "segundosRestantes": null, "completadoEn": "date", "email": "..." } ] }`

## Acceptance Criteria
- [ ] TypeScript interfaces/types are generated for all request and response payloads.
- [ ] A clean API service class (using fetch or axios) is set up with error handling.
- [ ] Token management and HTTP interceptors are fully implemented.
