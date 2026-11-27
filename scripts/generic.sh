#!/usr/bin/env bash
# Recomp genérico do Mega Drive (chamado pelo port.sh quando a ROM não tem receita). O Genesis Recomp não
# tem projeto genérico, então montamos o nosso a partir do port do Rocket Knight Adventures (que foi feito
# sem disassembly, só com a descoberta heurística + o "floor" do interpretador): spec que lê os vetores do
# cartucho, game.toml sem nada do jogo, e rodadas de perfil em que o código que o interpretador rodou
# (floor_coverage.toml) vira raiz da recompilação seguinte. Saída: build/web-<nome>/.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
name="$1"; ROM="$(realpath "$2")"
EMSDK="${EMSDK:-$ROOT/tools/emsdk}"
FRAMES="${MDWEB_PROFILE_FRAMES:-6000}"; ROUNDS="${MDWEB_PROFILE_ROUNDS:-2}"
work="$ROOT/games/$name"; out="$ROOT/build/web-$name"
# shellcheck disable=SC1091
source "$ROOT/recipes/common.sh"
# shellcheck disable=SC1091
source "$ROOT/recipes/rka.sh"      # só REPO/COMMIT: o projeto do RKA é o molde
EXE=GenesisGameRecomp
WEB_TARGET_HOOK="${WEB_TARGET_HOOK//\$\{WEB_TARGET\}/$EXE}"

echo "== [1/5] montando o projeto genérico"
if ! python3 -c "import sys;d=open(sys.argv[1],'rb').read(0x110);sys.exit(0 if b'SEGA' in d[0x100:0x110] else 1)" "$ROM"; then
  echo "erro: não parece uma ROM de Mega Drive (.md/.bin sem intercalação, 'SEGA' no cabeçalho em \$100)" >&2; exit 2
fi
src="$ROOT/games/.src/rka-$COMMIT"
if [ ! -d "$src/.git" ]; then
  rm -rf "$src"; mkdir -p "$src"
  git -C "$src" init -q; git -C "$src" remote add origin "$REPO"
  git -C "$src" fetch -q --depth 1 origin "$COMMIT"; git -C "$src" checkout -q FETCH_HEAD
  git -C "$src" submodule update -q --init --recursive
fi
rm -rf "$work"; mkdir -p "$work"
cp -a "$src" "$work/src"; cd "$work/src"
rm -f game/rka_* game/CUSTOM-VIDEO.md
cp "$ROM" game/game.bin; ROM="$work/src/game/game.bin"
cp "$ROOT/generic/game_spec.c" game/game_spec.c
ssp=$(python3 -c "import sys;print('0x%08X'%int.from_bytes(open(sys.argv[1],'rb').read()[0:4],'big'))" "$ROM")
cat > game/game.toml <<TOML
# recomp genérico (genesisrecomp-web): nada específico do jogo; descoberta heurística + rodadas de perfil
[game]
output_prefix = "game"
jump_table_autodiscovery = true
discovery_files = ["profile.discovery.toml"]

[functions]
extra = []

[ram_layout]
# a pilha inicial vem do vetor 0 do cartucho; o resto fica desconhecido (0)
game_mode      = 0x000000
vint_runcount  = 0x000000
vint_routine   = 0x000000
plc_pending    = 0x000000
initial_ssp    = $ssp
vbla_stack     = $ssp
intr_stack     = $ssp
player_object  = 0x000000
level_modes    = []
TOML
printf '[functions]\nlate_extra = []\n' > game/profile.discovery.toml
python3 - <<'PY'
p='CMakeLists.txt'; s=open(p).read()
s=s.replace('add_recomp_mode(RKARecomp rka "${CMAKE_CURRENT_SOURCE_DIR}/game" rka.bin 4390 4391)\ntarget_sources(RKARecomp PRIVATE game/rka_video.c game/rka_options.c game/rka_cheats.c)\ntarget_compile_definitions(RKARecomp PRIVATE RKA_BUILD_VERSION="${RKA_BUILD_VERSION}")',
            'add_recomp_mode(GenesisGameRecomp game "${CMAKE_CURRENT_SOURCE_DIR}/game" game.bin 4390 4391)')
