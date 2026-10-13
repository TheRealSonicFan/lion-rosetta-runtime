#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define BUILD_ID "coreui-titlebar-bsearch-exact-six-v2"
#define BUILD_MARKER "PM_COREUI_TITLEBAR_BSEARCH_BUILD_ID:" BUILD_ID "\n"

#define MODE_ENV "ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_MODE"
#define MODE_PASSTHROUGH "passthrough"
#define MODE_LION "lion-exact-six-v1"

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
#define MAX_LOGS_PER_PATH 8U

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
log_target(int index, const char *mode, const char *action)
{
    char line[256];
    const char *prefix = "PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=";
    const char *mid1 = " mode=";
    const char *mid2 = " action=";
    const char *suffix = "\n";
    size_t pos = 0;
    const char *parts[7];
    unsigned int i;

    if (index < 0 || index > 5)
        return;
    if (gSeen[index] > MAX_LOGS_PER_PATH)
        return;

    parts[0] = prefix;
    parts[1] = kNames[index];
    parts[2] = mid1;
    parts[3] = mode;
    parts[4] = mid2;
    parts[5] = action;
    parts[6] = suffix;

    for (i = 0; i < 7; ++i) {
        size_t n = strlen(parts[i]);
        if (pos + n >= sizeof(line))
            return;
        memcpy(line + pos, parts[i], n);
        pos += n;
    }
    line[pos] = '\0';
    write_literal(line);
}

static bsearch_fn
original_function(void)
{
    if (gOriginal == NULL) {
        gOriginal = (bsearch_fn)(uintptr_t)sBsearchInterpose.replacee;
    }
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
    const void *caller = __builtin_return_address(0);
    unsigned char translated[RECORD_SIZE];
    int index;
    int callsite_ok;

    if (fn == NULL || fn == (bsearch_fn)&rosetta_bsearch)
        return NULL;

    if (key == NULL || size != RECORD_SIZE)
        return fn(key, base, nmemb, size, compar);

    index = target_index(record + PATH_OFFSET);
    if (index < 0)
        return fn(key, base, nmemb, size, compar);

    callsite_ok = callsite_matches(compar, caller);

    if (mode != NULL && strcmp(mode, MODE_PASSTHROUGH) == 0) {
        if (callsite_ok &&
            search_record_prefix_is_zero(record) &&
            header_matches(base, nmemb,
                           SNOW_RECORD_COUNT, SNOW_COMPONENT_COUNT,
                           SNOW_INDEX_START, SNOW_PAYLOAD_START)) {
            ++gSeen[index];
            log_build_once();
            log_target(index, MODE_PASSTHROUGH, "PASSTHROUGH");
        }
        return fn(key, base, nmemb, size, compar);
    }

    if (mode != NULL && strcmp(mode, MODE_LION) == 0) {
        if (!callsite_ok ||
            !search_record_prefix_is_zero(record) ||
            !header_matches(base, nmemb,
                            LION_RECORD_COUNT, LION_COMPONENT_COUNT,
                            LION_INDEX_START, LION_PAYLOAD_START)) {
            ++gSeen[index];
            log_build_once();
            log_target(index, MODE_LION, "GUARD_REJECT_PASSTHROUGH");
            return fn(key, base, nmemb, size, compar);
        }

        memcpy(translated, record, RECORD_SIZE);
        memcpy(translated + PATH_OFFSET, kLionKeys[index], PATH_LENGTH);
        ++gSeen[index];
        log_build_once();
        log_target(index, MODE_LION, "TRANSLATED");
        return fn(translated, base, nmemb, size, compar);
    }

    return fn(key, base, nmemb, size, compar);
}

__attribute__((used))
static struct interpose_tuple sBsearchInterpose
__attribute__((section("__DATA,__interpose"))) = {
    (const void *)(uintptr_t)&rosetta_bsearch,
    (const void *)(uintptr_t)&bsearch
};
