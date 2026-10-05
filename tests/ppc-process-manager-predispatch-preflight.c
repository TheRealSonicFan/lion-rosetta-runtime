#include <Security/AuthSession.h>
#include <mach/mach.h>
#include <stdio.h>
#include <unistd.h>

extern mach_port_t scCreateSystemServiceVersion(const char *serviceName,
                                                 unsigned long requestedVersion,
                                                 unsigned long *actualVersion);

static void
marker(const char *text)
{
    fprintf(stderr, "%s\n", text);
    fflush(stderr);
}

int
main(void)
{
    mach_port_t servicePort = MACH_PORT_NULL;
    SecuritySessionId sessionId = noSecuritySession;
    SessionAttributeBits attributes = 0;
    OSStatus status;

    marker("PM_PREDISPATCH_MILESTONE:M00_MAIN_ENTER");

    marker("PM_PREDISPATCH_MILESTONE:M01_BEFORE_scCreateSystemServiceVersion");
    servicePort = scCreateSystemServiceVersion("LaunchApplicationServices",
                                               0x00010000UL,
                                               NULL);
    fprintf(stderr,
            "PM_PREDISPATCH_PORT:LaunchApplicationServices=0x%08lx\n",
            (unsigned long)servicePort);
    fflush(stderr);
    marker("PM_PREDISPATCH_MILESTONE:M02_AFTER_scCreateSystemServiceVersion");

    if (servicePort == MACH_PORT_NULL) {
        marker("PM_PREDISPATCH_RESULT:SYSTEMSERVICE_ZERO_PORT");
        return 20;
    }

    marker("PM_PREDISPATCH_MILESTONE:M03_BEFORE_SessionGetInfo");
    status = SessionGetInfo(callerSecuritySession, &sessionId, &attributes);
    fprintf(stderr, "PM_PREDISPATCH_STATUS:SessionGetInfo=%ld\n", (long)status);
    fprintf(stderr, "PM_PREDISPATCH_SESSION:ID=0x%08lx ATTRS=0x%08lx\n",
            (unsigned long)sessionId, (unsigned long)attributes);
    fflush(stderr);
    marker("PM_PREDISPATCH_MILESTONE:M04_AFTER_SessionGetInfo");

    if (servicePort != MACH_PORT_NULL)
        (void)mach_port_deallocate(mach_task_self(), servicePort);

    if (status != noErr) {
        marker("PM_PREDISPATCH_RESULT:SESSIONGETINFO_ERROR");
        return 21;
    }

    if (sessionId == noSecuritySession) {
        marker("PM_PREDISPATCH_RESULT:SESSIONGETINFO_ZERO_SESSION");
        return 22;
    }

    marker("PM_PREDISPATCH_RESULT:PREDISPATCH_PRIMITIVES_PASS");
    marker("PM_PREDISPATCH_MILESTONE:M05_SUCCESS");
    return 0;
}
