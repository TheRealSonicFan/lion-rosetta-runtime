#include <Carbon/Carbon.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define BUILD_ID "hitoolbox-titlebar-drag-trace-v1"
#define BUILD_MARKER "PM_HITOOLBOX_TITLEBAR_DRAG_TRACE_BUILD_ID:" BUILD_ID
#define MODE_ENV "ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_MODE"
#define MODE_SNOW "snow-passive-v1"
#define MODE_LION "lion-passive-v1"
#define HITOOLBOX_TOKEN "/HIToolbox.framework/"

struct interpose_tuple {
    const void *replacement;
    const void *replacee;
};

typedef void (*drag_window_fn)(WindowRef, Point, const Rect *);
typedef WindowPartCode (*find_window_fn)(Point, WindowRef *);

static drag_window_fn gDragOriginal;
static find_window_fn gFindOriginal;
static volatile unsigned int gDragIndex;
static volatile unsigned int gFindIndex;
static int gBuildLogged;

static void rosetta_DragWindow(WindowRef window, Point startPt, const Rect *boundsRect);
static WindowPartCode rosetta_FindWindow(Point where, WindowRef *window);

__attribute__((used))
static struct interpose_tuple sDragInterpose
__attribute__((section("__DATA,__interpose"))) = {
    (const void *)(uintptr_t)&rosetta_DragWindow,
    (const void *)(uintptr_t)&DragWindow
};

