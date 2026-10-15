#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define BUILD_ID "hitoolbox-windowframe-cuidraw-trace-v2"
#define BUILD_MARKER "PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_BUILD_ID:" BUILD_ID "\n"

#define MODE_ENV "ROSETTA_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_MODE"
#define MODE_SNOW "snow-passive-v2"
#define MODE_LION "lion-passive-v2"

#define HITOOLBOX_TOKEN "/HIToolbox.framework/"
#define TARGET_COUNT 6

typedef CFTypeRef CUIRendererRef;
typedef void (*cuidraw_fn)(CUIRendererRef, CGRect, CGContextRef, CFDictionaryRef, CFDictionaryRef *);

extern void CUIDraw(CUIRendererRef, CGRect, CGContextRef, CFDictionaryRef, CFDictionaryRef *);

struct interpose_tuple {
    const void *replacement;
    const void *replacee;
};

static struct interpose_tuple sCUIDrawInterpose;
static cuidraw_fn gOriginal = NULL;
static unsigned int gCallIndex = 0;

static const uint32_t gReturnOffsets[TARGET_COUNT] = {
    0x000217acU,
    0x000218e4U,
    0x00021968U,
    0x000219ecU,
    0x00021aa8U,
    0x00021b20U
};

static void write_literal(const char *s)
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

static void append_text(char *line, size_t cap, size_t *pos, const char *s)
{
    size_t n = strlen(s);
    if (*pos + n >= cap)
        return;
    memcpy(line + *pos, s, n);
    *pos += n;
}

static void append_uint(char *line, size_t cap, size_t *pos, unsigned long value)
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

static void append_hex32(char *line, size_t cap, size_t *pos, uint32_t value)
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

static uint32_t float_bits(CGFloat value)
{
    union {
        float f;
        uint32_t u;
    } v;
    v.f = (float)value;
    return v.u;
}

__attribute__((constructor))
static void trace_loaded(void)
{
    write_literal(BUILD_MARKER);
}

static unsigned int slot_for_offset(uint32_t offset)
{
    unsigned int i;
    for (i = 0; i < TARGET_COUNT; ++i) {
        if (offset == gReturnOffsets[i])
            return i + 1U;
    }
    return 0;
}

static void cfstring_ascii(CFStringRef s, char *out, size_t cap)
{
    if (cap == 0)
        return;
    out[0] = '\0';
    if (s == NULL)
        return;
    if (!CFStringGetCString(s, out, (CFIndex)cap, kCFStringEncodingUTF8))
        strncpy(out, "<non-utf8>", cap - 1);
    out[cap - 1] = '\0';
}

static void log_option(unsigned int call_index, CFTypeRef key, CFTypeRef value)
{
    char line[768];
    char keybuf[256];
    char valbuf[256];
    size_t pos = 0;
    CFTypeID key_type = key ? CFGetTypeID(key) : 0;
    CFTypeID value_type = value ? CFGetTypeID(value) : 0;

    keybuf[0] = '\0';
    valbuf[0] = '\0';
    if (key != NULL && key_type == CFStringGetTypeID())
        cfstring_ascii((CFStringRef)key, keybuf, sizeof(keybuf));

    append_text(line, sizeof(line), &pos, "PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_OPTION:call=");
    append_uint(line, sizeof(line), &pos, call_index);
    append_text(line, sizeof(line), &pos, " key=");
    append_text(line, sizeof(line), &pos, keybuf[0] ? keybuf : "<non-string>");
    append_text(line, sizeof(line), &pos, " type=");

    if (value == NULL) {
        append_text(line, sizeof(line), &pos, "NULL");
    } else if (value_type == CFStringGetTypeID()) {
        cfstring_ascii((CFStringRef)value, valbuf, sizeof(valbuf));
        append_text(line, sizeof(line), &pos, "string value=");
        append_text(line, sizeof(line), &pos, valbuf);
    } else if (value_type == CFBooleanGetTypeID()) {
        append_text(line, sizeof(line), &pos, "boolean value=");
        append_text(line, sizeof(line), &pos,
                    CFBooleanGetValue((CFBooleanRef)value) ? "true" : "false");
    } else if (value_type == CFNumberGetTypeID()) {
        double d = 0.0;
        union {
            double d;
            uint64_t u;
        } bits;
        if (CFNumberGetValue((CFNumberRef)value, kCFNumberDoubleType, &d)) {
            bits.d = d;
            append_text(line, sizeof(line), &pos, "number bits_hi=");
            append_hex32(line, sizeof(line), &pos, (uint32_t)(bits.u >> 32));
            append_text(line, sizeof(line), &pos, " bits_lo=");
            append_hex32(line, sizeof(line), &pos, (uint32_t)(bits.u & 0xffffffffU));
        } else {
            append_text(line, sizeof(line), &pos, "number unreadable");
        }
    } else {
        append_text(line, sizeof(line), &pos, "cf_type_id=");
        append_uint(line, sizeof(line), &pos, (unsigned long)value_type);
    }

    append_text(line, sizeof(line), &pos, "\n");
    if (pos < sizeof(line)) {
        line[pos] = '\0';
        write_literal(line);
    }
}

