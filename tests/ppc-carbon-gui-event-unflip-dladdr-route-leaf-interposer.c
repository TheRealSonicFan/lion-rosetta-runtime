/*
 * Route-execution-only dladdr interposer for the event-unflip near-stub path.
 *
 * The exact target-return path is intentionally a leaf fast path: after the
 * probe has pre-resolved gTargetReturn, the replacement compares LR, increments
 * one counter, and returns the fail-closed nonzero result without calling any
 * libc/dyld/logging/original-dladdr routine. Non-target dladdr traffic keeps the
 * previously proved forwarding behavior.
 */

#include <dlfcn.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define BUILD_ID "event-unflip-dladdr-route-leaf-guard-v1"
#define BUILD_MARKER "PM_EVENT_UNFLIP_DLADDR_ROUTE_GUARD_BUILD_ID:" BUILD_ID "\n"
#define NON_TARGET_MARKER "PM_EVENT_UNFLIP_DLADDR_ROUTE_GUARD:NON_TARGET_PASSTHROUGH\n"
#define MODE_ENV "ROSETTA_EVENT_UNFLIP_DLADDR_GUARD_MODE"
#define MODE_SNOW "passthrough"
#define MODE_LION "lion-guard-v1"
#define MAIN_TO_TARGET_RETURN 0x00003ff4UL
#define FAIL_CLOSED_RESULT 1

typedef int (*dladdr_fn)(const void *, Dl_info *);

struct interpose_tuple {
    const void *replacement;
    const void *replacee;
};

static int rosetta_event_unflip_dladdr(const void *, Dl_info *);

__attribute__((used))
static struct interpose_tuple sDladdrInterpose
__attribute__((section("__DATA,__interpose"))) = {
    (const void *)(uintptr_t)&rosetta_event_unflip_dladdr,
    (const void *)(uintptr_t)&dladdr
};

static dladdr_fn gOriginal = NULL;
static uintptr_t gTargetReturn = 0;
static int gResolvingTarget = 0;
static unsigned int gNonTargetForwardCount = 0;
static unsigned int gTargetWrapperCount = 0;
static unsigned int gBuildLogged = 0;

static void
write_literal(const char *s)
{
    size_t n = strlen(s);
    while (n != 0) {
        ssize_t wrote = write(STDERR_FILENO, s, n);
        if (wrote <= 0)
            return;
        s += wrote;
        n -= (size_t)wrote;
    }
}

static void
log_build_once(void)
{
    if (!gBuildLogged) {
        write_literal(BUILD_MARKER);
        gBuildLogged = 1;
    }
}

static dladdr_fn
original_function(void)
{
    if (gOriginal == NULL)
        gOriginal = (dladdr_fn)(uintptr_t)sDladdrInterpose.replacee;
    return gOriginal;
}

static uintptr_t
resolve_target_return(void)
{
    void *main_symbol;

    if (gTargetReturn != 0)
        return gTargetReturn;
    if (gResolvingTarget)
        return 0;

    gResolvingTarget = 1;
    main_symbol = dlsym(RTLD_DEFAULT, "CGSMainDisplayID");
    if (main_symbol != NULL)
        gTargetReturn = (uintptr_t)main_symbol + MAIN_TO_TARGET_RETURN;
    gResolvingTarget = 0;
    return gTargetReturn;
}

uintptr_t
rosetta_event_unflip_dladdr_guard_target_return(void)
{
    return resolve_target_return();
}

int
rosetta_event_unflip_dladdr_guard_classify(uintptr_t candidate)
{
    uintptr_t target = resolve_target_return();
    return target != 0 && candidate == target;
}

int
rosetta_event_unflip_dladdr_guard_call_original(const void *address,
                                                Dl_info *info)
{
    dladdr_fn fn = original_function();
    if (fn == NULL || fn == (dladdr_fn)&rosetta_event_unflip_dladdr)
        return 0;
    return fn(address, info);
}

void
rosetta_event_unflip_dladdr_guard_get_counts(unsigned int *non_target,
                                             unsigned int *target)
{
    if (non_target != NULL)
        *non_target = gNonTargetForwardCount;
    if (target != NULL)
        *target = gTargetWrapperCount;
}

int
rosetta_event_unflip_dladdr_guard_target_leaf_contract(void)
{
    return 1;
}

static int
rosetta_event_unflip_dladdr(const void *address, Dl_info *info)
{
    uintptr_t caller = (uintptr_t)__builtin_return_address(0);
    dladdr_fn fn;
    const char *mode;

    /*
     * Route-execution target fast path.  gTargetReturn is explicitly primed
     * and validated by the probe before the CoreGraphics callsite is modified.
     * Keep this branch free of function calls so no proof-harness activity can
     * perturb the caller's live f30/f31 event coordinates.
     */
    if (gTargetReturn != 0 && caller == gTargetReturn) {
        ++gTargetWrapperCount;
        return FAIL_CLOSED_RESULT;
    }

    fn = original_function();
    if (fn == NULL || fn == (dladdr_fn)&rosetta_event_unflip_dladdr)
        return 0;

    ++gNonTargetForwardCount;
    mode = getenv(MODE_ENV);
    if (mode != NULL &&
        (strcmp(mode, MODE_SNOW) == 0 || strcmp(mode, MODE_LION) == 0)) {
        log_build_once();
        write_literal(NON_TARGET_MARKER);
    }
    return fn(address, info);
}
