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
