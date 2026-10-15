#include <ApplicationServices/ApplicationServices.h>
#include <dlfcn.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define BUILD_ID "coreui-windowframe-shared-art-external-boundary-trace-compat-v1"
#define BUILD_MARKER "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_BUILD_ID:" BUILD_ID "\n"

#define MODE_ENV "ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_MODE"
#define MODE_PASSTHROUGH "snow-passthrough-v1"
#define MODE_LION "lion-bitmapinfo-0x2002-v1"

#define COREUI_TOKEN "/CoreUI.framework/"
#define COREUI_ARTFILE_RETURN_OFFSET 0x000299e0U
#define COREUI_SHARED_RAW_PROVIDER_RETURN_OFFSET 0x0002acf0U
#define COREUI_SHARED_RAW_IMAGE_RETURN_OFFSET 0x0002ad34U
#define COREUI_SHARED_IMAGEIO_PROVIDER_RETURN_OFFSET 0x0002ae1cU
#define COREUI_SHARED_IMAGEIO_SOURCE_RETURN_OFFSET 0x0002ae28U
#define COREUI_SHARED_IMAGEIO_IMAGE_RETURN_OFFSET 0x0002afe8U

#define COREUI_SHARED_RAW_SAVED_INCOMING_R30_OFFSET 0x00000068U
#define COREUI_SHARED_IMAGEIO_SOURCE_SAVED_INCOMING_R30_OFFSET 0x00000058U

#define FRAME_ID_1 0x00004e8eU
#define FRAME_ID_2 0x00004e90U
#define FRAME_ID_3 0x00004e8dU
#define FRAME_ID_4 0x00004e8fU
#define FRAME_ID_5 0x00004e91U

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

typedef CGDataProviderRef (*cgdataprovidercreate_fn)(
    void *, const void *, size_t, CGDataProviderReleaseDataCallback);
typedef CGImageRef (*cgimagecreate_fn)(
    size_t, size_t, size_t, size_t, size_t, CGColorSpaceRef, CGBitmapInfo,
    CGDataProviderRef, const CGFloat *, bool, CGColorRenderingIntent);
typedef CGImageSourceRef (*cgimagesourcecreateprovider_fn)(
    CGDataProviderRef, CFDictionaryRef);
typedef CGImageRef (*cgimagesourcecreateimage_fn)(
    CGImageSourceRef, size_t, CFDictionaryRef);

struct interpose_tuple {
    const void *replacement;
    const void *replacee;
};

static struct interpose_tuple sProviderInterpose;
static struct interpose_tuple sImageInterpose;
static struct interpose_tuple sSourceInterpose;
static struct interpose_tuple sSourceImageInterpose;

static cgdataprovidercreate_fn gProviderOriginal = NULL;
static cgimagecreate_fn gImageOriginal = NULL;
static cgimagesourcecreateprovider_fn gSourceOriginal = NULL;
static cgimagesourcecreateimage_fn gSourceImageOriginal = NULL;

static unsigned int gCompatCallIndex = 0;
static int gBuildLogged = 0;

#define READ_CALLER_SAVED_U32(stack_offset, out_value, out_ok) do { \
    uintptr_t _sp = (uintptr_t)__builtin_frame_address(0); \
    uintptr_t _caller_sp = 0; \
    if (_sp != 0) \
        _caller_sp = *(const volatile uintptr_t *)(uintptr_t)_sp; \
    if (_caller_sp != 0) { \
        (out_value) = *(const volatile uint32_t *)(uintptr_t)(_caller_sp + (stack_offset)); \
        (out_ok) = 1; \
    } else { \
        (out_value) = 0; \
        (out_ok) = 0; \
    } \
} while (0)

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
is_active_frame_id(uint32_t image_id)
{
    return image_id == FRAME_ID_1 ||
           image_id == FRAME_ID_2 ||
           image_id == FRAME_ID_3 ||
           image_id == FRAME_ID_4 ||
           image_id == FRAME_ID_5;
}

