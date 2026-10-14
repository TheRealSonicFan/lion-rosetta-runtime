#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define BUILD_ID "coreui-artfile-bsearch-exact-six-allkeys-trace-v1"
#define BUILD_MARKER "PM_COREUI_ARTFILE_BSEARCH_BUILD_ID:" BUILD_ID "\n"

#define MODE_ENV "ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_MODE"
#define MODE_SNOW_TRACE "snow-passive-allkeys-v1"
#define MODE_LION_TRACE "lion-exact-six-allkeys-v1"

#define RECORD_SIZE 12U
#define PATH_OFFSET 4U
#define PATH_LENGTH 8U

#define SNOW_RECORD_COUNT 3324U
#define SNOW_COMPONENT_COUNT 182U
#define SNOW_INDEX_START 0x0c4aU
#define SNOW_PAYLOAD_START 0x0a81cU

#define LION_RECORD_COUNT 2674U
#define LION_COMPONENT_COUNT 169U
#define LION_INDEX_START 0x0b9dU
#define LION_PAYLOAD_START 0x088f8U

#define CALLER_COMPARATOR_DELTA 0x38f0UL
#define MAX_UNIQUE_TRACE_KEYS 256U
#define MAX_TARGET_LOGS_PER_PATH 16U
#define MAX_COMPONENT_TEXT 64U

typedef int (*bsearch_comparator_fn)(const void *, const void *);
typedef void *(*bsearch_fn)(const void *, const void *, size_t, size_t,
                            bsearch_comparator_fn);

struct interpose_tuple {
    const void *replacement;
    const void *replacee;
};

static struct interpose_tuple sBsearchInterpose;
static bsearch_fn gOriginal = NULL;
static unsigned int gSeen[6] = { 0, 0, 0, 0, 0, 0 };
static unsigned char gUniqueKeys[MAX_UNIQUE_TRACE_KEYS][PATH_LENGTH];
static unsigned int gUniqueCount = 0;
static int gTraceLimitLogged = 0;
static int gBuildLogged = 0;

static const unsigned char kSnowKeys[6][PATH_LENGTH] = {
    { 0xa6, 0x13, 0x16, 0x1f, 0x7a, 0x00, 0x00, 0x00 },
    { 0xa6, 0x16, 0x1f, 0x56, 0x7a, 0x00, 0x00, 0x00 },
    { 0xa6, 0x16, 0x1f, 0x7a, 0xb6, 0x00, 0x00, 0x00 },
    { 0xa6, 0x01, 0x13, 0x16, 0x7a, 0x00, 0x00, 0x00 },
    { 0xa6, 0x01, 0x16, 0x56, 0x7a, 0x00, 0x00, 0x00 },
    { 0xa6, 0x01, 0x16, 0x7a, 0xb6, 0x00, 0x00, 0x00 }
};

static const unsigned char kLionKeys[6][PATH_LENGTH] = {
    { 0x99, 0x14, 0x17, 0x22, 0x72, 0x00, 0x00, 0x00 },
    { 0x99, 0x17, 0x22, 0x55, 0x72, 0x00, 0x00, 0x00 },
    { 0x99, 0x17, 0x22, 0x72, 0xa9, 0x00, 0x00, 0x00 },
    { 0x99, 0x01, 0x14, 0x17, 0x72, 0x00, 0x00, 0x00 },
    { 0x99, 0x01, 0x17, 0x55, 0x72, 0x00, 0x00, 0x00 },
    { 0x99, 0x01, 0x17, 0x72, 0xa9, 0x00, 0x00, 0x00 }
};

static const char *kNames[6] = {
    "disabled-clear",
    "disabled-minus",
    "disabled-zoom",
    "active-clear",
    "active-minus",
    "active-zoom"
};

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

static uint16_t
read_le16(const unsigned char *p)
{
    return (uint16_t)((uint16_t)p[0] | ((uint16_t)p[1] << 8));
}

static uint32_t
read_le32(const unsigned char *p)
{
    return (uint32_t)p[0] |
           ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) |
           ((uint32_t)p[3] << 24);
}

