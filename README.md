# genesisrecomp-web

Builds for the browser (Emscripten) of published [Genesis Recomp](https://github.com/mstan/segagenesisrecomp)
game ports, for the Recompendium hub. Each Mega Drive title needs its own analysis configuration, so only the
games in `games.tsv` are accepted, recognised by the ROM's SHA-1; each recipe in `recipes/` pins the
game's port repository and lists the small web edits.

```sh
scripts/setup.sh                       # Emscripten SDK; needs git, python3, cmake, ninja
scripts/port.sh sonic1 "Sonic the Hedgehog (USA, Europe).md"   # -> build/web-sonic1/index.html
```

No ROM or generated code is stored here. The ports and the framework are under the PolyForm
Noncommercial license with their PERMISSIONS.md; this recipe repository adds no game data.

Web changes applied to every port (`recipes/common.sh`): the game's fiber runs on Emscripten fibers
(`web/fiber_web.inc`, full Asyncify; fiber save states are unavailable), and the in-tree generator runs
under node with host filesystem access.

## Any other ROM: generic recomp

Genesis Recomp has no generic project, so `scripts/generic.sh` builds one from the Rocket Knight
Adventures port (itself bootstrapped without a disassembly): `generic/game_spec.c` reads the entry, V-int
and H-int from the cartridge's vector table, and `game.toml` carries nothing game-specific beyond the
initial stack. Two rounds of three headless runs with random input record what the interpreter floor ran
(`floor_coverage.toml`); `tools/fold_floor.py` turns those addresses into roots for the next regen,
skipping any inside an already generated function. Needs native SDL2 development files and ninja.
A file without the `SEGA` header at $100 fails with exit code 2.
