#include <ApplicationServices/ApplicationServices.h>
#include <ImageIO/ImageIO.h>
#include <dlfcn.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define BUILD_ID "coreui-windowframe-shared-art-selection-trace-compat-v1"
#define BUILD_MARKER "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_BUILD_ID:" BUILD_ID "\n"

#define MODE_ENV "ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_MODE"
#define MODE_PASSTHROUGH "snow-passthrough-v1"
#define MODE_LION "lion-bitmapinfo-0x2002-v1"

#define COREUI_TOKEN "/CoreUI.framework/"
#define COREUI_ARTFILE_RETURN_OFFSET 0x000299e0U
#define COREUI_SHARED_RAW_RETURN_OFFSET 0x0002ad34U
#define COREUI_SHARED_IMAGEIO_RETURN_OFFSET 0x0002afe8U
#define COREUI_SHARED_RAW_SAVED_R30_OFFSET 0x00000068U
#define COREUI_SHARED_IMAGEIO_SAVED_R30_OFFSET 0x00000060U
#define MAX_TRACE_CALLS 256U

#define FRAME_ID_1 0x00004e8eU
#define FRAME_ID_2 0x00004e90U
#define FRAME_ID_3 0x00004e89U
#define FRAME_ID_4 0x00004e8aU
#define FRAME_ID_5 0x00004e8dU
#define FRAME_ID_6 0x00004e8fU
#define FRAME_ID_7 0x00004e91U

#define READ_CALLER_SAVED_U32(stack_offset, out_value, out_ok) do { \
    uintptr_t _trace_sp = 0; \
    uintptr_t _trace_caller_sp = 0; \
    __asm__ volatile("mr %0,1" : "=r"(_trace_sp)); \
    if (_trace_sp != 0) \
        _trace_caller_sp = *(const volatile uintptr_t *)(uintptr_t)_trace_sp; \
    if (_trace_caller_sp != 0) { \
        (out_value) = *(const volatile uint32_t *)(uintptr_t)(_trace_caller_sp + (stack_offset)); \
        (out_ok) = 1; \
    } else { \
        (out_value) = 0; \
        (out_ok) = 0; \
    } \
} while (0)

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
typedef CGImageRef (*cgimagesourcecreate_fn)(CGImageSourceRef, size_t,
                                            CFDictionaryRef);

struct interpose_tuple {
    const void *replacement;
    const void *replacee;
};