__attribute__((used))
static struct interpose_tuple sFindInterpose
__attribute__((section("__DATA,__interpose"))) = {
    (const void *)(uintptr_t)&rosetta_FindWindow,
    (const void *)(uintptr_t)&FindWindow
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

__attribute__((constructor))
static void drag_trace_init(void)
{
    if (mode_value())
        log_build_once();
}

static int caller_info(const void *caller, uint32_t *offset)
{
    Dl_info info;
    uintptr_t addr = (uintptr_t)caller;
    uintptr_t base;
    if (offset)
        *offset = 0;
    memset(&info, 0, sizeof(info));
    if (!caller || dladdr(caller, &info) == 0 || !info.dli_fname || !info.dli_fbase)
        return 0;
    if (!strstr(info.dli_fname, HITOOLBOX_TOKEN))
        return 0;
    base = (uintptr_t)info.dli_fbase;
    if (addr < base)
        return 0;
    if (offset)
        *offset = (uint32_t)(addr - base);
    return 1;
}

static drag_window_fn drag_original(void)
{
    if (!gDragOriginal)
        gDragOriginal = (drag_window_fn)(uintptr_t)sDragInterpose.replacee;
    return gDragOriginal;
}

static find_window_fn find_original(void)
{
    if (!gFindOriginal)
        gFindOriginal = (find_window_fn)(uintptr_t)sFindInterpose.replacee;
    return gFindOriginal;
}

static void append_rect(char *b, size_t c, size_t *p, const char *prefix, const Rect *r)
{
    append_text(b, c, p, prefix);
    if (!r) {
        append_text(b, c, p, "NULL");
        return;
    }
    append_text(b, c, p, "left=");
    append_int(b, c, p, r->left);
    append_text(b, c, p, ",top=");
    append_int(b, c, p, r->top);
    append_text(b, c, p, ",right=");
    append_int(b, c, p, r->right);
    append_text(b, c, p, ",bottom=");
    append_int(b, c, p, r->bottom);
}

static void log_drag_call(unsigned int index, const char *mode, uint32_t callerOffset,
                          int hitoolbox, Point startPt, OSStatus boundsStatus,
                          const Rect *before)
{
    char b[640];
    size_t p = 0;
    log_build_once();
    append_text(b, sizeof(b), &p, "PM_HITOOLBOX_TITLEBAR_DRAG_TRACE_CALL:index=");
    append_uint(b, sizeof(b), &p, index);
    append_text(b, sizeof(b), &p, " mode=");
    append_text(b, sizeof(b), &p, mode);
    append_text(b, sizeof(b), &p, " caller_offset=");
    append_hex32(b, sizeof(b), &p, callerOffset);
    append_text(b, sizeof(b), &p, " hitoolbox=");
    append_text(b, sizeof(b), &p, hitoolbox ? "YES" : "NO");
    append_text(b, sizeof(b), &p, " start_h=");
    append_int(b, sizeof(b), &p, startPt.h);
    append_text(b, sizeof(b), &p, " start_v=");
    append_int(b, sizeof(b), &p, startPt.v);
    append_text(b, sizeof(b), &p, " bounds_status=");
    append_int(b, sizeof(b), &p, boundsStatus);
    append_text(b, sizeof(b), &p, " ");
    append_rect(b, sizeof(b), &p, "before_", boundsStatus == noErr ? before : NULL);
    append_text(b, sizeof(b), &p, "\n");
    if (p < sizeof(b)) {
        b[p] = '\0';
        write_literal(b);
    }
}

static void log_drag_result(unsigned int index, uint32_t callerOffset,
                            OSStatus beforeStatus, const Rect *before,
                            OSStatus afterStatus, const Rect *after)
{
    char b[640];
    size_t p = 0;
    int moved = 0;
    if (beforeStatus == noErr && afterStatus == noErr && before && after)
        moved = memcmp(before, after, sizeof(Rect)) != 0;
    log_build_once();
    append_text(b, sizeof(b), &p, "PM_HITOOLBOX_TITLEBAR_DRAG_TRACE_RESULT:index=");
    append_uint(b, sizeof(b), &p, index);
    append_text(b, sizeof(b), &p, " caller_offset=");
    append_hex32(b, sizeof(b), &p, callerOffset);
    append_text(b, sizeof(b), &p, " moved=");
    append_text(b, sizeof(b), &p, moved ? "YES" : "NO");
    append_text(b, sizeof(b), &p, " before_status=");
    append_int(b, sizeof(b), &p, beforeStatus);
    append_text(b, sizeof(b), &p, " after_status=");
    append_int(b, sizeof(b), &p, afterStatus);
    append_text(b, sizeof(b), &p, " ");
    append_rect(b, sizeof(b), &p, "after_", afterStatus == noErr ? after : NULL);
    append_text(b, sizeof(b), &p, "\n");
    if (p < sizeof(b)) {
        b[p] = '\0';
        write_literal(b);
    }
}

static void log_find(unsigned int index, uint32_t callerOffset, int hitoolbox,
                     Point where, WindowPartCode part, WindowRef window)
{
    char b[512];
    size_t p = 0;
    log_build_once();
    append_text(b, sizeof(b), &p, "PM_HITOOLBOX_TITLEBAR_FINDWINDOW_TRACE:index=");
    append_uint(b, sizeof(b), &p, index);
    append_text(b, sizeof(b), &p, " caller_offset=");
    append_hex32(b, sizeof(b), &p, callerOffset);
    append_text(b, sizeof(b), &p, " hitoolbox=");
    append_text(b, sizeof(b), &p, hitoolbox ? "YES" : "NO");
    append_text(b, sizeof(b), &p, " point_h=");
    append_int(b, sizeof(b), &p, where.h);
    append_text(b, sizeof(b), &p, " point_v=");
    append_int(b, sizeof(b), &p, where.v);
    append_text(b, sizeof(b), &p, " part=");
    append_int(b, sizeof(b), &p, part);
    append_text(b, sizeof(b), &p, " window=");
    append_hex32(b, sizeof(b), &p, (uint32_t)(uintptr_t)window);
    append_text(b, sizeof(b), &p, "\n");
    if (p < sizeof(b)) {
        b[p] = '\0';
        write_literal(b);
    }
}

static void rosetta_DragWindow(WindowRef window, Point startPt, const Rect *boundsRect)
{
    drag_window_fn fn = drag_original();
    const char *mode = mode_value();
    const void *caller = __builtin_return_address(0);
    uint32_t callerOffset = 0;
    int hitoolbox = caller_info(caller, &callerOffset);
    Rect before;
    Rect after;
    OSStatus beforeStatus = paramErr;
    OSStatus afterStatus = paramErr;
    unsigned int index;

    if (!fn || fn == (drag_window_fn)&rosetta_DragWindow)
        return;

    if (!mode) {
        fn(window, startPt, boundsRect);
        return;
    }

    index = ++gDragIndex;
    if (window)
        beforeStatus = GetWindowBounds(window, kWindowStructureRgn, &before);
    log_drag_call(index, mode, callerOffset, hitoolbox, startPt,
                  beforeStatus, beforeStatus == noErr ? &before : NULL);

    fn(window, startPt, boundsRect);

    if (window)
        afterStatus = GetWindowBounds(window, kWindowStructureRgn, &after);
    log_drag_result(index, callerOffset, beforeStatus,
                    beforeStatus == noErr ? &before : NULL,
                    afterStatus, afterStatus == noErr ? &after : NULL);
}

static WindowPartCode rosetta_FindWindow(Point where, WindowRef *window)
{
    find_window_fn fn = find_original();
    const char *mode = mode_value();
    const void *caller = __builtin_return_address(0);
    uint32_t callerOffset = 0;
    int hitoolbox = caller_info(caller, &callerOffset);
    WindowPartCode part;
    unsigned int index;

    if (!fn || fn == (find_window_fn)&rosetta_FindWindow)
        return inDesk;

    part = fn(where, window);
    if (mode) {
        index = ++gFindIndex;
        log_find(index, callerOffset, hitoolbox, where, part,
                 window ? *window : NULL);
    }
    return part;
}