static int
snow_exact(size_t width, size_t height, size_t bpc, size_t bpp,
           size_t bpr, CGBitmapInfo info)
{
    return width == SNOW_WIDTH && height == SNOW_HEIGHT &&
           bpc == BPC && bpp == BPP && bpr == SNOW_BPR &&
           (uint32_t)info == SNOW_BITMAP_INFO;
}

static int
lion_exact(size_t width, size_t height, size_t bpc, size_t bpp,
           size_t bpr, CGBitmapInfo info)
{
    return width == LION_WIDTH && height == LION_HEIGHT &&
           bpc == BPC && bpp == BPP && bpr == LION_BPR &&
           (uint32_t)info == SNOW_BITMAP_INFO;
}

static void
log_compat_call(unsigned int index, const char *mode, int exact,
                size_t width, size_t height, size_t bpc, size_t bpp,
                size_t bpr, CGBitmapInfo info, uint32_t caller_offset)
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
    append_uint(line, sizeof(line), &pos, bpc);
    append_text(line, sizeof(line), &pos, " bpp=");
    append_uint(line, sizeof(line), &pos, bpp);
    append_text(line, sizeof(line), &pos, " bpr=");
    append_uint(line, sizeof(line), &pos, bpr);
    append_text(line, sizeof(line), &pos, " bitmapInfo=");
    append_hex32(line, sizeof(line), &pos, (uint32_t)info);
    append_text(line, sizeof(line), &pos, " caller_offset=");
    append_hex32(line, sizeof(line), &pos, caller_offset);
    append_text(line, sizeof(line), &pos, "\n");
    if (pos < sizeof(line)) {
        line[pos] = '\0';
        write_literal(line);
    }
}

static void
log_provider(const char *path, const char *phase, uint32_t image_id,
             int stack_ok, const void *data, size_t size,
             CGDataProviderRef provider)
{
    char line[512];
    size_t pos = 0;
    log_build_once();
    append_text(line, sizeof(line), &pos, "PM_COREUI_SHARED_ART_BOUNDARY_PROVIDER:path=");
    append_text(line, sizeof(line), &pos, path);
    append_text(line, sizeof(line), &pos, " phase=");
    append_text(line, sizeof(line), &pos, phase);
    append_text(line, sizeof(line), &pos, " image_id=");
    append_hex32(line, sizeof(line), &pos, image_id);
    append_text(line, sizeof(line), &pos, " stack_ok=");
    append_text(line, sizeof(line), &pos, stack_ok ? "YES" : "NO");
    append_text(line, sizeof(line), &pos, " frame_target=");
    append_text(line, sizeof(line), &pos,
                stack_ok && is_active_frame_id(image_id) ? "YES" : "NO");
    append_text(line, sizeof(line), &pos, " data=");
    append_hex32(line, sizeof(line), &pos, (uint32_t)(uintptr_t)data);
    append_text(line, sizeof(line), &pos, " size=");
    append_uint(line, sizeof(line), &pos, size);
    if (strcmp(phase, "RESULT") == 0) {
        append_text(line, sizeof(line), &pos, " provider=");
        append_hex32(line, sizeof(line), &pos, (uint32_t)(uintptr_t)provider);
    }
    append_text(line, sizeof(line), &pos, "\n");
    if (pos < sizeof(line)) {
        line[pos] = '\0';
        write_literal(line);
    }
}