static struct interpose_tuple sCGImageCreateInterpose;
static struct interpose_tuple sCGImageSourceCreateImageAtIndexInterpose;
static cgimagecreate_fn gOriginal = NULL;
static cgimagesourcecreate_fn gImageSourceOriginal = NULL;
static unsigned int gCompatCallIndex = 0;
static unsigned int gTraceCallIndex = 0;
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
trace_mode(const char **mode_out)
{
    const char *mode = getenv(MODE_ENV);

    if (mode_out != NULL)
        *mode_out = mode != NULL ? mode : "UNSET";

    if (mode == NULL)
        return 0;
    return strcmp(mode, MODE_PASSTHROUGH) == 0 ||
           strcmp(mode, MODE_LION) == 0;
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
    if (caller_addr < base_addr)
        return 0;

    if (offset_out != NULL)
        *offset_out = (uint32_t)(caller_addr - base_addr);
    return 1;
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
log_compat_call(unsigned int index, const char *mode, int exact,
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

static unsigned int
log_trace_call(const char *mode,
               size_t width, size_t height,
               size_t bits_per_component, size_t bits_per_pixel,
               size_t bytes_per_row, CGBitmapInfo bitmap_info,
               CGDataProviderRef provider, const CGFloat *decode,
               bool should_interpolate, CGColorRenderingIntent intent,
               uint32_t caller_offset, int compat_target)
{
    char line[768];
    size_t pos = 0;
    unsigned int index;

    if (gTraceCallIndex >= MAX_TRACE_CALLS) {
        if (gTraceCallIndex == MAX_TRACE_CALLS) {
            ++gTraceCallIndex;
            write_literal("PM_COREUI_WINDOWFRAME_IMAGE_TRACE_LIMIT:unique_limit=256\n");
        }
        return 0;
    }

    index = ++gTraceCallIndex;
    log_build_once();

    append_text(line, sizeof(line), &pos, "PM_COREUI_WINDOWFRAME_IMAGE_TRACE_CALL:index=");
    append_uint(line, sizeof(line), &pos, index);
    append_text(line, sizeof(line), &pos, " mode=");
    append_text(line, sizeof(line), &pos, mode);
    append_text(line, sizeof(line), &pos, " caller_offset=");
    append_hex32(line, sizeof(line), &pos, caller_offset);
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
    append_text(line, sizeof(line), &pos, " provider=");
    append_text(line, sizeof(line), &pos, provider != NULL ? "NONNULL" : "NULL");
    append_text(line, sizeof(line), &pos, " decode=");
    append_text(line, sizeof(line), &pos, decode != NULL ? "NONNULL" : "NULL");
    append_text(line, sizeof(line), &pos, " interpolate=");
    append_text(line, sizeof(line), &pos, should_interpolate ? "YES" : "NO");
    append_text(line, sizeof(line), &pos, " intent=");
    append_uint(line, sizeof(line), &pos, (unsigned long)intent);
    append_text(line, sizeof(line), &pos, " compat_target=");
    append_text(line, sizeof(line), &pos, compat_target ? "YES" : "NO");
    append_text(line, sizeof(line), &pos, "\n");

    if (pos < sizeof(line)) {
        line[pos] = '\0';
        write_literal(line);
    }
    return index;
}

static void
log_trace_result(unsigned int index, CGImageRef result,
                 CGBitmapInfo effective_bitmap_info)
{
    char line[256];
    size_t pos = 0;

    if (index == 0)
        return;

    append_text(line, sizeof(line), &pos, "PM_COREUI_WINDOWFRAME_IMAGE_TRACE_RESULT:index=");
    append_uint(line, sizeof(line), &pos, index);
    append_text(line, sizeof(line), &pos, " result=");
    append_text(line, sizeof(line), &pos, result != NULL ? "NONNULL" : "NULL");
    append_text(line, sizeof(line), &pos, " effectiveBitmapInfo=");
    append_hex32(line, sizeof(line), &pos, (uint32_t)effective_bitmap_info);
    append_text(line, sizeof(line), &pos, "\n");

    if (pos < sizeof(line)) {
        line[pos] = '\0';
        write_literal(line);
    }
}


static int
is_frame_image_id(uint32_t image_id)
{
    return image_id == FRAME_ID_1 ||
           image_id == FRAME_ID_2 ||
           image_id == FRAME_ID_3 ||
           image_id == FRAME_ID_4 ||
           image_id == FRAME_ID_5 ||
           image_id == FRAME_ID_6 ||
           image_id == FRAME_ID_7;
}

static void
log_shared_raw(const char *phase, uint32_t image_id, int stack_ok,
               size_t width, size_t height, size_t bytes_per_row,
               CGImageRef result)
{
    char line[512];
    size_t pos = 0;

    append_text(line, sizeof(line), &pos,
                "PM_COREUI_SHARED_ART_SELECTION_RAW:phase=");
    append_text(line, sizeof(line), &pos, phase);
    append_text(line, sizeof(line), &pos, " frame_id=");
    append_hex32(line, sizeof(line), &pos, image_id);
    append_text(line, sizeof(line), &pos, " stack_ok=");
    append_text(line, sizeof(line), &pos, stack_ok ? "YES" : "NO");
    append_text(line, sizeof(line), &pos, " frame_target=");
    append_text(line, sizeof(line), &pos,
                stack_ok && is_frame_image_id(image_id) ? "YES" : "NO");
    append_text(line, sizeof(line), &pos, " width=");
    append_uint(line, sizeof(line), &pos, width);
    append_text(line, sizeof(line), &pos, " height=");
    append_uint(line, sizeof(line), &pos, height);
    append_text(line, sizeof(line), &pos, " bpr=");
    append_uint(line, sizeof(line), &pos, bytes_per_row);
    if (strcmp(phase, "RESULT") == 0) {
        append_text(line, sizeof(line), &pos, " result=");
        append_text(line, sizeof(line), &pos,
                    result != NULL ? "NONNULL" : "NULL");
    }
    append_text(line, sizeof(line), &pos, "\n");
    if (pos < sizeof(line)) {
        line[pos] = '\0';
        write_literal(line);
    }
}

static void
log_shared_imageio(const char *phase, uint32_t image_id, int stack_ok,
                   size_t image_index, CGImageRef result)
{
    char line[384];
    size_t pos = 0;

    append_text(line, sizeof(line), &pos,
                "PM_COREUI_SHARED_ART_SELECTION_IMAGEIO:phase=");
    append_text(line, sizeof(line), &pos, phase);
    append_text(line, sizeof(line), &pos, " frame_id=");
    append_hex32(line, sizeof(line), &pos, image_id);
    append_text(line, sizeof(line), &pos, " stack_ok=");
    append_text(line, sizeof(line), &pos, stack_ok ? "YES" : "NO");
    append_text(line, sizeof(line), &pos, " frame_target=");
    append_text(line, sizeof(line), &pos,
                stack_ok && is_frame_image_id(image_id) ? "YES" : "NO");
    append_text(line, sizeof(line), &pos, " image_index=");
    append_uint(line, sizeof(line), &pos, image_index);
    if (strcmp(phase, "RESULT") == 0) {
        append_text(line, sizeof(line), &pos, " result=");
        append_text(line, sizeof(line), &pos,
                    result != NULL ? "NONNULL" : "NULL");
    }
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
    const char *mode = NULL;
    const void *caller = __builtin_return_address(0);
    uint32_t caller_offset = 0;
    unsigned int compat_index = 0;
    unsigned int trace_index = 0;
    int coreui = 0;
    int artfile_caller = 0;
    int exact = 0;
    int shared_raw = 0;
    int shared_stack_ok = 0;
    uint32_t shared_image_id = 0;
    CGBitmapInfo effective_bitmap_info = bitmap_info;
    CGImageRef result;

    if (fn == NULL || fn == (cgimagecreate_fn)&rosetta_CGImageCreate)
        return NULL;

    if (!trace_mode(&mode))
        return fn(width, height, bits_per_component, bits_per_pixel,
                  bytes_per_row, space, bitmap_info, provider, decode,
                  should_interpolate, intent);

    coreui = caller_info(caller, &caller_offset);
    artfile_caller = coreui && caller_offset == COREUI_ARTFILE_RETURN_OFFSET;
    shared_raw = coreui && caller_offset == COREUI_SHARED_RAW_RETURN_OFFSET;

    if (shared_raw) {
        READ_CALLER_SAVED_U32(COREUI_SHARED_RAW_SAVED_R30_OFFSET,
                              shared_image_id, shared_stack_ok);
        log_shared_raw("CALL", shared_image_id, shared_stack_ok,
                       width, height, bytes_per_row, NULL);
    }

    if (artfile_caller) {
        compat_index = ++gCompatCallIndex;
        exact = strcmp(mode, MODE_PASSTHROUGH) == 0
            ? snow_exact(width, height, bits_per_component, bits_per_pixel,
                         bytes_per_row, bitmap_info)
            : lion_exact(width, height, bits_per_component, bits_per_pixel,
                         bytes_per_row, bitmap_info);

        log_compat_call(compat_index, mode, exact,
                        width, height, bits_per_component, bits_per_pixel,
                        bytes_per_row, bitmap_info, caller_offset);

        if (!exact) {
            write_literal("PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH\n");
        } else if (strcmp(mode, MODE_PASSTHROUGH) == 0) {
            write_literal("PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PASSTHROUGH\n");
        } else {
            effective_bitmap_info = (CGBitmapInfo)LION_BITMAP_INFO;
            write_literal("PM_COREUI_IMAGE_BITMAPINFO_COMPAT_ADAPTED:from=0x00000002 to=0x00002002\n");
        }
    }

    if (coreui) {
        trace_index = log_trace_call(mode,
                                     width, height,
                                     bits_per_component, bits_per_pixel,
                                     bytes_per_row, bitmap_info,
                                     provider, decode,
                                     should_interpolate, intent,
                                     caller_offset,
                                     artfile_caller && exact);
    }

    result = fn(width, height, bits_per_component, bits_per_pixel,
                bytes_per_row, space, effective_bitmap_info,
                provider, decode, should_interpolate, intent);

    if (artfile_caller && exact && strcmp(mode, MODE_LION) == 0) {
        if (result != NULL)
            write_literal("PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_PASS\n");
        else
            write_literal("PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_NULL\n");
    }

    if (coreui)
        log_trace_result(trace_index, result, effective_bitmap_info);

    if (shared_raw)
        log_shared_raw("RESULT", shared_image_id, shared_stack_ok,
                       width, height, bytes_per_row, result);

    return result;
}

static cgimagesourcecreate_fn
image_source_original_function(void)
{
    if (gImageSourceOriginal == NULL)
        gImageSourceOriginal =
            (cgimagesourcecreate_fn)(uintptr_t)
            sCGImageSourceCreateImageAtIndexInterpose.replacee;
    return gImageSourceOriginal;
}

static CGImageRef
rosetta_CGImageSourceCreateImageAtIndex(CGImageSourceRef source,
                                        size_t index,
                                        CFDictionaryRef options)
{
    cgimagesourcecreate_fn fn = image_source_original_function();
    const void *caller = __builtin_return_address(0);
    uint32_t caller_offset = 0;
    uint32_t image_id = 0;
    int stack_ok = 0;
    int coreui = 0;
    CGImageRef result;

    if (fn == NULL ||
        fn == (cgimagesourcecreate_fn)&rosetta_CGImageSourceCreateImageAtIndex)
        return NULL;

    coreui = caller_info(caller, &caller_offset);
    if (!coreui || caller_offset != COREUI_SHARED_IMAGEIO_RETURN_OFFSET)
        return fn(source, index, options);

    READ_CALLER_SAVED_U32(COREUI_SHARED_IMAGEIO_SAVED_R30_OFFSET,
                          image_id, stack_ok);
    log_shared_imageio("CALL", image_id, stack_ok, index, NULL);
    result = fn(source, index, options);
    log_shared_imageio("RESULT", image_id, stack_ok, index, result);
    return result;
}

__attribute__((used))
static struct interpose_tuple sCGImageCreateInterpose
__attribute__((section("__DATA,__interpose"))) = {
    (const void *)(uintptr_t)&rosetta_CGImageCreate,
    (const void *)(uintptr_t)&CGImageCreate
};

__attribute__((used))
static struct interpose_tuple sCGImageSourceCreateImageAtIndexInterpose
__attribute__((section("__DATA,__interpose"))) = {
    (const void *)(uintptr_t)&rosetta_CGImageSourceCreateImageAtIndex,
    (const void *)(uintptr_t)&CGImageSourceCreateImageAtIndex
};
