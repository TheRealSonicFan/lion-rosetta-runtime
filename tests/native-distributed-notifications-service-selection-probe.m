#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

#include <stdio.h>
#include <string.h>

#define BUILD_ID "distributed-notifications-native-service-selection-probe-v1"
#define BUILD_MARKER \
    "PM_DISTRIBUTED_NOTIFICATIONS_NATIVE_PROBE_BUILD_ID:" BUILD_ID

static int
run_cf_mode(void)
{
    CFNotificationCenterRef center;

    fprintf(stderr, "PM_DISTRIBUTED_NOTIFICATIONS_NATIVE_PROBE_MODE:CF:BEGIN\n");
    fflush(stderr);

    center = CFNotificationCenterGetDistributedCenter();

    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_NATIVE_PROBE_CF_CENTER:pointer=%p\n",
            center);
    fflush(stderr);

    if (center == NULL)
        return 21;

    fprintf(stderr, "PM_DISTRIBUTED_NOTIFICATIONS_NATIVE_PROBE_MODE:CF:PASS\n");
    fflush(stderr);
    return 0;
}

static int
run_foundation_mode(void)
{
    NSDistributedNotificationCenter *center;

    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_NATIVE_PROBE_MODE:FOUNDATION:BEGIN\n");
    fflush(stderr);

    center = [NSDistributedNotificationCenter defaultCenter];

    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_NATIVE_PROBE_FOUNDATION_CENTER:pointer=%p\n",
            center);
    fflush(stderr);

    if (center == nil)
        return 22;

    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_NATIVE_PROBE_MODE:FOUNDATION:PASS\n");
    fflush(stderr);
    return 0;
}

int
main(int argc, char **argv)
{
    fprintf(stderr, "%s\n", BUILD_MARKER);
    fflush(stderr);

    if (argc != 2) {
        fprintf(stderr, "usage: %s cf|foundation\n", argv[0]);
        return 64;
    }

    if (strcmp(argv[1], "cf") == 0)
        return run_cf_mode();

    if (strcmp(argv[1], "foundation") == 0)
        return run_foundation_mode();

    fprintf(stderr, "unknown mode: %s\n", argv[1]);
    return 64;
}
