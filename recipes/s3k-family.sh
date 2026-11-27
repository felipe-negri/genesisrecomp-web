# Sonic 3, Sonic & Knuckles e Sonic 3 & Knuckles: um repo do mstan com três executáveis.
# A receita de cada jogo define S3K_DIR (pasta e nome da ROM) e EXE antes de incluir este arquivo.
REPO=https://github.com/mstan/Sonic3AndKnucklesRecomp
COMMIT=93ccf9c4d30050523c863ab34827575a0837fd70
recipe_prepare() {
  cp "$ROM" "game/$S3K_DIR/$S3K_DIR.bin"
  web_engine_edits segagenesisrecomp
  python3 "$ROOT/recipes/edit.py" CMakeLists.txt --append "$WEB_TARGET_HOOK" \
    --replace '--compiler "$<TARGET_FILE:M68kStepRecomp>"' '--compiler "${S3K_STEP_RECOMP}"' \
    --replace 'DEPENDS M68kStepRecomp ' 'DEPENDS '
  # o gerador do descompressor (M68kStepRecomp) também roda na máquina do build: sai do mesmo build nativo
  HOST_ARGS+=("-DS3K_STEP_RECOMP=$work/host/M68kStepRecomp")
}
CMAKE_ARGS=()
# FIBER_MODE=threads também compila, mas ainda dá erro nas threads; o modo padrão (Asyncify completo, 76 MB) é o que funciona