static void
log_source(const char *phase, uint32_t image_id, int stack_ok,
           CGDataProviderRef provider, CGImageSourceRef source)
{
    char line[512];
    size_t pos = 0;
    log_build_once();
    append_text(line, sizeof(line), &pos, "PM_COREUI_SHARED_ART_BOUNDARY_SOURCE:phase=");
    append_text(line, sizeof(line), &pos, phase);
    append_text(line, sizeof(line), &pos, " image_id=");
    append_hex32(line, sizeof(line), &pos, image_id);
    append_text(line, sizeof(line), &pos, " stack_ok=");
    append_text(line, sizeof(line), &pos, stack_ok ? "YES" : "NO");
    append_text(line, sizeof(line), &pos, " frame_target=");
    append_text(line, sizeof(line), &pos,
                stack_ok && is_active_frame_id(image_id) ? "YES" : "NO");
    append_text(line, sizeof(line), &pos, " provider=");
    append_hex32(line, sizeof(line), &pos, (uint32_t)(uintptr_t)provider);
    if (strcmp(phase, "RESULT") == 0) {
        append_text(line, sizeof(line), &pos, " source=");
        append_hex32(line, sizeof(line), &pos, (uint32_t)(uintptr_t)source);
    }
    append_text(line, sizeof(line), &pos, "\n");
    if (pos < sizeof(line)) {
        line[pos] = '\0';
        write_literal(line);
    }
}

static void
log_final_image(const char *phase, CGImageSourceRef source, size_t index,
                CGImageRef result)
{
    char line[384];
    size_t pos = 0;
    log_build_once();
    append_text(line, sizeof(line), &pos, "PM_COREUI_SHARED_ART_BOUNDARY_FINAL:phase=");
    append_text(line, sizeof(line), &pos, phase);
    append_text(line, sizeof(line), &pos, " source=");
    append_hex32(line, sizeof(line), &pos, (uint32_t)(uintptr_t)source);
    append_text(line, sizeof(line), &pos, " image_index=");
    append_uint(line, sizeof(line), &pos, index);
    if (strcmp(phase, "RESULT") == 0) {
        append_text(line, sizeof(line), &pos, " result=");
        append_text(line, sizeof(line), &pos, result != NULL ? "NONNULL" : "NULL");
    }
    append_text(line, sizeof(line), &pos, "\n");
    if (pos < sizeof(line)) {
        line[pos] = '\0';
        write_literal(line);
    }
}

static void
log_raw_image(const char *phase, uint32_t image_id, int stack_ok,
              size_t width, size_t height, size_t bpr, CGImageRef result)
{
    char line[512];
    size_t pos = 0;
    log_build_once();
    append_text(line, sizeof(line), &pos, "PM_COREUI_SHARED_ART_BOUNDARY_RAW_IMAGE:phase=");
    append_text(line, sizeof(line), &pos, phase);
    append_text(line, sizeof(line), &pos, " image_id=");
    append_hex32(line, sizeof(line), &pos, image_id);
    append_text(line, sizeof(line), &pos, " stack_ok=");
    append_text(line, sizeof(line), &pos, stack_ok ? "YES" : "NO");
    append_text(line, sizeof(line), &pos, " frame_target=");
    append_text(line, sizeof(line), &pos,
                stack_ok && is_active_frame_id(image_id) ? "YES" : "NO");
    append_text(line, sizeof(line), &pos, " width=");
    append_uint(line, sizeof(line), &pos, width);
    append_text(line, sizeof(line), &pos, " height=");
    append_uint(line, sizeof(line), &pos, height);
    append_text(line, sizeof(line), &pos, " bpr=");
    append_uint(line, sizeof(line), &pos, bpr);
    if (strcmp(phase, "RESULT") == 0) {
        append_text(line, sizeof(line), &pos, " result=");
        append_text(line, sizeof(line), &pos, result != NULL ? "NONNULL" : "NULL");
    }
    append_text(line, sizeof(line), &pos, "\n");
    if (pos < sizeof(line)) {
        line[pos] = '\0';
        write_literal(line);
    }
}

static cgdataprovidercreate_fn
provider_original(void)
{
    if (gProviderOriginal == NULL)
        gProviderOriginal = (cgdataprovidercreate_fn)(uintptr_t)sProviderInterpose.replacee;
    return gProviderOriginal;
}

