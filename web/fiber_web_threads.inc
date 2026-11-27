/* Web build: each fiber is a parked pthread (Web Worker) and switching is a condition-variable handoff,
 * so only one runs at a time, as with real fibers. Unlike Emscripten fibers this needs no Asyncify over the
 * recompiled code, which keeps the WebAssembly small. The page must be cross-origin isolated
 * (COOP/COEP) for threads. Snapshots of a fiber stack are not possible, so save states that need one fail. */
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct web_fiber {
    pthread_t thread;
    pthread_cond_t cv;
    int scheduled, started, is_thread;
    fiber_entry_fn entry;
    void *arg;
    size_t stack_size;
} web_fiber;

static pthread_mutex_t s_lock = PTHREAD_MUTEX_INITIALIZER;
static web_fiber *s_thread, *s_current;

static void *web_fiber_main(void *p)
{
    web_fiber *f = (web_fiber *)p;
    pthread_mutex_lock(&s_lock);
    while (!f->scheduled) pthread_cond_wait(&f->cv, &s_lock);
    pthread_mutex_unlock(&s_lock);
    f->entry(f->arg);
    fprintf(stderr, "[fiber] entry returned\n");
    abort();
    return NULL;
}

fiber_t fiber_convert_thread(void)
{
    if (s_thread) return s_thread;
    web_fiber *f = (web_fiber *)calloc(1, sizeof *f);
    if (!f) return NULL;
    pthread_cond_init(&f->cv, NULL);
    f->is_thread = f->scheduled = 1;
    s_thread = s_current = f;
    return f;
}

fiber_t fiber_create(size_t commit, size_t reserve, fiber_entry_fn entry, void *arg)
{
    if (!entry) return NULL;
    web_fiber *f = (web_fiber *)calloc(1, sizeof *f);
    if (!f) return NULL;
    pthread_cond_init(&f->cv, NULL);
    f->entry = entry; f->arg = arg;
    f->stack_size = reserve > commit ? reserve : commit;
    if (f->stack_size < ((size_t)1u << 20)) f->stack_size = (size_t)1u << 20;
    return f;
}

void fiber_switch(fiber_t target)
{
    web_fiber *to = (web_fiber *)target, *from = s_current;
    if (!to || to == from) return;
    if (!from) { fprintf(stderr, "[fiber] switch before fiber_convert_thread\n"); abort(); }
    pthread_mutex_lock(&s_lock);
    if (!to->is_thread && !to->started) {
        pthread_attr_t a;
        pthread_attr_init(&a);
        pthread_attr_setstacksize(&a, to->stack_size);
        if (pthread_create(&to->thread, &a, web_fiber_main, to) != 0) {
            fprintf(stderr, "[fiber] cannot start a fiber thread\n"); abort();
        }
        pthread_attr_destroy(&a);
        to->started = 1;
    }
    from->scheduled = 0;
    to->scheduled = 1;
    s_current = to;
    pthread_cond_signal(&to->cv);
    while (!from->scheduled) pthread_cond_wait(&from->cv, &s_lock);
    pthread_mutex_unlock(&s_lock);
}

fiber_t fiber_current(void) { return s_current; }

void fiber_destroy(fiber_t fiber)
{
    web_fiber *f = (web_fiber *)fiber;
    /* a started fiber's thread stays parked forever; only never-run fibers are freed */
    if (!f || f == s_current || f->is_thread || f->started) return;
    pthread_cond_destroy(&f->cv); free(f);
}

void fiber_revert_thread(void) { }

int fiber_reset(fiber_t fiber, fiber_entry_fn entry, void *arg)
{
    web_fiber *f = (web_fiber *)fiber;
    if (!f || f->is_thread || f == s_current || !entry || f->started) return -1;
    f->entry = entry; f->arg = arg;
    return 0;
}

size_t fiber_snapshot_bound(fiber_t fiber) { (void)fiber; return 0; }
size_t fiber_snapshot_save(fiber_t fiber, void *dst, size_t cap) { (void)fiber; (void)dst; (void)cap; return 0; }
int fiber_snapshot_load(fiber_t fiber, const void *src, size_t len) { (void)fiber; (void)src; (void)len; return -1; }
int fiber_stack_range(fiber_t fiber, uintptr_t *lo, uintptr_t *top) { (void)fiber; (void)lo; (void)top; return -1; }
