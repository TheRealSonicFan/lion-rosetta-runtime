#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define BUILD_ID "cgwindowlist-pid-observer-v1"
#define BUILD_MARKER "CGWINDOW_OBSERVER_BUILD_ID:" BUILD_ID
#define MAX_DISPLAYS 16

static int
dict_number_s64(CFDictionaryRef dict, CFStringRef key, long long *out)
{
    CFTypeRef value = CFDictionaryGetValue(dict, key);
    int64_t v = 0;
    if (value == NULL || CFGetTypeID(value) != CFNumberGetTypeID())
        return 0;
    if (!CFNumberGetValue((CFNumberRef)value, kCFNumberSInt64Type, &v))
        return 0;
    *out = (long long)v;
    return 1;
}

static int
dict_number_double(CFDictionaryRef dict, CFStringRef key, double *out)
{
    CFTypeRef value = CFDictionaryGetValue(dict, key);
    double v = 0.0;
    if (value == NULL || CFGetTypeID(value) != CFNumberGetTypeID())
        return 0;
    if (!CFNumberGetValue((CFNumberRef)value, kCFNumberDoubleType, &v))
        return 0;
    *out = v;
    return 1;
}

static int
dict_bool(CFDictionaryRef dict, CFStringRef key, int *out)
{
    CFTypeRef value = CFDictionaryGetValue(dict, key);
    if (value == NULL)
        return 0;
    if (CFGetTypeID(value) == CFBooleanGetTypeID()) {
        *out = CFBooleanGetValue((CFBooleanRef)value) ? 1 : 0;
        return 1;
    }
    if (CFGetTypeID(value) == CFNumberGetTypeID()) {
        int v = 0;
        if (!CFNumberGetValue((CFNumberRef)value, kCFNumberIntType, &v))
            return 0;
        *out = v ? 1 : 0;
        return 1;
    }
    return 0;
}

static void
copy_cfstring(CFTypeRef value, char *buffer, size_t size)
{
    CFIndex i;
    if (size == 0)
        return;
    buffer[0] = '\0';
    if (value == NULL || CFGetTypeID(value) != CFStringGetTypeID())
        return;
    if (!CFStringGetCString((CFStringRef)value, buffer, (CFIndex)size,
                            kCFStringEncodingUTF8)) {
        strcpy(buffer, "<unrepresentable>");
        return;
    }
    for (i = 0; buffer[i] != '\0'; ++i) {
        if (buffer[i] == '\n' || buffer[i] == '\r' || buffer[i] == '\t')
            buffer[i] = ' ';
    }
}

static int
title_matches(CFDictionaryRef dict, const char *expected_title)
{
    char name[512];
    if (expected_title == NULL || expected_title[0] == '\0')
        return 0;
    copy_cfstring(CFDictionaryGetValue(dict, kCGWindowName),
                  name, sizeof(name));
    return strcmp(name, expected_title) == 0;
}

