# Changelog

## 1.1 — 2026-11-16

Playable on phones and tablets, in Godot and in the browser.

### Added

- **Phones and tablets**: the [Escoria Mobile](https://github.com/joaquin-becerra/escoria-mobile-addon) 1.0.0 addon is included (`addons/escoria-mobile`). It switches on with the first touch; with a mouse on desktop, nothing changes.
  - **Gestures**: tap an item to see its name, tap it again to act. A tap on the floor walks, a double tap runs, and a long press is a right click.
  - **Phone layout**: the room fills the screen and the verb panel becomes a drawer. Tap an object and then a verb, or open the drawer with its tab. The dialog options slide up over the room.
  - **Two buttons**: one opens the settings, the other highlights the room's items for a few seconds.
  - **Web**: the first touch turns on fullscreen and landscape. A "turn your phone" hint shows while the phone is held upright.
  - **GEJE**: the web version gets the same gestures, layout and buttons.

### Fixed

- **Room transitions** fit the real view. The fade-out is fully drawn before the next room loads: on the web, dots of the previous room used to stay on screen for about two seconds.
- **HD office**:
  - Zob and Zif no longer show over the filing cabinet or the wall next to it from the back of the office. Some of the cabinet's HD occluders were empty and one strip of wall had none.
  - Feet no longer get cut over the visible floor at the front edge. The black border in front of the actors now follows the HD floor.
- **Office walkable area**: its bottom edge now matches the floor that is drawn, so nobody can stand beyond it.

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