s=s.replace('"${GAME}/${PREFIX}_spec.c"','"${GAME}/game_spec.c"').replace('RKARecomp','GenesisGameRecomp')
open(p,'w').write(s)
PY

echo "== [2/5] build nativo de análise"
cmake -S . -B "$work/native" -G Ninja -DCMAKE_BUILD_TYPE=Release > "$work/native.log" 2>&1
build_native() { ninja -C "$work/native" "$EXE" >> "$work/native.log" 2>&1 || { grep -m5 -E 'error|FAILED' "$work/native.log" >&2; exit 1; }; }
build_native

for r in $(seq 1 "$ROUNDS"); do
  echo "== [3/5] perfil, rodada $r de $ROUNDS: 3 partidas com entrada aleatória"
  for s in 1 2 3; do
    python3 "$ROOT/tools/random_input.py" "$FRAMES" "$((r * 10 + s))" > "$work/in-$r-$s.txt"
    # a evidência (floor_coverage.toml) é gravada ao lado do executável: uma cópia por partida
    rm -rf "$work/run-$r-$s"; mkdir -p "$work/run-$r-$s"; cp "$work/native/$EXE" "$work/run-$r-$s/"
    (cd "$work/run-$r-$s" && SDL_VIDEODRIVER=offscreen SDL_AUDIODRIVER=dummy "./$EXE" "$ROM" --no-launcher \
      --input-script "$work/in-$r-$s.txt" > run.log 2>&1 || true) &
  done
  wait
  python3 "$ROOT/tools/fold_floor.py" "$work/native/generated/game" game/profile.discovery.toml \
    "$work"/run-$r-*/floor_coverage.toml | sed 's/^/   /'
  build_native
done
rm -rf "$work/native"

echo "== [4/5] compilando WASM"
HOST_ARGS=()
web_engine_edits segagenesisrecomp
python3 "$ROOT/recipes/edit.py" CMakeLists.txt --append "$WEB_TARGET_HOOK"
# shellcheck disable=SC1091
source "$EMSDK/emsdk_env.sh" > /dev/null 2>&1
ldflags="-sASYNCIFY -sASYNCIFY_STACK_SIZE=1048576 -sALLOW_MEMORY_GROWTH -sINITIAL_MEMORY=256MB -sSTACK_SIZE=2MB \
-sEXIT_RUNTIME=0 -lidbfs.js -sFORCE_FILESYSTEM -sMAX_WEBGL_VERSION=2 --pre-js=$ROOT/web/pre.js --preload-file=$ROM@/game.bin"
emcmake cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release "-DCMAKE_C_FLAGS=-sUSE_SDL=2" \
  "-DCMAKE_CXX_FLAGS=-sUSE_SDL=2" "-DWEB_LINK_FLAGS=$ldflags" "${HOST_ARGS[@]}" > "$work/web.log" 2>&1 \
  || { grep -A5 'CMake Error' "$work/web.log" >&2; exit 1; }
ninja -C build "$EXE" >> "$work/web.log" 2>&1 || { grep -m5 -E 'error|FAILED' "$work/web.log" >&2; exit 1; }
if grep -q 'function signature mismatch' "$work/web.log"; then
  echo "erro: funções chamadas com assinatura errada (travaria no navegador)" >&2; exit 1
fi

echo "== [5/5] publicando"
rm -rf "$out"; mkdir -p "$out"
cp "build/$EXE.js" "build/$EXE.wasm" "build/$EXE.data" "$out/"
sed "s|{{{ SCRIPT }}}|<script async src=\"$EXE.js\"></script>|" "$ROOT/web/shell.html" > "$out/index.html"
cd "$ROOT"; rm -rf "$work/src"