int
main(int argc, char **argv)
{
    pid_t target_pid;
    long duration_ms;
    long interval_ms;
    const char *expected_title = NULL;
    long samples;
    long sample_index;
    long samples_with_windows = 0;
    long samples_with_onscreen = 0;
    long samples_with_exact_title = 0;
    long max_windows = 0;
    long max_onscreen = 0;
    long max_exact_title = 0;
    CGDirectDisplayID main_display;
    CGRect main_bounds;
    CGDirectDisplayID displays[MAX_DISPLAYS];
    uint32_t display_count = 0;
    CGError display_err;
    uint32_t di;

    if (argc < 4 || argc > 5) {
        fprintf(stderr,
                "usage: %s <pid> <duration-ms> <interval-ms> [expected-title]\n",
                argv[0]);
        return 64;
    }

    target_pid = (pid_t)strtol(argv[1], NULL, 10);
    duration_ms = strtol(argv[2], NULL, 10);
    interval_ms = strtol(argv[3], NULL, 10);
    if (argc == 5)
        expected_title = argv[4];

    if (target_pid <= 0 || duration_ms <= 0 || interval_ms <= 0 ||
        interval_ms > duration_ms) {
        fprintf(stderr, "error: invalid observer arguments\n");
        return 64;
    }

    samples = (duration_ms + interval_ms - 1) / interval_ms;

    printf("%s\n", BUILD_MARKER);
    printf("CGWINDOW_OBSERVER_START:pid=%ld durationMs=%ld intervalMs=%ld samples=%ld title=%s\n",
           (long)target_pid, duration_ms, interval_ms, samples,
           expected_title != NULL ? expected_title : "<none>");

    main_display = CGMainDisplayID();
    main_bounds = CGDisplayBounds(main_display);
    display_err = CGGetActiveDisplayList(MAX_DISPLAYS, displays, &display_count);
    printf("CGWINDOW_OBSERVER_MAIN_DISPLAY:id=0x%08x x=%.0f y=%.0f width=%.0f height=%.0f activeListError=%d activeCount=%u\n",
           (unsigned int)main_display,
           main_bounds.origin.x, main_bounds.origin.y,
           main_bounds.size.width, main_bounds.size.height,
           (int)display_err, (unsigned int)display_count);
    for (di = 0; di < display_count && di < MAX_DISPLAYS; ++di) {
        CGRect b = CGDisplayBounds(displays[di]);
        printf("CGWINDOW_OBSERVER_ACTIVE_DISPLAY:index=%u id=0x%08x x=%.0f y=%.0f width=%.0f height=%.0f main=%s\n",
               (unsigned int)di, (unsigned int)displays[di],
               b.origin.x, b.origin.y, b.size.width, b.size.height,
               displays[di] == main_display ? "YES" : "NO");
    }
    fflush(stdout);

    for (sample_index = 1; sample_index <= samples; ++sample_index) {
        CFArrayRef windows =
            CGWindowListCopyWindowInfo(kCGWindowListOptionAll,
                                       kCGNullWindowID);
        CFIndex count = windows != NULL ? CFArrayGetCount(windows) : 0;
        CFIndex i;
        long matches = 0;
        long onscreen_matches = 0;
        long exact_title_matches = 0;

        for (i = 0; i < count; ++i) {
            CFTypeRef item = CFArrayGetValueAtIndex(windows, i);
            CFDictionaryRef dict;
            long long owner_pid = -1;
            long long window_number = -1;
            long long layer = 0;
            long long sharing = -1;
            long long store = -1;
            long long memory = -1;
            double alpha = -1.0;
            int onscreen = 0;
            int have_onscreen;
            CGRect bounds = CGRectNull;
            CFTypeRef bounds_value;
            char owner_name[512];
            char window_name[512];

            if (item == NULL ||
                CFGetTypeID(item) != CFDictionaryGetTypeID())
                continue;
            dict = (CFDictionaryRef)item;

            if (!dict_number_s64(dict, kCGWindowOwnerPID, &owner_pid) ||
                owner_pid != (long long)target_pid)
                continue;

            ++matches;
            (void)dict_number_s64(dict, kCGWindowNumber, &window_number);
            (void)dict_number_s64(dict, kCGWindowLayer, &layer);
            (void)dict_number_s64(dict, kCGWindowSharingState, &sharing);
            (void)dict_number_s64(dict, kCGWindowStoreType, &store);
            (void)dict_number_s64(dict, kCGWindowMemoryUsage, &memory);
            (void)dict_number_double(dict, kCGWindowAlpha, &alpha);
            have_onscreen = dict_bool(dict, kCGWindowIsOnscreen, &onscreen);
            bounds_value = CFDictionaryGetValue(dict, kCGWindowBounds);
            if (bounds_value != NULL &&
                CFGetTypeID(bounds_value) == CFDictionaryGetTypeID())
                (void)CGRectMakeWithDictionaryRepresentation(
                    (CFDictionaryRef)bounds_value, &bounds);
            copy_cfstring(CFDictionaryGetValue(dict, kCGWindowOwnerName),
                          owner_name, sizeof(owner_name));
            copy_cfstring(CFDictionaryGetValue(dict, kCGWindowName),
                          window_name, sizeof(window_name));

            if (have_onscreen && onscreen)
                ++onscreen_matches;
            if (title_matches(dict, expected_title))
                ++exact_title_matches;

            printf("CGWINDOW_OBSERVER_WINDOW:sample=%ld pid=%lld window=%lld onscreen=%s layer=%lld alpha=%.3f x=%.0f y=%.0f width=%.0f height=%.0f sharing=%lld store=%lld memory=%lld owner=%s name=%s\n",
                   sample_index, owner_pid, window_number,
                   have_onscreen ? (onscreen ? "YES" : "NO") : "UNKNOWN",
                   layer, alpha,
                   CGRectIsNull(bounds) ? -1.0 : bounds.origin.x,
                   CGRectIsNull(bounds) ? -1.0 : bounds.origin.y,
                   CGRectIsNull(bounds) ? -1.0 : bounds.size.width,
                   CGRectIsNull(bounds) ? -1.0 : bounds.size.height,
                   sharing, store, memory,
                   owner_name[0] != '\0' ? owner_name : "<none>",
                   window_name[0] != '\0' ? window_name : "<none>");
        }

        if (matches > 0)
            ++samples_with_windows;
        if (onscreen_matches > 0)
            ++samples_with_onscreen;
        if (exact_title_matches > 0)
            ++samples_with_exact_title;
        if (matches > max_windows)
            max_windows = matches;
        if (onscreen_matches > max_onscreen)
            max_onscreen = onscreen_matches;
        if (exact_title_matches > max_exact_title)
            max_exact_title = exact_title_matches;

        printf("CGWINDOW_OBSERVER_SAMPLE:index=%ld totalWindows=%ld targetWindows=%ld onscreenWindows=%ld exactTitleWindows=%ld\n",
               sample_index, (long)count, matches, onscreen_matches,
               exact_title_matches);
        fflush(stdout);

        if (windows != NULL)
            CFRelease(windows);

        if (sample_index != samples)
            usleep((useconds_t)(interval_ms * 1000));
    }

    printf("CGWINDOW_OBSERVER_SUMMARY:pid=%ld samples=%ld samplesWithWindows=%ld samplesWithOnscreen=%ld samplesWithExactTitle=%ld maxWindows=%ld maxOnscreen=%ld maxExactTitle=%ld\n",
           (long)target_pid, samples, samples_with_windows,
           samples_with_onscreen, samples_with_exact_title,
           max_windows, max_onscreen, max_exact_title);
    printf("CGWINDOW_OBSERVER_RESULT:PASS\n");
    return 0;
}