static CGDataProviderRef
rosetta_CGDataProviderCreateWithData(void *info, const void *data, size_t size,
                                     CGDataProviderReleaseDataCallback releaseData)
{
    cgdataprovidercreate_fn fn = provider_original();
    const void *caller = __builtin_return_address(0);
    uint32_t offset = 0;
    uint32_t image_id = 0;
    uint32_t saved_offset = 0;
    int stack_ok = 0;
    int coreui = 0;
    const char *path = NULL;
    CGDataProviderRef result;

    if (fn == NULL || fn == (cgdataprovidercreate_fn)&rosetta_CGDataProviderCreateWithData)
        return NULL;

    coreui = caller_info(caller, &offset);
    if (coreui && offset == COREUI_SHARED_RAW_PROVIDER_RETURN_OFFSET) {
        path = "RAW";
        saved_offset = COREUI_SHARED_RAW_SAVED_INCOMING_R30_OFFSET;
    } else if (coreui && offset == COREUI_SHARED_IMAGEIO_PROVIDER_RETURN_OFFSET) {
        path = "IMAGEIO";
        saved_offset = COREUI_SHARED_IMAGEIO_SOURCE_SAVED_INCOMING_R30_OFFSET;
    }

    if (path != NULL) {
        READ_CALLER_SAVED_U32(saved_offset, image_id, stack_ok);
        log_provider(path, "CALL", image_id, stack_ok, data, size, NULL);
    }

    result = fn(info, data, size, releaseData);

    if (path != NULL)
        log_provider(path, "RESULT", image_id, stack_ok, data, size, result);
    return result;
}

static cgimagecreate_fn
image_original(void)
{
    if (gImageOriginal == NULL)
        gImageOriginal = (cgimagecreate_fn)(uintptr_t)sImageInterpose.replacee;
    return gImageOriginal;
}

static CGImageRef
rosetta_CGImageCreate(size_t width, size_t height, size_t bpc, size_t bpp,
                      size_t bpr, CGColorSpaceRef space, CGBitmapInfo bitmapInfo,
                      CGDataProviderRef provider, const CGFloat *decode,
                      bool interpolate, CGColorRenderingIntent intent)
{
    cgimagecreate_fn fn = image_original();
    const char *mode = NULL;
    const void *caller = __builtin_return_address(0);
    uint32_t offset = 0;
    uint32_t image_id = 0;
    int stack_ok = 0;
    int coreui;
    int artfile;
    int raw;
    int exact = 0;
    CGBitmapInfo effective = bitmapInfo;
    CGImageRef result;

    if (fn == NULL || fn == (cgimagecreate_fn)&rosetta_CGImageCreate)
        return NULL;
    if (!trace_mode(&mode))
        return fn(width, height, bpc, bpp, bpr, space, bitmapInfo, provider,
                  decode, interpolate, intent);

    coreui = caller_info(caller, &offset);
    artfile = coreui && offset == COREUI_ARTFILE_RETURN_OFFSET;
    raw = coreui && offset == COREUI_SHARED_RAW_IMAGE_RETURN_OFFSET;

    if (raw) {
        READ_CALLER_SAVED_U32(COREUI_SHARED_RAW_SAVED_INCOMING_R30_OFFSET,
                              image_id, stack_ok);
        log_raw_image("CALL", image_id, stack_ok, width, height, bpr, NULL);
    }

    if (artfile) {
        unsigned int index = ++gCompatCallIndex;
        exact = strcmp(mode, MODE_PASSTHROUGH) == 0
            ? snow_exact(width, height, bpc, bpp, bpr, bitmapInfo)
            : lion_exact(width, height, bpc, bpp, bpr, bitmapInfo);
        log_compat_call(index, mode, exact, width, height, bpc, bpp, bpr,
                        bitmapInfo, offset);
        if (!exact) {
            write_literal("PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH\n");
        } else if (strcmp(mode, MODE_PASSTHROUGH) == 0) {
            write_literal("PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PASSTHROUGH\n");
        } else {
            effective = (CGBitmapInfo)LION_BITMAP_INFO;
            write_literal("PM_COREUI_IMAGE_BITMAPINFO_COMPAT_ADAPTED:from=0x00000002 to=0x00002002\n");
        }
    }

    result = fn(width, height, bpc, bpp, bpr, space, effective, provider,
                decode, interpolate, intent);

    if (artfile && exact && strcmp(mode, MODE_LION) == 0) {
        if (result != NULL)
            write_literal("PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_PASS\n");
        else
            write_literal("PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_NULL\n");
    }

    if (raw)
        log_raw_image("RESULT", image_id, stack_ok, width, height, bpr, result);
    return result;
}

