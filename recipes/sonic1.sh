# Sonic the Hedgehog (JUE REV00): port do mstan (Genesis Recomp), versão pinada.
REPO=https://github.com/mstan/SonicTheHedgehogRecomp
COMMIT=8f45c2dd45c3f2aa9742be79516620a65f4d6b9f
EXE=SonicTheHedgehogRecomp
recipe_prepare() {
  cp "$ROM" game/sonic.bin   # o CMake gera o C a partir daqui durante o build
  web_engine_edits segagenesisrecomp
  python3 "$ROOT/recipes/edit.py" CMakeLists.txt --append "$WEB_TARGET_HOOK"
}
CMAKE_ARGS=()
