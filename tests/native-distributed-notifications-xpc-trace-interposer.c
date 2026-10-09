#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <xpc/xpc.h>

#define BUILD_ID "distributed-notifications-native-xpc-trace-v2"
#define BUILD_MARKER \
    "PM_DISTRIBUTED_NOTIFICATIONS_NATIVE_XPC_TRACE_BUILD_ID:" BUILD_ID
#define SERVICE_PREFIX "com.apple.distributed_notifications"

typedef xpc_connection_t (*xpc_connection_create_fn)(const char *,
                                                     dispatch_queue_t);

static xpc_connection_create_fn real_xpc_connection_create;

static void
trace_line(const char *name)
{
    const char *mode;
    char line[512];
    int n;

    if (name == NULL)
        return;

    if (strncmp(name, SERVICE_PREFIX, strlen(SERVICE_PREFIX)) != 0)
        return;

    mode = getenv("PM_DISTNOTIFY_PROBE_MODE");
    if (mode == NULL || mode[0] == '\0')
        mode = "UNSET";

    n = snprintf(line,
                 sizeof(line),
                 "PM_DISTRIBUTED_NOTIFICATIONS_NATIVE_XPC_CREATE:mode=%s name=%s\n",
                 mode,
                 name);
    if (n > 0) {
        size_t count = (size_t)n;
        if (count >= sizeof(line))
            count = sizeof(line) - 1;
        (void)write(STDERR_FILENO, line, count);
    }
}

static xpc_connection_t
replacement_xpc_connection_create(const char *name, dispatch_queue_t targetq)
{
    if (real_xpc_connection_create == NULL) {
        real_xpc_connection_create =
            (xpc_connection_create_fn)dlsym(RTLD_NEXT,
                                            "xpc_connection_create");
    }

    trace_line(name);

    if (real_xpc_connection_create == NULL) {
        static const char failure[] =
            "PM_DISTRIBUTED_NOTIFICATIONS_NATIVE_XPC_TRACE_ERROR:dlsym_failed\n";
        (void)write(STDERR_FILENO, failure, sizeof(failure) - 1);
        _exit(90);
    }

    if ((void *)(unsigned long)real_xpc_connection_create ==
        (void *)(unsigned long)replacement_xpc_connection_create) {
        static const char recursive[] =
            "PM_DISTRIBUTED_NOTIFICATIONS_NATIVE_XPC_TRACE_ERROR:self_resolution\n";
        (void)write(STDERR_FILENO, recursive, sizeof(recursive) - 1);
        _exit(91);
    }

    return real_xpc_connection_create(name, targetq);
}

#define DYLD_INTERPOSE(_replacement, _replacee) \
    __attribute__((used)) static struct { \
        const void *replacement; \
        const void *replacee; \
    } _interpose_##_replacee \
    __attribute__((section("__DATA,__interpose"))) = { \
        (const void *)(unsigned long)&_replacement, \
        (const void *)(unsigned long)&_replacee \
    }

DYLD_INTERPOSE(replacement_xpc_connection_create, xpc_connection_create);

__attribute__((used))
static const char build_marker[] = BUILD_MARKER;
