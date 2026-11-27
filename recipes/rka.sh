# Rocket Knight Adventures: port do mstan (Genesis Recomp), versão pinada.
REPO=https://github.com/mstan/RocketKnightAdventuresRecomp
COMMIT=46481c217209d5ce154d07b7ae9fe396244760d3
EXE=RKARecomp
recipe_prepare() {
  cp "$ROM" game/rka.bin
  web_engine_edits segagenesisrecomp
  python3 "$ROOT/recipes/edit.py" CMakeLists.txt --append "$WEB_TARGET_HOOK"
}
CMAKE_ARGS=()
