/* Force-included in web builds that keep Asyncify off the recompiled code: the host loop's sleeps become
 * browser yields, and every presented frame yields once so a late game still lets the page update. */
#ifndef GENESIS_WEB_YIELD_H
#define GENESIS_WEB_YIELD_H
#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#include <SDL2/SDL.h>   /* declared first, so only calls are rewritten */
/* only the main (browser) thread yields; worker threads keep the plain calls */
#define SDL_Delay(ms) (emscripten_is_main_runtime_thread() ? emscripten_sleep(ms) : SDL_Delay(ms))
#define SDL_RenderPresent(r) (SDL_RenderPresent(r), emscripten_is_main_runtime_thread() ? emscripten_sleep(0) : (void)0)
#endif
#endif