static cgimagesourcecreateprovider_fn
source_original(void)
{
    if (gSourceOriginal == NULL)
        gSourceOriginal = (cgimagesourcecreateprovider_fn)(uintptr_t)sSourceInterpose.replacee;
    return gSourceOriginal;
}

static CGImageSourceRef
rosetta_CGImageSourceCreateWithDataProvider(CGDataProviderRef provider,
                                            CFDictionaryRef options)
{
    cgimagesourcecreateprovider_fn fn = source_original();
    const void *caller = __builtin_return_address(0);
    uint32_t offset = 0;
    uint32_t image_id = 0;
    int stack_ok = 0;
    int target = 0;
    CGImageSourceRef result;

    if (fn == NULL || fn == (cgimagesourcecreateprovider_fn)&rosetta_CGImageSourceCreateWithDataProvider)
        return NULL;

    target = caller_info(caller, &offset) &&
             offset == COREUI_SHARED_IMAGEIO_SOURCE_RETURN_OFFSET;
    if (!target)
        return fn(provider, options);

    READ_CALLER_SAVED_U32(COREUI_SHARED_IMAGEIO_SOURCE_SAVED_INCOMING_R30_OFFSET,
                          image_id, stack_ok);
    log_source("CALL", image_id, stack_ok, provider, NULL);
    result = fn(provider, options);
    log_source("RESULT", image_id, stack_ok, provider, result);
    return result;
}

static cgimagesourcecreateimage_fn
source_image_original(void)
{
    if (gSourceImageOriginal == NULL)
        gSourceImageOriginal = (cgimagesourcecreateimage_fn)(uintptr_t)sSourceImageInterpose.replacee;
    return gSourceImageOriginal;
}

static CGImageRef
rosetta_CGImageSourceCreateImageAtIndex(CGImageSourceRef source, size_t index,
                                        CFDictionaryRef options)
{
    cgimagesourcecreateimage_fn fn = source_image_original();
    const void *caller = __builtin_return_address(0);
    uint32_t offset = 0;
    int target = 0;
    CGImageRef result;

    if (fn == NULL || fn == (cgimagesourcecreateimage_fn)&rosetta_CGImageSourceCreateImageAtIndex)
        return NULL;

    target = caller_info(caller, &offset) &&
             offset == COREUI_SHARED_IMAGEIO_IMAGE_RETURN_OFFSET;
    if (!target)
        return fn(source, index, options);

    log_final_image("CALL", source, index, NULL);
    result = fn(source, index, options);
    log_final_image("RESULT", source, index, result);
    return result;
}

__attribute__((used))
static struct interpose_tuple sProviderInterpose
__attribute__((section("__DATA,__interpose"))) = {
    (const void *)(uintptr_t)&rosetta_CGDataProviderCreateWithData,
    (const void *)(uintptr_t)&CGDataProviderCreateWithData
};

__attribute__((used))
static struct interpose_tuple sImageInterpose
__attribute__((section("__DATA,__interpose"))) = {
    (const void *)(uintptr_t)&rosetta_CGImageCreate,
    (const void *)(uintptr_t)&CGImageCreate
};

__attribute__((used))
static struct interpose_tuple sSourceInterpose
__attribute__((section("__DATA,__interpose"))) = {
    (const void *)(uintptr_t)&rosetta_CGImageSourceCreateWithDataProvider,
    (const void *)(uintptr_t)&CGImageSourceCreateWithDataProvider
};

__attribute__((used))
static struct interpose_tuple sSourceImageInterpose
__attribute__((section("__DATA,__interpose"))) = {
    (const void *)(uintptr_t)&rosetta_CGImageSourceCreateImageAtIndex,
    (const void *)(uintptr_t)&CGImageSourceCreateImageAtIndex
};
