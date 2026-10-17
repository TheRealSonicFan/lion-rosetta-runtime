/*
 * Proof-only dladdr interposer for the event-unflip near-stub route.
 *
 * This artifact does not patch CoreGraphics and does not implement the
 * functional display-source repair.  It proves only that dyld interposition
 * can preserve the original dladdr replacee and that the exact event-unflip
 * return-address guard can be classified without executing the patched route.
 */

#include <dlfcn.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define BUILD_ID "event-unflip-dladdr-guard-v1"
#define BUILD_MARKER "PM_EVENT_UNFLIP_DLADDR_GUARD_BUILD_ID:" BUILD_ID "\n"
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

static int
rosetta_event_unflip_dladdr(const void *address, Dl_info *info)
{
    dladdr_fn fn = original_function();
    uintptr_t caller = (uintptr_t)__builtin_return_address(0);
    uintptr_t target;
    const char *mode = getenv(MODE_ENV);

    if (fn == NULL || fn == (dladdr_fn)&rosetta_event_unflip_dladdr)
        return 0;

    target = resolve_target_return();
    if (target != 0 && caller == target) {
        ++gTargetWrapperCount;
        log_build_once();
        write_literal("PM_EVENT_UNFLIP_DLADDR_GUARD:TARGET_MATCH_FAIL_CLOSED\n");
        return FAIL_CLOSED_RESULT;
    }

    ++gNonTargetForwardCount;
    if (mode != NULL &&
        (strcmp(mode, MODE_SNOW) == 0 || strcmp(mode, MODE_LION) == 0)) {
        log_build_once();
        write_literal("PM_EVENT_UNFLIP_DLADDR_GUARD:NON_TARGET_PASSTHROUGH\n");
    }
    return fn(address, info);
}
