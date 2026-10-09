#include <mach/mach.h>
#include <servers/bootstrap.h>
#include <stdint.h>
#include <stdio.h>

extern kern_return_t bootstrap_look_up2(mach_port_t,
                                        const char *,
                                        mach_port_t *,
                                        pid_t,
                                        uint64_t);

#define BUILD_ID "distributed-notifications-bootstrap-probe-v1"
#define BUILD_MARKER \
    "PM_DISTRIBUTED_NOTIFICATIONS_PROBE_BUILD_ID:" BUILD_ID
#define SERVICE_NAME "com.apple.distributed_notifications.2"
#define LOOKUP_FLAGS 0x0000000000000008ULL

int
main(void)
{
    mach_port_t bp = MACH_PORT_NULL;
    mach_port_t service = MACH_PORT_NULL;
    mach_port_type_t type = 0;
    kern_return_t kr;
    kern_return_t type_kr;

    fprintf(stderr, "%s\n", BUILD_MARKER);
    fflush(stderr);

    kr = task_get_bootstrap_port(mach_task_self(), &bp);
    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_PROBE_BOOTSTRAP_PORT:kr=%ld hex=0x%08lx port=0x%08lx\n",
            (long)kr,
            (unsigned long)(uint32_t)kr,
            (unsigned long)bp);
    fflush(stderr);
    if (kr != KERN_SUCCESS || bp == MACH_PORT_NULL)
        return 20;

    kr = bootstrap_look_up2(bp,
                            SERVICE_NAME,
                            &service,
                            (pid_t)0,
                            LOOKUP_FLAGS);
    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_PROBE_LOOKUP:kr=%ld hex=0x%08lx servicePort=0x%08lx\n",
            (long)kr,
            (unsigned long)(uint32_t)kr,
            (unsigned long)service);
    fflush(stderr);
    if (kr != KERN_SUCCESS || service == MACH_PORT_NULL)
        return 21;

    type_kr = mach_port_type(mach_task_self(), service, &type);
    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_PROBE_PORT_TYPE:kr=%ld hex=0x%08lx type=0x%08lx hasSend=%s\n",
            (long)type_kr,
            (unsigned long)(uint32_t)type_kr,
            (unsigned long)type,
            (type_kr == KERN_SUCCESS &&
             (type & MACH_PORT_TYPE_SEND) != 0) ? "YES" : "NO");
    fflush(stderr);
    if (type_kr != KERN_SUCCESS ||
        (type & MACH_PORT_TYPE_SEND) == 0) {
        (void)mach_port_deallocate(mach_task_self(), service);
        return 22;
    }

    (void)mach_port_deallocate(mach_task_self(), service);
    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_PROBE_RESULT:PASS\n");
    fflush(stderr);
    return 0;
}
