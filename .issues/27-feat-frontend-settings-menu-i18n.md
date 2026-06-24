# feat(frontend): settings menu — sound toggle + language (EN/ES i18n)

- **Phase:** 6 — enhancement (UX / settings / i18n)
- **Stories:** new — player settings; accessible after login
- **Blocked by:** 08 (identity-auth-session), 21 (audio sound effects)
- **Traceability:** PRD §8 (NFR) · CLAUDE.md Patterns (Singleton `AudioServiceImp`,
  `ConfiguracionManager`) · ADR-0002 (config is DI-lifetime, not a Singleton)

> Add a **Settings** entry point (button), available **after login**, opening a Settings screen
> with two controls: **Sound (On/Off)** and **Language (English / Spanish)**. Language requires a
> real **i18n** implementation: all user-facing strings are externalized and the UI switches
> locale live. Both settings **persist** across sessions and are read on startup.

## User Story

> *As a logged-in player, I open Settings to turn sound on/off and switch the app between English
> and Spanish; my choices stick the next time I play.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `application`/`core` | `ConfiguracionManager` (DI-lifetime, **not** a Singleton — ADR-0002) exposing `sonidoHabilitado` + `idioma`; a `PreferenciasUsuario` port persisted via `shared_preferences` |
| `presentation` (DM-F8) | `AjustesViewModel` + `AjustesViewState`; `AjustesView` with the two controls; a Settings button on a post-login screen (Level Select header) |
| `infrastructure` | `PreferenciasUsuarioPersistente` (`shared_preferences`); the sound toggle flips `AudioServiceImp`'s global mute (ticket 21/25) — game logic untouched |
| `i18n` | externalized string resources (EN + ES) via Flutter localization (`flutter_localizations` / ARB or equivalent); a `LocalizacionesProvider` exposing the active locale to Views |

## Acceptance Criteria

1. A **Settings** button is reachable only **after login**; it opens the Settings screen.
2. **Sound On/Off** toggles all SFX globally (mutes/unmutes `AudioServiceImp`) **without** any
   change to `domain`/`application` game logic; the choice persists and is applied on next launch.
3. **Language EN/ES** switches every user-facing string live; **no hard-coded UI strings remain**
   (all routed through i18n resources); the choice persists and is applied on next launch.
4. Settings are read on startup so the very first rendered frame reflects the saved locale + mute.
5. Defaults are sensible on first run (sound on; device locale if EN/ES else English).

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `presentation/ajustes_viewmodel_test.dart` (fake prefs port + fake audio):
  - `should_persist_and_apply_sound_toggle_when_changed` (AC2).
  - `should_persist_and_change_locale_when_language_selected` (AC3).
  - `should_load_saved_settings_on_init` (AC4).
- `infrastructure/preferencias_usuario_persistente_test.dart`
  (`SharedPreferences.setMockInitialValues`):
  - `should_round_trip_sound_and_language_across_instances` (AC2/AC3/AC4).
- `i18n/localizaciones_test.dart`:
  - `should_resolve_each_key_in_english_and_spanish` (AC3 — no missing keys, no literal fallbacks).

### 🟢 GREEN
- Implement `ConfiguracionManager` + `PreferenciasUsuario` port + persistent adapter; build the
  Settings VM/View + post-login button; wire EN/ES localization and locale switching; flip audio
  mute from the toggle.

### ♻️ REFACTOR
- Keep `ConfiguracionManager` DI-lifetime (ADR-0002 — **not** a Singleton); keep i18n keys in one
  place; ensure no View holds a literal user-facing string.

## Definition of Done
- Post-login Settings with working Sound (On/Off) and Language (EN/ES); both persist and apply on
  startup; live locale switch; no hard-coded UI strings.
- Sound toggle drives audio mute only — no game-logic change; defaults sensible on first run.
- `flutter analyze` clean, full suite green.

---
**Working agreement (mandatory):** strict **TDD** (🔴→🟢→♻️). **MVVM + Clean Architecture**
(CLAUDE.md): Views bind to `AjustesViewModel`; ViewModels never import `infrastructure/`;
persistence sits behind a port. `ConfiguracionManager` is **DI-lifetime, not a Singleton**
(ADR-0002 — only `AudioServiceImp` is the sanctioned Singleton). Ubiquitous language per PRD §4.
