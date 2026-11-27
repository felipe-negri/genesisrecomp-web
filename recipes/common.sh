# Edições do motor (segagenesisrecomp) que todo jogo precisa na web.
# shellcheck disable=SC2034
WEB_TARGET_HOOK='
if(EMSCRIPTEN AND WEB_LINK_FLAGS)
    # Web build (recompendium recipe): link flags for the game executable only.
    separate_arguments(_web_flags UNIX_COMMAND "${WEB_LINK_FLAGS}")
    target_link_options(${WEB_TARGET} PRIVATE ${_web_flags})
endif()
'
web_engine_edits() {
  local eng="$1"
  # o jogo roda numa fibra: no navegador, fibras do Emscripten (Asyncify) no lugar do minicoro
  # FIBER_MODE=threads (receita): cada fibra é uma thread do navegador e o Asyncify fica fora do código
  # recompilado (WASM bem menor; a página precisa de COOP/COEP). Padrão: fibras do Emscripten (Asyncify completo).
  if [ "${FIBER_MODE:-}" = threads ]; then
    cp "$ROOT/web/fiber_web_threads.inc" "$eng/runner/fiber_web.inc"
  else
    cp "$ROOT/web/fiber_web.inc" "$eng/runner/fiber_web.inc"
  fi
  python3 "$ROOT/recipes/edit.py" "$eng/runner/fiber_compat.c" \
    --replace '#include "fiber_compat.h"\n' '#include "fiber_compat.h"\n#ifdef __EMSCRIPTEN__\n#include "fiber_web.inc"\n#else\n' \
    --append '\n#endif /* __EMSCRIPTEN__ */\n'
  # o gerador (GenesisRecomp) tem que rodar na máquina do build
  if grep -q GENESIS_RECOMPILER_EXE "$eng/cmake/GenesisRecompGenerated.cmake"; then
    # motor novo: aceita um gerador nativo pronto
    cmake -S "$eng/recompiler" -B "$work/host" -DCMAKE_BUILD_TYPE=Release > "$work/host.log" 2>&1
    cmake --build "$work/host" --parallel >> "$work/host.log" 2>&1
    HOST_ARGS=("-DGENESIS_RECOMPILER_EXE=$work/host/GenesisRecomp")
    return
  fi
  # motor antigo: o gerador é compilado junto e, num build web, roda no node com acesso ao disco
  python3 "$ROOT/recipes/edit.py" "$eng/cmake/GenesisRecompGenerated.cmake" \
    --replace '        COMMAND "$<TARGET_FILE:GenesisRecomp>" ${_recompiler_args}\n' '        COMMAND GenesisRecomp ${_recompiler_args}\n' \
    --replace '                     "${CMAKE_BINARY_DIR}/genesis-recompiler")\nendif()' \
              '                     "${CMAKE_BINARY_DIR}/genesis-recompiler")\n    if(EMSCRIPTEN)\n        target_link_options(GenesisRecomp PRIVATE -sNODERAWFS=1 -sALLOW_MEMORY_GROWTH=1 -sSTACK_SIZE=16MB -sEXIT_RUNTIME=1)\n    endif()\nendif()'
}
