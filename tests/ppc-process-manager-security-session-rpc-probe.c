#include <Security/AuthSession.h>
#include <stdio.h>

static void
marker(const char *text)
{
    fprintf(stderr, "%s\n", text);
    fflush(stderr);
}

int
main(void)
{
    SecuritySessionId sessionId = noSecuritySession;
    SessionAttributeBits attributes = 0;
    OSStatus status;

    marker("PM_SECURITY_SESSION_MILESTONE:M00_MAIN_ENTER");
    marker("PM_SECURITY_SESSION_MILESTONE:M01_BEFORE_SessionGetInfo");

    status = SessionGetInfo(callerSecuritySession, &sessionId, &attributes);

    fprintf(stderr, "PM_SECURITY_SESSION_STATUS:SessionGetInfo=%ld\n",
            (long)status);
    fprintf(stderr, "PM_SECURITY_SESSION_VALUE:ID=0x%08lx ATTRS=0x%08lx\n",
            (unsigned long)sessionId, (unsigned long)attributes);
    fflush(stderr);

    marker("PM_SECURITY_SESSION_MILESTONE:M02_AFTER_SessionGetInfo");

    if (status != noErr) {
        marker("PM_SECURITY_SESSION_RESULT:SESSIONGETINFO_ERROR");
        return 21;
    }

    if (sessionId == noSecuritySession) {
        marker("PM_SECURITY_SESSION_RESULT:SESSIONGETINFO_ZERO_SESSION");
        return 22;
    }

    marker("PM_SECURITY_SESSION_RESULT:PASS");
    marker("PM_SECURITY_SESSION_MILESTONE:M03_SUCCESS");
    return 0;
}
