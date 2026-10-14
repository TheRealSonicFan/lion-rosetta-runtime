#include <ApplicationServices/ApplicationServices.h>
#include <dlfcn.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define BUILD_ID "coreui-image-bitmapinfo-compat-v1"
#define BUILD_MARKER "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_BUILD_ID:" BUILD_ID "\n"

#define MODE_ENV "ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_MODE"
#define MODE_PASSTHROUGH "snow-passthrough-v1"
#define MODE_LION "lion-bitmapinfo-0x2002-v1"

#define COREUI_TOKEN "/CoreUI.framework/"
#define COREUI_RETURN_OFFSET 0x000299e0U

#define SNOW_WIDTH 14U
#define SNOW_HEIGHT 16U
#define SNOW_BPR 56U

#define LION_WIDTH 16U
#define LION_HEIGHT 16U
#define LION_BPR 64U

#define BPC 8U
#define BPP 32U
#define SNOW_BITMAP_INFO 0x00000002U
#define LION_BITMAP_INFO 0x00002002U

typedef CGImageRef (*cgimagecreate_fn)(size_t, size_t, size_t, size_t, size_t,
                                      CGColorSpaceRef, CGBitmapInfo,
                                      CGDataProviderRef, const CGFloat *,
                                      bool, CGColorRenderingIntent);

struct interpose_tuple {
    const void *replacement;
    const void *replacee;
};

static struct interpose_tuple sCGImageCreateInterpose;
static cgimagecreate_fn gOriginal = NULL;
static unsigned int gCallIndex = 0;
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
caller_matches(const void *caller, uint32_t *offset_out)
{
    Dl_info info;
    uintptr_t caller_addr = (uintptr_t)caller;
    uintptr_t base_addr;
    uint32_t offset = 0;

    if (offset_out != NULL)
        *offset_out = 0;

    memset(&info, 0, sizeof(info));
    if (caller == NULL || dladdr(caller, &info) == 0 ||
        info.dli_fname == NULL || info.dli_fbase == NULL)
        return 0;
    if (strstr(info.dli_fname, COREUI_TOKEN) == NULL)
        return 0;

    base_addr = (uintptr_t)info.dli_fbase;
    if (caller_addr < base_addr)
        return 0;

    offset = (uint32_t)(caller_addr - base_addr);
    if (offset_out != NULL)
        *offset_out = offset;
    return offset == COREUI_RETURN_OFFSET;
}

static int
snow_exact(size_t width, size_t height,
           size_t bits_per_component, size_t bits_per_pixel,
           size_t bytes_per_row, CGBitmapInfo bitmap_info)
{
    return width == SNOW_WIDTH &&
           height == SNOW_HEIGHT &&
           bits_per_component == BPC &&
           bits_per_pixel == BPP &&
           bytes_per_row == SNOW_BPR &&
           (uint32_t)bitmap_info == SNOW_BITMAP_INFO;
}

static int
lion_exact(size_t width, size_t height,
           size_t bits_per_component, size_t bits_per_pixel,
           size_t bytes_per_row, CGBitmapInfo bitmap_info)
{
    return width == LION_WIDTH &&
           height == LION_HEIGHT &&
           bits_per_component == BPC &&
           bits_per_pixel == BPP &&
           bytes_per_row == LION_BPR &&
           (uint32_t)bitmap_info == SNOW_BITMAP_INFO;
}

static void
log_call(unsigned int index, const char *mode, int exact,
         size_t width, size_t height,
         size_t bits_per_component, size_t bits_per_pixel,
         size_t bytes_per_row, CGBitmapInfo bitmap_info,
         uint32_t caller_offset)
{
    char line[512];
    size_t pos = 0;

    log_build_once();
    append_text(line, sizeof(line), &pos, "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_CALL:index=");
    append_uint(line, sizeof(line), &pos, index);
    append_text(line, sizeof(line), &pos, " mode=");
    append_text(line, sizeof(line), &pos, mode);
    append_text(line, sizeof(line), &pos, " exact=");
    append_text(line, sizeof(line), &pos, exact ? "YES" : "NO");
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
    append_text(line, sizeof(line), &pos, " caller_offset=");
    append_hex32(line, sizeof(line), &pos, caller_offset);
    append_text(line, sizeof(line), &pos, "\n");

    if (pos < sizeof(line)) {
        line[pos] = '\0';
        write_literal(line);
    }
}

static cgimagecreate_fn
original_function(void)
{
    if (gOriginal == NULL)
        gOriginal = (cgimagecreate_fn)(uintptr_t)sCGImageCreateInterpose.replacee;
    return gOriginal;
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
    cgimagecreate_fn fn = original_function();
    const char *mode = getenv(MODE_ENV);
    const void *caller = __builtin_return_address(0);
    uint32_t caller_offset = 0;
    unsigned int index;
    int exact;
    CGImageRef result;

    if (fn == NULL || fn == (cgimagecreate_fn)&rosetta_CGImageCreate)
        return NULL;

    if (mode == NULL ||
        (strcmp(mode, MODE_PASSTHROUGH) != 0 &&
         strcmp(mode, MODE_LION) != 0) ||
        !caller_matches(caller, &caller_offset)) {
        return fn(width, height, bits_per_component, bits_per_pixel,
                  bytes_per_row, space, bitmap_info, provider, decode,
                  should_interpolate, intent);
    }

    index = ++gCallIndex;
    exact = strcmp(mode, MODE_PASSTHROUGH) == 0
        ? snow_exact(width, height, bits_per_component, bits_per_pixel,
                     bytes_per_row, bitmap_info)
        : lion_exact(width, height, bits_per_component, bits_per_pixel,
                     bytes_per_row, bitmap_info);

    log_call(index, mode, exact,
             width, height, bits_per_component, bits_per_pixel,
             bytes_per_row, bitmap_info, caller_offset);

    if (!exact) {
        write_literal("PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH\n");
        return fn(width, height, bits_per_component, bits_per_pixel,
                  bytes_per_row, space, bitmap_info, provider, decode,
                  should_interpolate, intent);
    }

    if (strcmp(mode, MODE_PASSTHROUGH) == 0) {
        write_literal("PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PASSTHROUGH\n");
        return fn(width, height, bits_per_component, bits_per_pixel,
                  bytes_per_row, space, bitmap_info, provider, decode,
                  should_interpolate, intent);
    }

    write_literal("PM_COREUI_IMAGE_BITMAPINFO_COMPAT_ADAPTED:from=0x00000002 to=0x00002002\n");
    result = fn(width, height, bits_per_component, bits_per_pixel,
                bytes_per_row, space, (CGBitmapInfo)LION_BITMAP_INFO,
                provider, decode, should_interpolate, intent);

    if (result != NULL)
        write_literal("PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_PASS\n");
    else
        write_literal("PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_NULL\n");

    return result;
}

__attribute__((used))
static struct interpose_tuple sCGImageCreateInterpose
__attribute__((section("__DATA,__interpose"))) = {
    (const void *)(uintptr_t)&rosetta_CGImageCreate,
    (const void *)(uintptr_t)&CGImageCreate
};
