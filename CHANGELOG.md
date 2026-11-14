# Changelog

## 1.0 — 2026-11-12

First release. It starts from the OpenQuest ScummC version, converted to Godot 4.7 + Escoria by scumm2escoria (2026-10-23), and improves it by hand.

### Added

- **Translations**: Spanish, French and German (2026-10-24), then Italian. Accented letters were composed into the four original bitmap fonts, and the language is chosen automatically on the first run.
- **HD graphics** (from 2026-10-26):
  - HD versions of rooms, items, interface and characters in `hd/`;
  - the original/HD switch in Options and on F10;
  - HD fonts, and per-character speech colors in HD.
- **Character art**: the characters redrawn with Gemini from their frames and cleaned up; Zif and Zob vectorized (even-width outline, shared palette).
- **Music**: the four themes of the AGS version (office, secret room, intro and ending), with music and effects volumes.
- **Menus**: an OpenQuest main and pause menu, with options for language, volumes, graphics and screen mode.
- **Animated title screen**, **new ending** with a credits roll, **loading indicator** between rooms and a **fullscreen button**.
- **Web export** (single-threaded, works without special server headers) and support for GEJE (the `[scumm2escoria]` section of `project.godot`).

### Fixed

- **Exported builds**: Escoria's `esc_location.gd` used `EditorInterface` directly, so it didn't compile and characters walked to the middle of objects.
- **Debug console**: it only opens in debug builds.
- **Room changes**: a click during the skyline fade could leave the screen black.
- **Talk animation**: it lasted zero frames, because Escoria stopped it when the text finished typing.
- **Sentence line**: a stale second target stayed shown.
