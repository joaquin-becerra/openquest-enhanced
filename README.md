# OpenQuest Enhanced — Godot + Escoria

An enhanced remake of **OpenQuest**, Michael Sheail's short two-room point & click demo, running on [Godot](https://godotengine.org/) 4.7 and the [Escoria](https://github.com/godot-escoria) adventure framework.

## Goal

OpenQuest was first made for Adventure Game Studio (2007), then ported to SCUMM with ScummC and to Wintermute. This project starts from the ScummC version and converts it automatically to Godot + Escoria with [scumm2escoria](https://github.com/joaquin-becerra/scumm2escoria). The result was then improved by hand. It shows both:

- how far an automatic SCUMM → Godot conversion gets;
- what a classic adventure can become with today's tools.

### ▶ [Play it in the browser](https://joaquin-becerra.github.io/godot-escoria-js-engine/player/?game=openquest-escoria-enhanced)

The web version runs on [GEJE](https://github.com/joaquin-becerra/godot-escoria-js-engine) (Godot Escoria JS Engine), a JavaScript engine that plays Godot + Escoria games in a browser without Godot's WebAssembly runtime.

## What's new compared with the converted game

- **HD graphics, switchable while playing.** Choose "Graphics" in Options or press F10 to switch between the original pixel art and redrawn HD art.
  - The HD art covers the characters, rooms, items and interface.
  - The HD character frames were redrawn with AI (Gemini) from the originals and cleaned up; Zif and Zob were also vectorized.
  - Positions, collisions and scripts are the same in both modes.
- **HD fonts**: Bangers, Nunito and Patrick Hand (all OFL) replace the bitmap fonts in HD mode.
- **6 languages**: English, Spanish, French, German, Italian and Portuguese.
  - On the first run the game picks the system or browser language.
  - Accented letters were added to the original bitmap fonts.
- **Music**: the four themes of the AGS version, plus separate music and effects volumes.
- **New menus**: the main and pause menu use the game's own look (intro background, logo, verb-box buttons). Options include language, volumes, graphics and screen mode.
- **Credits at the end of the game**: Zif beams up to the ship, the ship leaves and the credits roll.
- **Animated title screen**: Zif talks on the phone and Zob sweeps his detector.
- **Phones and tablets** (new in 1.1), with the [Escoria Mobile](https://github.com/joaquin-becerra/escoria-mobile-addon) addon, in Godot and in the browser:
  - touch gestures: tap an item to see it, tap again to act; double tap to run; long press for a right click;
  - the room fills the screen and the verb panel becomes a drawer: tap an object, then a verb;
  - buttons for the settings and for highlighting the room's items;
  - on the web, fullscreen and landscape with the first touch.
- **Quality of life**:
  - a loading indicator between rooms;
  - an always-visible fullscreen button, which also works on the web;
  - the debug console only in debug builds.
- **Fixes**: Escoria's `esc_location.gd` broke in exported builds (characters walked to the middle of objects), and some draw-order and input problems at room changes were fixed.

## Running it

Open the project with **Godot 4.7** and press F5.

To play in the browser:
- **Godot**: use the "Web" export preset.
- **GEJE**: export the game with `tools/export.js` in GEJE. The `[scumm2escoria]` section of `project.godot` tells GEJE which changes the converter made to Escoria's addons, and GEJE brings their JS side.

## Project layout

| Path | Contents |
|---|---|
| `rooms/` | Title screen, skyline intro, office, secret room and the ending |
| `characters/`, `items/` | Characters and inventory items with their ESC scripts |
| `hd/` | HD versions of the graphics, mirroring the paths of the originals |
| `graphics/hd_graphics.gd` | Switches between original and HD graphics and fonts |
| `addons/escoria-mobile/` | [Escoria Mobile](https://github.com/joaquin-becerra/escoria-mobile-addon): touch, phone layout and HUD (settings under `escoria/mobile/` in `project.godot`) |
| `ui/` | SCUMM-style UI (verbs, sentence line, speech, dialog chooser, transitions), menus, options |
| `commands/` | Custom ESC commands (`scumm_*` from the converter, `show_loading`…) |
| `translations/` | `openquest.csv` (game texts) and `escoria_ui.csv` (menus) |
| `music/`, `sounds/` | Music and sound effects |

## Credits

- **OpenQuest**: game, graphics and sounds by **Michael Sheail** (2007, Adventure Game Studio).
- **Adventure Game Studio**: Chris Jones.
- **ScummC port**: Jennifer McMurray and the ScummC team.
- **Godot + Escoria version, enhancements and HD art**: Joaquín A. Becerra.
- **Escoria**: https://github.com/godot-escoria
- **Fonts**: Bangers, Nunito and Patrick Hand under the SIL Open Font License (license files in `hd/fonts/`).

## License

OpenQuest's code and assets are free to modify and distribute under the **Creative Commons Attribution 4.0 International** license. This remake keeps that license and its credits. Escoria is MIT, and the fonts are OFL. See [LICENSE](LICENSE).

## Support

If you enjoyed it, you can support this work with a [donation via PayPal](https://www.paypal.com/donate/?hosted_button_id=AGB8C4H72NQMJ).

## Notes

- The HD character art was generated with AI (Google Gemini) from the original frames and then edited by hand.