static void log_options(unsigned int call_index, CFDictionaryRef options)
{
    CFIndex count;
    const void **keys;
    const void **values;
    CFIndex i;

    if (options == NULL) {
        char line[160];
        size_t pos = 0;
        append_text(line, sizeof(line), &pos, "PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_OPTIONS:call=");
        append_uint(line, sizeof(line), &pos, call_index);
        append_text(line, sizeof(line), &pos, " dictionary=NULL\n");
        line[pos] = '\0';
        write_literal(line);
        return;
    }

    count = CFDictionaryGetCount(options);
    {
        char line[192];
        size_t pos = 0;
        append_text(line, sizeof(line), &pos, "PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_OPTIONS:call=");
        append_uint(line, sizeof(line), &pos, call_index);
        append_text(line, sizeof(line), &pos, " count=");
        append_uint(line, sizeof(line), &pos, (unsigned long)count);
        append_text(line, sizeof(line), &pos, "\n");
        line[pos] = '\0';
        write_literal(line);
    }

    if (count <= 0 || count > 128)
        return;

    keys = (const void **)calloc((size_t)count, sizeof(void *));
    values = (const void **)calloc((size_t)count, sizeof(void *));
    if (keys == NULL || values == NULL) {
        free(keys);
        free(values);
        write_literal("PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_OPTIONS:allocation_failed\n");
        return;
    }

    CFDictionaryGetKeysAndValues(options, keys, values);
    for (i = 0; i < count; ++i)
        log_option(call_index, (CFTypeRef)keys[i], (CFTypeRef)values[i]);

    free(keys);
    free(values);
}

static cuidraw_fn original_function(void)
{
    if (gOriginal == NULL)
        gOriginal = (cuidraw_fn)(uintptr_t)sCUIDrawInterpose.replacee;
    return gOriginal;
}

static void rosetta_CUIDraw(CUIRendererRef renderer,
                           CGRect rect,
                           CGContextRef context,
                           CFDictionaryRef options,
                           CFDictionaryRef *result)
{
    cuidraw_fn fn = original_function();
    const char *mode = getenv(MODE_ENV);
    const void *caller = __builtin_return_address(0);
    Dl_info info;
    uintptr_t caller_addr = (uintptr_t)caller;
    uintptr_t base_addr = 0;
    uint32_t caller_offset = 0;
    int dladdr_ok = 0;
    int hitoolbox = 0;
    unsigned int slot = 0;
    unsigned int index;
    char line[1024];
    size_t pos = 0;

    if (fn == NULL || fn == (cuidraw_fn)&rosetta_CUIDraw)
        return;

    if (mode == NULL ||
        (strcmp(mode, MODE_SNOW) != 0 && strcmp(mode, MODE_LION) != 0)) {
        fn(renderer, rect, context, options, result);
        return;
    }

    memset(&info, 0, sizeof(info));
    if (caller != NULL && dladdr(caller, &info) != 0) {
        dladdr_ok = 1;
        if (info.dli_fbase != NULL) {
            base_addr = (uintptr_t)info.dli_fbase;
            if (caller_addr >= base_addr)
                caller_offset = (uint32_t)(caller_addr - base_addr);
        }
        if (info.dli_fname != NULL &&
            strstr(info.dli_fname, HITOOLBOX_TOKEN) != NULL)
            hitoolbox = 1;
    }

    if (hitoolbox)
        slot = slot_for_offset(caller_offset);

    index = ++gCallIndex;

    append_text(line, sizeof(line), &pos, "PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:index=");
    append_uint(line, sizeof(line), &pos, index);
    append_text(line, sizeof(line), &pos, " mode=");
    append_text(line, sizeof(line), &pos, mode);
    append_text(line, sizeof(line), &pos, " dladdr=");
    append_text(line, sizeof(line), &pos, dladdr_ok ? "YES" : "NO");
    append_text(line, sizeof(line), &pos, " hitoolbox=");
    append_text(line, sizeof(line), &pos, hitoolbox ? "YES" : "NO");
    append_text(line, sizeof(line), &pos, " slot=");
    append_uint(line, sizeof(line), &pos, slot);
    append_text(line, sizeof(line), &pos, " caller=");
    append_hex32(line, sizeof(line), &pos, (uint32_t)caller_addr);
    append_text(line, sizeof(line), &pos, " base=");
    append_hex32(line, sizeof(line), &pos, (uint32_t)base_addr);
    append_text(line, sizeof(line), &pos, " caller_offset=");
    append_hex32(line, sizeof(line), &pos, caller_offset);
    append_text(line, sizeof(line), &pos, " image=");
    append_text(line, sizeof(line), &pos,
                (dladdr_ok && info.dli_fname != NULL) ? info.dli_fname : "<unknown>");
    append_text(line, sizeof(line), &pos, " x_bits=");
    append_hex32(line, sizeof(line), &pos, float_bits(rect.origin.x));
    append_text(line, sizeof(line), &pos, " y_bits=");
    append_hex32(line, sizeof(line), &pos, float_bits(rect.origin.y));
    append_text(line, sizeof(line), &pos, " w_bits=");
    append_hex32(line, sizeof(line), &pos, float_bits(rect.size.width));
    append_text(line, sizeof(line), &pos, " h_bits=");
    append_hex32(line, sizeof(line), &pos, float_bits(rect.size.height));
    append_text(line, sizeof(line), &pos, " options=");
    append_text(line, sizeof(line), &pos, options ? "NONNULL" : "NULL");
    append_text(line, sizeof(line), &pos, " result_ptr=");
    append_text(line, sizeof(line), &pos, result ? "NONNULL" : "NULL");
    append_text(line, sizeof(line), &pos, "\n");
    line[pos] = '\0';
    write_literal(line);

    if (hitoolbox)
        log_options(index, options);

    fn(renderer, rect, context, options, result);
    write_literal("PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_RESULT:PASSTHROUGH\n");
}

__attribute__((used))
static struct interpose_tuple sCUIDrawInterpose
__attribute__((section("__DATA,__interpose"))) = {
    (const void *)(uintptr_t)&rosetta_CUIDraw,
    (const void *)(uintptr_t)&CUIDraw
};
