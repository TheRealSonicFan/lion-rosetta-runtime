#include <mach/mach.h>
#include <mach/kern_return.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>

extern mach_port_t bootstrap_port;
extern kern_return_t bootstrap_look_up2(mach_port_t bp,
                                         const char *service_name,
                                         mach_port_t *service_port,
                                         pid_t target_pid,
                                         unsigned int flags);

static void
marker(const char *text)
{
    fprintf(stderr, "%s\n", text);
    fflush(stderr);
}

int
main(void)
{
    const char *serviceName = "com.apple.CoreServices.coreservicesd";
    const char *overrideName = getenv("CORESERVICESD_SERVICE_NAME");
    const char *dontUseServer = getenv("SCDontUseServer");
    mach_port_t servicePort = MACH_PORT_NULL;
    kern_return_t kr;

    marker("PM_BOOTSTRAP_LOOKUP_MILESTONE:M00_MAIN_ENTER");
    fprintf(stderr, "PM_BOOTSTRAP_LOOKUP_BOOTSTRAP_PORT:0x%08lx\n",
            (unsigned long)bootstrap_port);
    fprintf(stderr, "PM_BOOTSTRAP_LOOKUP_ENV:CORESERVICESD_SERVICE_NAME=%s\n",
            overrideName ? "SET" : "UNSET");
    fprintf(stderr, "PM_BOOTSTRAP_LOOKUP_ENV:SCDontUseServer=%s\n",
            dontUseServer ? "SET" : "UNSET");
    fprintf(stderr, "PM_BOOTSTRAP_LOOKUP_NAME:%s\n", serviceName);
    fprintf(stderr, "PM_BOOTSTRAP_LOOKUP_TARGET_PID:0\n");
    fprintf(stderr, "PM_BOOTSTRAP_LOOKUP_FLAGS:0x00000008\n");
    fflush(stderr);

    if (overrideName || dontUseServer) {
        marker("PM_BOOTSTRAP_LOOKUP_RESULT:ENVIRONMENT_NOT_CLEAN");
        return 30;
    }

    if (bootstrap_port == MACH_PORT_NULL) {
        marker("PM_BOOTSTRAP_LOOKUP_RESULT:BOOTSTRAP_PORT_NULL");
        return 22;
    }

    marker("PM_BOOTSTRAP_LOOKUP_MILESTONE:M01_BEFORE_bootstrap_look_up2");
    kr = bootstrap_look_up2(bootstrap_port,
                            serviceName,
                            &servicePort,
                            (pid_t)0,
                            0x00000008U);
    fprintf(stderr,
            "PM_BOOTSTRAP_LOOKUP_RETURN:kr=%ld hex=0x%08lx servicePort=0x%08lx\n",
            (long)kr,
            (unsigned long)((unsigned int)kr),
            (unsigned long)servicePort);
    fflush(stderr);
    marker("PM_BOOTSTRAP_LOOKUP_MILESTONE:M02_AFTER_bootstrap_look_up2");

    if (kr != KERN_SUCCESS) {
        marker("PM_BOOTSTRAP_LOOKUP_RESULT:LOOKUP_ERROR");
        return 20;
    }

    if (servicePort == MACH_PORT_NULL) {
        marker("PM_BOOTSTRAP_LOOKUP_RESULT:LOOKUP_ZERO_PORT");
        return 21;
    }

    (void)mach_port_deallocate(mach_task_self(), servicePort);
    marker("PM_BOOTSTRAP_LOOKUP_RESULT:LOOKUP_PASS");
    marker("PM_BOOTSTRAP_LOOKUP_MILESTONE:M03_SUCCESS");
    return 0;
}
