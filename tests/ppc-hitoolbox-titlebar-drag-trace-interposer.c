#include <Carbon/Carbon.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define BUILD_ID "hitoolbox-titlebar-drag-trace-v2"
#define BUILD_MARKER "PM_HITOOLBOX_TITLEBAR_DRAG_TRACE_BUILD_ID:" BUILD_ID
#define MODE_ENV "ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_MODE"
#define MODE_SNOW "snow-passive-v2"
#define MODE_LION "lion-passive-v2"
#define SUBJECT_TOKEN "ppc-carbon-gui-smoketest-private-dyld"

struct interpose_tuple {
    const void *replacement;
    const void *replacee;
};

typedef OSStatus (*install_timer_fn)(EventLoopRef,
                                     EventTimerInterval,
                                     EventTimerInterval,
                                     EventLoopTimerUPP,
                                     void *,
                                     EventLoopTimerRef *);

static install_timer_fn gInstallTimerOriginal;
static EventHandlerUPP gMouseHandlerUPP;
static EventHandlerRef gMouseHandlerRef;
static volatile unsigned int gEventIndex;
static int gBuildLogged;

static OSStatus rosetta_InstallEventLoopTimer(EventLoopRef inEventLoop,
                                               EventTimerInterval inFireDelay,
                                               EventTimerInterval inInterval,
                                               EventLoopTimerUPP inTimerProc,
                                               void *inTimerData,
                                               EventLoopTimerRef *outTimer);

__attribute__((used))
static struct interpose_tuple sTimerInterpose
__attribute__((section("__DATA,__interpose"))) = {
    (const void *)(uintptr_t)&rosetta_InstallEventLoopTimer,
    (const void *)(uintptr_t)&InstallEventLoopTimer
};

static void write_literal(const char *s)
{
    size_t n;
    if (!s)
        return;
    n = strlen(s);
    while (n) {
        ssize_t w = write(STDERR_FILENO, s, n);
        if (w <= 0)
            return;
        s += (size_t)w;
        n -= (size_t)w;
    }
}

static void append_text(char *b, size_t c, size_t *p, const char *s)
{
    while (s && *s && *p + 1 < c)
        b[(*p)++] = *s++;
}

static void append_uint(char *b, size_t c, size_t *p, unsigned long v)
{
    char t[32];
    size_t n = 0, i;
    if (!v) {
        if (*p + 1 < c)
            b[(*p)++] = '0';
        return;
    }
    while (v && n < sizeof(t)) {
        t[n++] = (char)('0' + (v % 10UL));
        v /= 10UL;
    }
    for (i = 0; i < n && *p + 1 < c; i++)
        b[(*p)++] = t[n - 1 - i];
}

static void append_int(char *b, size_t c, size_t *p, long v)
{
    unsigned long mag;
    if (v < 0) {
        if (*p + 1 < c)
            b[(*p)++] = '-';
        mag = (unsigned long)(-(v + 1)) + 1UL;
    } else {
        mag = (unsigned long)v;
    }
    append_uint(b, c, p, mag);
}

static void append_hex32(char *b, size_t c, size_t *p, uint32_t v)
{
    static const char d[] = "0123456789abcdef";
    int shift;
    append_text(b, c, p, "0x");
    for (shift = 28; shift >= 0; shift -= 4) {
        if (*p + 1 >= c)
            return;
        b[(*p)++] = d[(v >> shift) & 15U];
    }
}

static const char *mode_value(void)
{
    const char *m = getenv(MODE_ENV);
    if (!m)
        return NULL;
    if (!strcmp(m, MODE_SNOW) || !strcmp(m, MODE_LION))
        return m;
    return NULL;
}

static void log_build_once(void)
{
    if (!gBuildLogged) {
        gBuildLogged = 1;
        write_literal(BUILD_MARKER "\n");
    }
}

static int caller_is_subject(const void *caller)
{
    Dl_info info;
    memset(&info, 0, sizeof(info));
    if (!caller || dladdr(caller, &info) == 0 || !info.dli_fname)
        return 0;
    return strstr(info.dli_fname, SUBJECT_TOKEN) != NULL;
}

static install_timer_fn timer_original(void)
{
    if (!gInstallTimerOriginal)
        gInstallTimerOriginal =
            (install_timer_fn)(uintptr_t)sTimerInterpose.replacee;
    return gInstallTimerOriginal;
}

static void log_install(OSStatus status)
{
    char b[192];
    size_t p = 0;
    log_build_once();
    append_text(b, sizeof(b), &p,
                "PM_HITOOLBOX_TITLEBAR_INPUT_HANDLER_INSTALL:target=dispatcher status=");
    append_int(b, sizeof(b), &p, status);
    append_text(b, sizeof(b), &p, "\n");
    if (p < sizeof(b)) {
        b[p] = '\0';
        write_literal(b);
    }
}

