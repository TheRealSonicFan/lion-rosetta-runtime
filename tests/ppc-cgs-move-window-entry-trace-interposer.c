#include <ApplicationServices/ApplicationServices.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define BUILD_ID "cgs-move-window-entry-passive-v1"
#define BUILD_MARKER "PM_CGS_MOVE_WINDOW_ENTRY_TRACE_BUILD_ID:" BUILD_ID
#define MODE_ENV "ROSETTA_CGS_MOVE_WINDOW_ENTRY_TRACE_MODE"
#define MODE_SNOW "snow-passive-v1"
#define MODE_LION "lion-passive-v1"

typedef int32_t (*cgs_move_window_fn)(int32_t, uint32_t, const CGPoint *);

struct interpose_tuple {
    const void *replacement;
    const void *replacee;
};

extern int32_t CGSMoveWindow(int32_t connection,
                             uint32_t window,
                             const CGPoint *point);

static cgs_move_window_fn gOriginal;
static volatile unsigned int gIndex;
static int gBuildLogged;

static int32_t rosetta_CGSMoveWindow(int32_t connection,
                                     uint32_t window,
                                     const CGPoint *point);

__attribute__((used))
static struct interpose_tuple sMoveWindowInterpose
__attribute__((section("__DATA,__interpose"))) = {
    (const void *)(uintptr_t)&rosetta_CGSMoveWindow,
    (const void *)(uintptr_t)&CGSMoveWindow
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

static uint32_t float_bits(CGFloat value)
{
    float f = (float)value;
    uint32_t bits = 0;
    memcpy(&bits, &f, sizeof(bits));
    return bits;
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

static cgs_move_window_fn original_fn(void)
{
    if (!gOriginal)
        gOriginal = (cgs_move_window_fn)(uintptr_t)sMoveWindowInterpose.replacee;
    return gOriginal;
}

static void caller_info(const void *caller,
                        int *is_hitoolbox,
                        uint32_t *offset)
{
    Dl_info info;
    *is_hitoolbox = 0;
    *offset = 0;
    memset(&info, 0, sizeof(info));
    if (!caller || dladdr(caller, &info) == 0)
        return;
    if (info.dli_fname && strstr(info.dli_fname, "/HIToolbox"))
        *is_hitoolbox = 1;
    if (info.dli_fbase)
        *offset = (uint32_t)((uintptr_t)caller - (uintptr_t)info.dli_fbase);
}

static void log_entry(unsigned int index,
                      const char *mode,
                      int32_t connection,
                      uint32_t window,
                      const CGPoint *point,
                      const void *caller)
{
    char b[640];
    size_t p = 0;
    uint32_t xbits = 0;
    uint32_t ybits = 0;
    int hitoolbox = 0;
    uint32_t caller_offset = 0;

    if (point) {
        xbits = float_bits(point->x);
        ybits = float_bits(point->y);
    }
    caller_info(caller, &hitoolbox, &caller_offset);

    log_build_once();
    append_text(b, sizeof(b), &p, "PM_CGS_MOVE_WINDOW_ENTRY:index=");
    append_uint(b, sizeof(b), &p, index);
    append_text(b, sizeof(b), &p, " mode=");
    append_text(b, sizeof(b), &p, mode);
    append_text(b, sizeof(b), &p, " connection=");
    append_int(b, sizeof(b), &p, connection);
    append_text(b, sizeof(b), &p, " window=");
    append_uint(b, sizeof(b), &p, window);
    append_text(b, sizeof(b), &p, " point=");
    append_text(b, sizeof(b), &p, point ? "NONNULL" : "NULL");
    append_text(b, sizeof(b), &p, " x_bits=");
    append_hex32(b, sizeof(b), &p, xbits);
    append_text(b, sizeof(b), &p, " y_bits=");
    append_hex32(b, sizeof(b), &p, ybits);
    append_text(b, sizeof(b), &p, " x_hi16=");
    append_hex32(b, sizeof(b), &p, (xbits >> 16) & 0xffffU);
    append_text(b, sizeof(b), &p, " x_lo16=");
    append_hex32(b, sizeof(b), &p, xbits & 0xffffU);
    append_text(b, sizeof(b), &p, " y_hi16=");
    append_hex32(b, sizeof(b), &p, (ybits >> 16) & 0xffffU);
    append_text(b, sizeof(b), &p, " y_lo16=");
    append_hex32(b, sizeof(b), &p, ybits & 0xffffU);
    append_text(b, sizeof(b), &p, " caller_hitoolbox=");
    append_text(b, sizeof(b), &p, hitoolbox ? "YES" : "NO");
    append_text(b, sizeof(b), &p, " caller_offset=");
    append_hex32(b, sizeof(b), &p, caller_offset);
    append_text(b, sizeof(b), &p, "\n");
    if (p < sizeof(b)) {
        b[p] = '\0';
        write_literal(b);
    }
}

static void log_result(unsigned int index, int32_t result)
{
    char b[192];
    size_t p = 0;
    append_text(b, sizeof(b), &p, "PM_CGS_MOVE_WINDOW_RESULT:index=");
    append_uint(b, sizeof(b), &p, index);
    append_text(b, sizeof(b), &p, " result=");
    append_int(b, sizeof(b), &p, result);
    append_text(b, sizeof(b), &p, "\n");
    if (p < sizeof(b)) {
        b[p] = '\0';
        write_literal(b);
    }
}

__attribute__((constructor))
static void move_window_trace_init(void)
{
    if (mode_value())
        log_build_once();
}

static int32_t rosetta_CGSMoveWindow(int32_t connection,
                                     uint32_t window,
                                     const CGPoint *point)
{
    cgs_move_window_fn fn = original_fn();
    const char *mode = mode_value();
    const void *caller = __builtin_return_address(0);
    unsigned int index;
    int32_t result;

    if (!fn || fn == (cgs_move_window_fn)&rosetta_CGSMoveWindow)
        return -50;

    if (!mode)
        return fn(connection, window, point);

    index = ++gIndex;
    log_entry(index, mode, connection, window, point, caller);
    result = fn(connection, window, point);
    log_result(index, result);
    return result;
}
