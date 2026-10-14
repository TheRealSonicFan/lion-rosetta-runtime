#include <ApplicationServices/ApplicationServices.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define BUILD_ID "coreui-image-constructor-passive-trace-v1"
#define BUILD_MARKER "PM_COREUI_IMAGE_TRACE_BUILD_ID:" BUILD_ID "\n"

#define MODE_ENV "ROSETTA_COREUI_IMAGE_CONSTRUCTOR_TRACE_MODE"
#define MODE_SNOW "snow-passive-image-v1"
#define MODE_LION "lion-passive-image-v1"

#define COREUI_TOKEN "/CoreUI.framework/"
#define MAX_LOGS 64U

typedef CGImageRef (*cgimagecreate_fn)(size_t, size_t, size_t, size_t, size_t,
                                      CGColorSpaceRef, CGBitmapInfo,
                                      CGDataProviderRef, const CGFloat *,
                                      bool, CGColorRenderingIntent);
typedef CMError (*cwmatchbitmap_fn)(CMWorldRef, CMBitmap *,
                                    CMBitmapCallBackUPP, void *, CMBitmap *);

struct interpose_tuple {
    const void *replacement;
    const void *replacee;
};

static struct interpose_tuple sCGImageCreateInterpose;
static struct interpose_tuple sCWMatchBitmapInterpose;

static cgimagecreate_fn gCGImageCreate = NULL;
static cwmatchbitmap_fn gCWMatchBitmap = NULL;
static unsigned int gImageSeq = 0;
static unsigned int gMatchSeq = 0;
static int gBuildLogged = 0;

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

static void
append_text(char *line, size_t cap, size_t *pos, const char *s)
{
    size_t n = strlen(s);
    if (*pos + n >= cap)
        return;
    memcpy(line + *pos, s, n);
    *pos += n;
}

static void
append_uint(char *line, size_t cap, size_t *pos, unsigned long value)
{
    char tmp[32];
    unsigned int n = 0;
    unsigned int i;

    if (value == 0) {
        if (*pos + 1 < cap)
            line[(*pos)++] = '0';
        return;
    }

    while (value != 0 && n < sizeof(tmp)) {
        tmp[n++] = (char)('0' + (value % 10UL));
        value /= 10UL;
    }

    for (i = 0; i < n; ++i) {
        if (*pos + 1 >= cap)
            return;
        line[(*pos)++] = tmp[n - 1U - i];
    }
}

static void
append_hex32(char *line, size_t cap, size_t *pos, uint32_t value)
{
    static const char digits[] = "0123456789abcdef";
    int shift;

    append_text(line, cap, pos, "0x");
    for (shift = 28; shift >= 0; shift -= 4) {
        if (*pos + 1 >= cap)
            return;
        line[(*pos)++] = digits[(value >> shift) & 0xfU];
    }
}

static int
trace_enabled(const char **mode_out)
{
    const char *mode = getenv(MODE_ENV);

    if (mode_out != NULL)
        *mode_out = mode != NULL ? mode : "UNSET";

    if (mode == NULL)
        return 0;
    return strcmp(mode, MODE_SNOW) == 0 || strcmp(mode, MODE_LION) == 0;
}

static int
target_geometry(size_t width, size_t height,
                size_t bits_per_component, size_t bits_per_pixel,
                size_t bytes_per_row)
{
    if (bits_per_component != 8 || bits_per_pixel != 32)
        return 0;

    if (width == 14 && height == 16 && bytes_per_row == 56)
        return 1;
    if (width == 16 && height == 16 && bytes_per_row == 64)
        return 1;

    return 0;
}

static int
caller_info(const void *caller, uint32_t *offset_out)
{
    Dl_info info;
    uintptr_t caller_addr = (uintptr_t)caller;
    uintptr_t base_addr;

    if (offset_out != NULL)
        *offset_out = 0;

    memset(&info, 0, sizeof(info));
    if (caller == NULL || dladdr(caller, &info) == 0 ||
        info.dli_fname == NULL || info.dli_fbase == NULL)
        return 0;

    if (strstr(info.dli_fname, COREUI_TOKEN) == NULL)
        return 0;

    base_addr = (uintptr_t)info.dli_fbase;
    if (caller_addr >= base_addr && offset_out != NULL)
        *offset_out = (uint32_t)(caller_addr - base_addr);

    return 1;
}

