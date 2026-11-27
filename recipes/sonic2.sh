# Sonic the Hedgehog 2: port do mstan (Genesis Recomp), versão pinada.
REPO=https://github.com/mstan/SonicTheHedgehog2Recomp
COMMIT=8fc7aa497c66da8322d47e94cd57cd1d9805ce7a
EXE=SonicTheHedgehog2Recomp
recipe_prepare() {
  cp "$ROM" game/sonic2.bin
  web_engine_edits segagenesisrecomp
  python3 "$ROOT/recipes/edit.py" CMakeLists.txt --append "$WEB_TARGET_HOOK"
  # música customizada (libgme): o navegador não carrega .so, então a lib entra estática no WASM
  # (a fonte LGPL exata continua indo junto, em docs/libgme-source, como no desktop)
  sed -i 's/set(GME_BUILD_SHARED ON/set(GME_BUILD_SHARED OFF/; s/set(GME_BUILD_STATIC OFF/set(GME_BUILD_STATIC ON/;
          s/gme_shared/gme_static/g; s/^    if(UNIX)$/    if(UNIX AND NOT EMSCRIPTEN)/' cmake/Sonic2CustomMusic.cmake
}
CMAKE_ARGS=(-DSONIC2_GAME_VERSION_OVERRIDE=web)
