/* Web build: Emscripten fibers (Asyncify unwinds and rewinds the C stack).
 * Snapshots of a fiber stack are not possible here, so save states that need
 * one report failure; everything else keeps the native contract. */
#include <emscripten/fiber.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    emscripten_fiber_t ctx;
    int is_thread;
    fiber_entry_fn entry;
    void *arg;
    char *cstack; size_t cstack_size;
    char *astack; size_t astack_size;
} web_fiber;

#define WEB_ASYNCIFY_STACK ((size_t)4u << 20)
static web_fiber *s_thread, *s_current;

static void web_trampoline(void *p)
{
    web_fiber *f = (web_fiber *)p;
    f->entry(f->arg);
    fprintf(stderr, "[fiber] entry returned\n");
    abort();
}

static int web_init(web_fiber *f)
{
    emscripten_fiber_init(&f->ctx, web_trampoline, f, f->cstack, f->cstack_size, f->astack, f->astack_size);
    return 0;
}

fiber_t fiber_convert_thread(void)
{
    if (s_thread) return s_thread;
    web_fiber *f = (web_fiber *)calloc(1, sizeof *f);
    if (!f) return NULL;
    f->is_thread = 1;
    f->astack_size = WEB_ASYNCIFY_STACK;
    f->astack = (char *)malloc(f->astack_size);
    if (!f->astack) { free(f); return NULL; }
    emscripten_fiber_init_from_current_context(&f->ctx, f->astack, f->astack_size);
    s_thread = s_current = f;
    return f;
}

fiber_t fiber_create(size_t commit, size_t reserve, fiber_entry_fn entry, void *arg)
{
    if (!entry) return NULL;
    web_fiber *f = (web_fiber *)calloc(1, sizeof *f);
    if (!f) return NULL;
    f->entry = entry; f->arg = arg;
    f->cstack_size = reserve > commit ? reserve : commit;
    if (f->cstack_size < ((size_t)256u << 10)) f->cstack_size = (size_t)256u << 10;
    f->astack_size = WEB_ASYNCIFY_STACK;
    f->cstack = (char *)malloc(f->cstack_size);
    f->astack = (char *)malloc(f->astack_size);
    if (!f->cstack || !f->astack) { free(f->cstack); free(f->astack); free(f); return NULL; }
    web_init(f);
    return f;
}

void fiber_switch(fiber_t target)
{
    web_fiber *to = (web_fiber *)target, *from = s_current;
    if (!to || to == from) return;
    if (!from) { fprintf(stderr, "[fiber] switch before fiber_convert_thread\n"); abort(); }
    s_current = to;
    emscripten_fiber_swap(&from->ctx, &to->ctx);
}

fiber_t fiber_current(void) { return s_current; }

void fiber_destroy(fiber_t fiber)
{
    web_fiber *f = (web_fiber *)fiber;
    if (!f || f == s_current || f->is_thread) return;
    free(f->cstack); free(f->astack); free(f);
}

void fiber_revert_thread(void)
{
    if (!s_thread || s_current != s_thread) return;
    free(s_thread->astack); free(s_thread);
    s_thread = s_current = NULL;
}

int fiber_reset(fiber_t fiber, fiber_entry_fn entry, void *arg)
{
    web_fiber *f = (web_fiber *)fiber;
    if (!f || f->is_thread || f == s_current || !entry) return -1;
    f->entry = entry; f->arg = arg;
    return web_init(f);
}

size_t fiber_snapshot_bound(fiber_t fiber) { (void)fiber; return 0; }
size_t fiber_snapshot_save(fiber_t fiber, void *dst, size_t cap) { (void)fiber; (void)dst; (void)cap; return 0; }
int fiber_snapshot_load(fiber_t fiber, const void *src, size_t len) { (void)fiber; (void)src; (void)len; return -1; }
int fiber_stack_range(fiber_t fiber, uintptr_t *lo, uintptr_t *top)
{
    web_fiber *f = (web_fiber *)fiber;
    if (!f || f->is_thread) return -1;
    if (lo) *lo = (uintptr_t)f->cstack;
    if (top) *top = (uintptr_t)(f->cstack + f->cstack_size);
    return 0;
}