static void log_event(EventRef event)
{
    char b[512];
    size_t p = 0;
    Point where;
    WindowRef hitWindow = NULL;
    WindowPartCode part = inDesk;
    OSStatus locationStatus;
    UInt32 kind;
    unsigned int index;
    const char *mode = mode_value();

    if (!mode || !event)
        return;

    kind = GetEventKind(event);
    locationStatus = GetEventParameter(event,
                                       kEventParamMouseLocation,
                                       typeQDPoint,
                                       NULL,
                                       sizeof(where),
                                       NULL,
                                       &where);
    if (locationStatus == noErr)
        part = FindWindow(where, &hitWindow);

    index = ++gEventIndex;
    log_build_once();
    append_text(b, sizeof(b), &p,
                "PM_HITOOLBOX_TITLEBAR_INPUT_EVENT:index=");
    append_uint(b, sizeof(b), &p, index);
    append_text(b, sizeof(b), &p, " mode=");
    append_text(b, sizeof(b), &p, mode);
    append_text(b, sizeof(b), &p, " kind=");
    append_uint(b, sizeof(b), &p, kind);
    append_text(b, sizeof(b), &p, " location_status=");
    append_int(b, sizeof(b), &p, locationStatus);
    append_text(b, sizeof(b), &p, " h=");
    append_int(b, sizeof(b), &p,
               locationStatus == noErr ? where.h : 0);
    append_text(b, sizeof(b), &p, " v=");
    append_int(b, sizeof(b), &p,
               locationStatus == noErr ? where.v : 0);
    append_text(b, sizeof(b), &p, " find_part=");
    append_int(b, sizeof(b), &p,
               locationStatus == noErr ? part : -1);
    append_text(b, sizeof(b), &p, " find_window=");
    append_hex32(b, sizeof(b), &p,
                 (uint32_t)(uintptr_t)hitWindow);
    append_text(b, sizeof(b), &p, "\n");
    if (p < sizeof(b)) {
        b[p] = '\0';
        write_literal(b);
    }
}

static OSStatus mouse_handler(EventHandlerCallRef nextHandler,
                              EventRef event,
                              void *userData)
{
    (void)nextHandler;
    (void)userData;
    log_event(event);
    return eventNotHandledErr;
}

static void install_dispatcher_handler(void)
{
    static const EventTypeSpec types[] = {
        { kEventClassMouse, kEventMouseDown },
        { kEventClassMouse, kEventMouseDragged },
        { kEventClassMouse, kEventMouseUp }
    };
    OSStatus status;

    if (!mode_value())
        return;

    log_build_once();
    gMouseHandlerUPP = NewEventHandlerUPP(mouse_handler);
    if (!gMouseHandlerUPP) {
        log_install(memFullErr);
        return;
    }

    status = InstallEventHandler(GetEventDispatcherTarget(),
                                 gMouseHandlerUPP,
                                 (ItemCount)(sizeof(types) / sizeof(types[0])),
                                 types,
                                 NULL,
                                 &gMouseHandlerRef);
    log_install(status);
}

__attribute__((constructor))
static void drag_trace_init(void)
{
    install_dispatcher_handler();
}

static OSStatus rosetta_InstallEventLoopTimer(EventLoopRef inEventLoop,
                                               EventTimerInterval inFireDelay,
                                               EventTimerInterval inInterval,
                                               EventLoopTimerUPP inTimerProc,
                                               void *inTimerData,
                                               EventLoopTimerRef *outTimer)
{
    install_timer_fn fn = timer_original();
    const char *mode = mode_value();
    const void *caller = __builtin_return_address(0);
    EventTimerInterval effective = inFireDelay;
    int exact = 0;
    OSStatus status;
    char b[320];
    size_t p = 0;

    if (!fn || fn == (install_timer_fn)&rosetta_InstallEventLoopTimer)
        return paramErr;

    if (mode && caller_is_subject(caller) &&
        inFireDelay > 1.99 && inFireDelay < 2.01 &&
        inInterval == 0.0) {
        effective = 8.0;
        exact = 1;
    }

    status = fn(inEventLoop,
                effective,
                inInterval,
                inTimerProc,
                inTimerData,
                outTimer);

    if (mode && caller_is_subject(caller)) {
        log_build_once();
        append_text(b, sizeof(b), &p,
                    "PM_HITOOLBOX_TITLEBAR_INPUT_TIMER:mode=");
        append_text(b, sizeof(b), &p, mode);
        append_text(b, sizeof(b), &p, " from_ms=");
        append_uint(b, sizeof(b), &p,
                    (unsigned long)(inFireDelay * 1000.0 + 0.5));
        append_text(b, sizeof(b), &p, " to_ms=");
        append_uint(b, sizeof(b), &p,
                    (unsigned long)(effective * 1000.0 + 0.5));
        append_text(b, sizeof(b), &p, " exact=");
        append_text(b, sizeof(b), &p, exact ? "YES" : "NO");
        append_text(b, sizeof(b), &p, " status=");
        append_int(b, sizeof(b), &p, status);
        append_text(b, sizeof(b), &p, "\n");
        if (p < sizeof(b)) {
            b[p] = '\0';
            write_literal(b);
        }
    }

    return status;
}