static int
header_matches(const void *base,
               size_t nmemb,
               unsigned int expected_records,
               unsigned int expected_components,
               unsigned int index_start,
               unsigned int payload_start)
{
    const unsigned char *index = (const unsigned char *)base;
    const unsigned char *header;

    if (index == NULL || (uintptr_t)index < (uintptr_t)index_start)
        return 0;
    if (nmemb != (size_t)expected_records)
        return 0;

    header = index - index_start;

    if (read_le16(header + 0x00) != expected_records)
        return 0;
    if (read_le16(header + 0x02) != PATH_LENGTH)
        return 0;
    if (read_le16(header + 0x04) != expected_components)
        return 0;
    if (read_le32(header + 0x10) != index_start)
        return 0;
    if (read_le32(header + 0x14) != payload_start)
        return 0;
    if (header + index_start != index)
        return 0;

    return 1;
}

static int
callsite_matches(bsearch_comparator_fn compar, const void *caller)
{
    uintptr_t c = (uintptr_t)(const void *)compar;
    uintptr_t r = (uintptr_t)caller;

    if (c == 0 || r <= c)
        return 0;
    return (r - c) == CALLER_COMPARATOR_DELTA;
}

static int
search_record_prefix_is_zero(const unsigned char *key)
{
    return key[0] == 0 && key[1] == 0 && key[2] == 0 && key[3] == 0;
}