static void
log_image(const char *mode,
          size_t width, size_t height,
          size_t bits_per_component, size_t bits_per_pixel,
          size_t bytes_per_row, CGBitmapInfo bitmap_info,
          int coreui_caller, uint32_t caller_offset)
{
    char line[512];
    size_t pos = 0;

    if (gImageSeq >= MAX_LOGS)
        return;
    ++gImageSeq;

    log_build_once();
    append_text(line, sizeof(line), &pos, "PM_COREUI_IMAGE_TRACE_CGIMAGE:seq=");
    append_uint(line, sizeof(line), &pos, gImageSeq);
    append_text(line, sizeof(line), &pos, " mode=");
    append_text(line, sizeof(line), &pos, mode);
    append_text(line, sizeof(line), &pos, " width=");
    append_uint(line, sizeof(line), &pos, width);
    append_text(line, sizeof(line), &pos, " height=");
    append_uint(line, sizeof(line), &pos, height);
    append_text(line, sizeof(line), &pos, " bpc=");
    append_uint(line, sizeof(line), &pos, bits_per_component);
    append_text(line, sizeof(line), &pos, " bpp=");
    append_uint(line, sizeof(line), &pos, bits_per_pixel);
    append_text(line, sizeof(line), &pos, " bpr=");
    append_uint(line, sizeof(line), &pos, bytes_per_row);
    append_text(line, sizeof(line), &pos, " bitmapInfo=");
    append_hex32(line, sizeof(line), &pos, (uint32_t)bitmap_info);
    append_text(line, sizeof(line), &pos, " coreui=");
    append_text(line, sizeof(line), &pos, coreui_caller ? "YES" : "NO");
    append_text(line, sizeof(line), &pos, " caller_offset=");
    append_hex32(line, sizeof(line), &pos, caller_offset);
    append_text(line, sizeof(line), &pos, "\n");

    if (pos >= sizeof(line))
        return;
    line[pos] = '\0';
    write_literal(line);
}

static void
log_match(const char *mode, int coreui_caller, uint32_t caller_offset)
{
    char line[256];
    size_t pos = 0;

    if (gMatchSeq >= MAX_LOGS)
        return;
    ++gMatchSeq;

    log_build_once();
    append_text(line, sizeof(line), &pos, "PM_COREUI_IMAGE_TRACE_CWMATCH:seq=");
    append_uint(line, sizeof(line), &pos, gMatchSeq);
    append_text(line, sizeof(line), &pos, " mode=");
    append_text(line, sizeof(line), &pos, mode);
    append_text(line, sizeof(line), &pos, " coreui=");
    append_text(line, sizeof(line), &pos, coreui_caller ? "YES" : "NO");
    append_text(line, sizeof(line), &pos, " caller_offset=");
    append_hex32(line, sizeof(line), &pos, caller_offset);
    append_text(line, sizeof(line), &pos, "\n");

    if (pos >= sizeof(line))
        return;
    line[pos] = '\0';
    write_literal(line);
}

static cgimagecreate_fn
original_cgimagecreate(void)
{
    if (gCGImageCreate == NULL)
        gCGImageCreate = (cgimagecreate_fn)(uintptr_t)sCGImageCreateInterpose.replacee;
    return gCGImageCreate;
}

static cwmatchbitmap_fn
original_cwmatchbitmap(void)
{
    if (gCWMatchBitmap == NULL)
        gCWMatchBitmap = (cwmatchbitmap_fn)(uintptr_t)sCWMatchBitmapInterpose.replacee;
    return gCWMatchBitmap;
}

static CGImageRef
rosetta_CGImageCreate(size_t width,
                      size_t height,
                      size_t bits_per_component,
                      size_t bits_per_pixel,
                      size_t bytes_per_row,
                      CGColorSpaceRef space,
                      CGBitmapInfo bitmap_info,
                      CGDataProviderRef provider,
                      const CGFloat *decode,
                      bool should_interpolate,
                      CGColorRenderingIntent intent)
{
    cgimagecreate_fn fn = original_cgimagecreate();
    const char *mode = NULL;
    const void *caller = __builtin_return_address(0);
    uint32_t offset = 0;
    int coreui = 0;

    if (fn == NULL || fn == (cgimagecreate_fn)&rosetta_CGImageCreate)
        return NULL;

    if (trace_enabled(&mode) &&
        target_geometry(width, height, bits_per_component,
                        bits_per_pixel, bytes_per_row)) {
        coreui = caller_info(caller, &offset);
        log_image(mode, width, height, bits_per_component,
                  bits_per_pixel, bytes_per_row, bitmap_info,
                  coreui, offset);
    }

    return fn(width, height, bits_per_component, bits_per_pixel,
              bytes_per_row, space, bitmap_info, provider, decode,
              should_interpolate, intent);
}

static CMError
rosetta_CWMatchBitmap(CMWorldRef cw,
                      CMBitmap *bitmap,
                      CMBitmapCallBackUPP progress_proc,
                      void *refcon,
                      CMBitmap *matched_bitmap)
{
    cwmatchbitmap_fn fn = original_cwmatchbitmap();
    const char *mode = NULL;
    const void *caller = __builtin_return_address(0);
    uint32_t offset = 0;
    int coreui = 0;

    if (fn == NULL || fn == (cwmatchbitmap_fn)&rosetta_CWMatchBitmap)
        return (CMError)-1;

    if (trace_enabled(&mode)) {
        coreui = caller_info(caller, &offset);
        if (coreui)
            log_match(mode, coreui, offset);
    }

    return fn(cw, bitmap, progress_proc, refcon, matched_bitmap);
}

__attribute__((used))
static struct interpose_tuple sCGImageCreateInterpose
__attribute__((section("__DATA,__interpose"))) = {
    (const void *)(uintptr_t)&rosetta_CGImageCreate,
    (const void *)(uintptr_t)&CGImageCreate
};

__attribute__((used))
static struct interpose_tuple sCWMatchBitmapInterpose
__attribute__((section("__DATA,__interpose"))) = {
    (const void *)(uintptr_t)&rosetta_CWMatchBitmap,
    (const void *)(uintptr_t)&CWMatchBitmap
};
