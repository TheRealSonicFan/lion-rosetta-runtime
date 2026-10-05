#include <mach/mach.h>
#include <dlfcn.h>
#include <stdio.h>

extern mach_port_t scCreateSystemServiceVersion(const char *serviceName,
                                                 unsigned long requestedVersion,
                                                 unsigned long *actualVersion);

typedef mach_port_t (*sc_get_server_checkin_port_fn)(void);
typedef unsigned long (*sc_get_process_options_fn)(void);

static void
marker(const char *text)
{
    fprintf(stderr, "%s\n", text);
    fflush(stderr);
}

int
main(void)
{
    sc_get_server_checkin_port_fn getServerCheckinPort;
    sc_get_process_options_fn getProcessOptions;
    mach_port_t servicePort = MACH_PORT_NULL;
    mach_port_t checkinPort = MACH_PORT_NULL;
    unsigned long actualVersion = 0;
    unsigned long processOptions = 0;

    marker("PM_SYSTEMSERVICE_STAGE_MILESTONE:M00_MAIN_ENTER");

    getServerCheckinPort = (sc_get_server_checkin_port_fn)
        dlsym(RTLD_DEFAULT, "scGetServerCheckinPort");
    getProcessOptions = (sc_get_process_options_fn)
        dlsym(RTLD_DEFAULT, "scGetProcessOptions");

    fprintf(stderr, "PM_SYSTEMSERVICE_STAGE_HELPER:scGetServerCheckinPort=%s\n",
            getServerCheckinPort ? "FOUND" : "MISSING");
    fprintf(stderr, "PM_SYSTEMSERVICE_STAGE_HELPER:scGetProcessOptions=%s\n",
            getProcessOptions ? "FOUND" : "MISSING");
    fflush(stderr);

    if (!getServerCheckinPort || !getProcessOptions) {
        marker("PM_SYSTEMSERVICE_STAGE_RESULT:PRIVATE_HELPER_UNAVAILABLE");
        return 30;
    }

    marker("PM_SYSTEMSERVICE_STAGE_MILESTONE:M01_BEFORE_scCreateSystemServiceVersion");
    servicePort = scCreateSystemServiceVersion("LaunchApplicationServices",
                                               0x00010000UL,
                                               &actualVersion);
    fprintf(stderr,
            "PM_SYSTEMSERVICE_STAGE_SERVICE:port=0x%08lx actualVersion=0x%08lx\n",
            (unsigned long)servicePort, actualVersion);
    fflush(stderr);
    marker("PM_SYSTEMSERVICE_STAGE_MILESTONE:M02_AFTER_scCreateSystemServiceVersion");

    marker("PM_SYSTEMSERVICE_STAGE_MILESTONE:M03_BEFORE_scGetServerCheckinPort");
    checkinPort = getServerCheckinPort();
    fprintf(stderr,
            "PM_SYSTEMSERVICE_STAGE_CHECKIN:port=0x%08lx\n",
            (unsigned long)checkinPort);
    fflush(stderr);
    marker("PM_SYSTEMSERVICE_STAGE_MILESTONE:M04_AFTER_scGetServerCheckinPort");

    marker("PM_SYSTEMSERVICE_STAGE_MILESTONE:M05_BEFORE_scGetProcessOptions");
    processOptions = getProcessOptions();
    fprintf(stderr,
            "PM_SYSTEMSERVICE_STAGE_OPTIONS:0x%08lx\n",
            processOptions);
    fflush(stderr);
    marker("PM_SYSTEMSERVICE_STAGE_MILESTONE:M06_AFTER_scGetProcessOptions");

    if (servicePort != MACH_PORT_NULL)
        (void)mach_port_deallocate(mach_task_self(), servicePort);

    if (servicePort != MACH_PORT_NULL && checkinPort != MACH_PORT_NULL) {
        marker("PM_SYSTEMSERVICE_STAGE_RESULT:STAGE_CONTROL_PASS");
        return 0;
    }

    if (servicePort == MACH_PORT_NULL && checkinPort == MACH_PORT_NULL) {
        marker("PM_SYSTEMSERVICE_STAGE_RESULT:CHECKIN_SESSION_UNAVAILABLE");
        return 20;
    }

    if (servicePort == MACH_PORT_NULL && checkinPort != MACH_PORT_NULL) {
        marker("PM_SYSTEMSERVICE_STAGE_RESULT:SERVICE_LOOKUP_FAILURE_AFTER_CHECKIN");
        return 21;
    }

    marker("PM_SYSTEMSERVICE_STAGE_RESULT:INCONSISTENT_SERVICE_WITHOUT_CHECKIN");
    return 22;
}