static int
target_index(const unsigned char *path)
{
    unsigned int i;
    for (i = 0; i < 6; ++i) {
        if (memcmp(path, kSnowKeys[i], PATH_LENGTH) == 0)
            return (int)i;
    }
    return -1;
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
append_uint(char *line, size_t cap, size_t *pos, unsigned int value)
{
    char tmp[16];
    unsigned int n = 0;
    unsigned int i;

    if (value == 0) {
        if (*pos + 1 < cap)
            line[(*pos)++] = '0';
        return;
    }

    while (value != 0 && n < sizeof(tmp)) {
        tmp[n++] = (char)('0' + (value % 10U));
        value /= 10U;
    }
    for (i = 0; i < n; ++i) {
        if (*pos + 1 >= cap)
            return;
        line[(*pos)++] = tmp[n - 1U - i];
    }
}

static void
append_hex8(char *line, size_t cap, size_t *pos, const unsigned char *p)
{
    static const char digits[] = "0123456789abcdef";
    unsigned int i;

    for (i = 0; i < PATH_LENGTH; ++i) {
        unsigned int v = p[i];
        if (*pos + 2 >= cap)
            return;
        line[(*pos)++] = digits[(v >> 4) & 0xfU];
        line[(*pos)++] = digits[v & 0xfU];
    }
}

static void
append_component_text(char *line, size_t cap, size_t *pos,
                      const unsigned char *s)
{
    unsigned int i;

    for (i = 0; i < MAX_COMPONENT_TEXT; ++i) {
        unsigned int ch = s[i];
        if (ch == 0)
            return;
        if (*pos + 1 >= cap)
            return;
        if (ch <= 0x20U || ch >= 0x7fU || ch == '=')
            line[(*pos)++] = '_';
        else
            line[(*pos)++] = (char)ch;
    }
}

static int
append_semantic(char *line, size_t cap, size_t *pos,
                const void *base, unsigned int index_start,
                unsigned int component_count,
                const unsigned char *path)
{
    const unsigned char *index = (const unsigned char *)base;
    const unsigned char *header = index - index_start;
    unsigned int table_start = read_le32(header + 0x08);
    unsigned int string_pool = read_le32(header + 0x0c);
    unsigned int i;
    int wrote_any = 0;

    for (i = 0; i < PATH_LENGTH; ++i) {
        unsigned int ident = path[i];
        const unsigned char *entry;
        const unsigned char *s;
        unsigned int str_off;

        if (ident == 0)
            break;
        if (ident > component_count) {
            append_text(line, cap, pos, "UNRESOLVED");
            return 0;
        }

        entry = header + table_start + (ident - 1U) * 8U;
        str_off = read_le32(entry);
        s = header + string_pool + str_off;

        if (wrote_any)
            append_text(line, cap, pos, ".");
        append_component_text(line, cap, pos, s);
        wrote_any = 1;
    }

    if (!wrote_any)
        append_text(line, cap, pos, "EMPTY");
    return wrote_any;
}

static int
unique_key_index(const unsigned char *path)
{
    unsigned int i;

    for (i = 0; i < gUniqueCount; ++i) {
        if (memcmp(gUniqueKeys[i], path, PATH_LENGTH) == 0)
            return (int)i;
    }

    if (gUniqueCount >= MAX_UNIQUE_TRACE_KEYS)
        return -2;

    memcpy(gUniqueKeys[gUniqueCount], path, PATH_LENGTH);
    ++gUniqueCount;
    return (int)(gUniqueCount - 1U);
}

static void
log_target(int index, const char *mode, const char *action)
{
    char line[256];
    size_t pos = 0;

    if (index < 0 || index > 5)
        return;
    if (gSeen[index] > MAX_TARGET_LOGS_PER_PATH)
        return;

    append_text(line, sizeof(line), &pos,
                "PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=");
    append_text(line, sizeof(line), &pos, kNames[index]);
    append_text(line, sizeof(line), &pos, " mode=");
    append_text(line, sizeof(line), &pos, mode);
    append_text(line, sizeof(line), &pos, " action=");
    append_text(line, sizeof(line), &pos, action);
    append_text(line, sizeof(line), &pos, "\n");
    if (pos >= sizeof(line))
        return;
    line[pos] = '\0';
    write_literal(line);
}

static unsigned int
result_index(const void *result, const void *base, size_t nmemb, size_t size,
             int *valid)
{
    uintptr_t r = (uintptr_t)result;
    uintptr_t b = (uintptr_t)base;
    uintptr_t end = b + nmemb * size;
    uintptr_t delta;

    *valid = 0;
    if (result == NULL || r < b || r >= end || size == 0)
        return 0;

    delta = r - b;
    if ((delta % size) != 0)
        return 0;

    *valid = 1;
    return (unsigned int)(delta / size);
}

static void
log_trace_unique(const void *base,
                 unsigned int index_start,
                 unsigned int component_count,
                 const unsigned char *raw_path,
                 const unsigned char *effective_path,
                 int known_index,
                 const char *mode,
                 const char *action,
                 const void *result,
                 size_t nmemb,
                 size_t size)
{
    char line[768];
    size_t pos = 0;
    int unique;
    int result_valid;
    unsigned int result_idx;

    unique = unique_key_index(raw_path);
    if (unique == -1)
        return;
    if (unique == -2) {
        if (!gTraceLimitLogged) {
            log_build_once();
            write_literal("PM_COREUI_ARTFILE_BSEARCH_TRACE_LIMIT:unique_limit=256\n");
            gTraceLimitLogged = 1;
        }
        return;
    }

    result_idx = result_index(result, base, nmemb, size, &result_valid);

    log_build_once();
    append_text(line, sizeof(line), &pos,
                "PM_COREUI_ARTFILE_BSEARCH_TRACE:unique_index=");
    append_uint(line, sizeof(line), &pos, (unsigned int)unique + 1U);
    append_text(line, sizeof(line), &pos, " mode=");
    append_text(line, sizeof(line), &pos, mode);
    append_text(line, sizeof(line), &pos, " raw_key=");
    append_hex8(line, sizeof(line), &pos, raw_path);
    append_text(line, sizeof(line), &pos, " raw_semantic=");
    append_semantic(line, sizeof(line), &pos, base, index_start,
                    component_count, raw_path);
    append_text(line, sizeof(line), &pos, " known_exact_six=");
    append_text(line, sizeof(line), &pos, known_index >= 0 ? "YES" : "NO");
    append_text(line, sizeof(line), &pos, " action=");
    append_text(line, sizeof(line), &pos, action);
    append_text(line, sizeof(line), &pos, " effective_key=");
    append_hex8(line, sizeof(line), &pos, effective_path);
    append_text(line, sizeof(line), &pos, " effective_semantic=");
    append_semantic(line, sizeof(line), &pos, base, index_start,
                    component_count, effective_path);
    append_text(line, sizeof(line), &pos, " result=");
    append_text(line, sizeof(line), &pos, result != NULL ? "HIT" : "MISS");
    append_text(line, sizeof(line), &pos, " result_index=");
    if (result_valid)
        append_uint(line, sizeof(line), &pos, result_idx);
    else
        append_text(line, sizeof(line), &pos, "NONE");
    append_text(line, sizeof(line), &pos, "\n");

    if (pos >= sizeof(line))
        return;
    line[pos] = '\0';
    write_literal(line);
}

static bsearch_fn
original_function(void)
{
    if (gOriginal == NULL)
        gOriginal = (bsearch_fn)(uintptr_t)sBsearchInterpose.replacee;
    return gOriginal;
}

static void *
rosetta_bsearch(const void *key,
                const void *base,
                size_t nmemb,
                size_t size,
                bsearch_comparator_fn compar)
{
    bsearch_fn fn = original_function();
    const char *mode = getenv(MODE_ENV);
    const unsigned char *record = (const unsigned char *)key;
    const unsigned char *path;
    const void *caller = __builtin_return_address(0);
    unsigned char translated[RECORD_SIZE];
    int index;
    int callsite_ok;
    int prefix_ok;
    void *result;

    if (fn == NULL || fn == (bsearch_fn)&rosetta_bsearch)
        return NULL;

    if (key == NULL || size != RECORD_SIZE)
        return fn(key, base, nmemb, size, compar);

    path = record + PATH_OFFSET;
    index = target_index(path);
    callsite_ok = callsite_matches(compar, caller);
    prefix_ok = search_record_prefix_is_zero(record);

    if (mode != NULL && strcmp(mode, MODE_SNOW_TRACE) == 0) {
        int guard_ok = callsite_ok && prefix_ok &&
            header_matches(base, nmemb,
                           SNOW_RECORD_COUNT, SNOW_COMPONENT_COUNT,
                           SNOW_INDEX_START, SNOW_PAYLOAD_START);

        result = fn(key, base, nmemb, size, compar);
        if (guard_ok) {
            log_trace_unique(base, SNOW_INDEX_START, SNOW_COMPONENT_COUNT,
                             path, path, index, MODE_SNOW_TRACE,
                             "PASSTHROUGH", result, nmemb, size);
            if (index >= 0) {
                ++gSeen[index];
                log_build_once();
                log_target(index, MODE_SNOW_TRACE, "PASSTHROUGH");
            }
        }
        return result;
    }

    if (mode != NULL && strcmp(mode, MODE_LION_TRACE) == 0) {
        int guard_ok = callsite_ok && prefix_ok &&
            header_matches(base, nmemb,
                           LION_RECORD_COUNT, LION_COMPONENT_COUNT,
                           LION_INDEX_START, LION_PAYLOAD_START);

        if (index >= 0) {
            ++gSeen[index];
            if (!guard_ok) {
                log_build_once();
                log_target(index, MODE_LION_TRACE,
                           "GUARD_REJECT_PASSTHROUGH");
                return fn(key, base, nmemb, size, compar);
            }

            memcpy(translated, record, RECORD_SIZE);
            memcpy(translated + PATH_OFFSET, kLionKeys[index], PATH_LENGTH);
            result = fn(translated, base, nmemb, size, compar);
            log_trace_unique(base, LION_INDEX_START, LION_COMPONENT_COUNT,
                             path, translated + PATH_OFFSET, index,
                             MODE_LION_TRACE, "TRANSLATED",
                             result, nmemb, size);
            log_build_once();
            log_target(index, MODE_LION_TRACE, "TRANSLATED");
            return result;
        }

        result = fn(key, base, nmemb, size, compar);
        if (guard_ok) {
            log_trace_unique(base, LION_INDEX_START, LION_COMPONENT_COUNT,
                             path, path, -1, MODE_LION_TRACE,
                             "PASSTHROUGH", result, nmemb, size);
        }
        return result;
    }

    return fn(key, base, nmemb, size, compar);
}

__attribute__((used))
static struct interpose_tuple sBsearchInterpose
__attribute__((section("__DATA,__interpose"))) = {
    (const void *)(uintptr_t)&rosetta_bsearch,
    (const void *)(uintptr_t)&bsearch
};
