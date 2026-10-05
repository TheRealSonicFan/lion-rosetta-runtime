#include <Carbon/Carbon.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

#define MILESTONE_LOG_PATH "/tmp/rosetta-processmanager-alternate-milestone.log"

static Boolean gTimerFired = false;

static void
append_line(const char *line)
{
    int fd;
    size_t len;

    if (line == NULL)
        return;

    len = strlen(line);
    (void)write(STDERR_FILENO, line, len);

    fd = open(MILESTONE_LOG_PATH, O_WRONLY | O_CREAT | O_APPEND, 0600);
    if (fd >= 0) {
        (void)write(fd, line, len);
        (void)close(fd);
    }
}

#define MILESTONE(name) append_line("PM_ALT_MILESTONE:" name "\n")

static void
log_status(const char *name, OSStatus status)
{
    char line[256];
    snprintf(line, sizeof(line), "PM_ALT_STATUS:%s=%ld\n", name, (long)status);
    append_line(line);
}

static void
log_psn(const char *name, const ProcessSerialNumber *psn)
{
    char line[256];
    snprintf(line, sizeof(line),
             "PM_ALT_PSN:%s=0x%08lx:0x%08lx\n",
             name,
             (unsigned long)psn->highLongOfPSN,
             (unsigned long)psn->lowLongOfPSN);
    append_line(line);
}

static void
log_pid(const char *name, pid_t pid)
{
    char line[256];
    snprintf(line, sizeof(line), "PM_ALT_PID:%s=%ld\n", name, (long)pid);
    append_line(line);
}

static pascal void
QuitTimer(EventLoopTimerRef timer, void *userData)
{
    Boolean *fired = (Boolean *)userData;
    (void)timer;

    MILESTONE("M21_TIMER_CALLBACK_ENTER");
    *fired = true;
    QuitApplicationEventLoop();
    MILESTONE("M22_TIMER_CALLBACK_EXIT");
}

int
main(void)
{
    ProcessSerialNumber pseudo = { 0, kCurrentProcess };
    ProcessSerialNumber resolved = { 0, 0 };
    ProcessSerialNumber *active = NULL;
    pid_t self = getpid();
    pid_t roundtrip = -1;
    WindowRef window = NULL;
    EventLoopTimerRef timer = NULL;
    EventLoopTimerUPP timerUPP = NULL;
    CFStringRef title = NULL;
    Rect bounds = { 140, 140, 340, 560 };
    WindowAttributes attributes;
    OSStatus status;

    MILESTONE("M00_MAIN_ENTER");
    log_pid("SELF", self);
    log_psn("PSEUDO", &pseudo);

    MILESTONE("M01_BEFORE_GetProcessPID_PSEUDO");
    status = GetProcessPID(&pseudo, &roundtrip);
    log_status("GetProcessPID_PSEUDO", status);
    MILESTONE("M02_AFTER_GetProcessPID_PSEUDO");
    if (status == noErr) {
        log_pid("PSEUDO_ROUNDTRIP", roundtrip);
        active = &pseudo;
    }

    MILESTONE("M03_BEFORE_GetProcessForPID");
    status = GetProcessForPID(self, &resolved);
    log_status("GetProcessForPID", status);
    MILESTONE("M04_AFTER_GetProcessForPID");
    if (status == noErr) {
        log_psn("RESOLVED", &resolved);
        active = &resolved;
    }

    if (active == NULL) {
        append_line("PM_ALT_FAILURE:NO_USABLE_PSN\n");
        return 31;
    }

    roundtrip = -1;
    MILESTONE("M05_BEFORE_GetProcessPID_ACTIVE");
    status = GetProcessPID(active, &roundtrip);
    log_status("GetProcessPID_ACTIVE", status);
    MILESTONE("M06_AFTER_GetProcessPID_ACTIVE");
    if (status != noErr) {
        append_line("PM_ALT_FAILURE:ACTIVE_PSN_PID_LOOKUP\n");
        return 32;
    }
    log_pid("ACTIVE_ROUNDTRIP", roundtrip);

    if (roundtrip != self) {
        append_line("PM_ALT_FAILURE:PID_ROUNDTRIP_MISMATCH\n");
        return 33;
    }

    MILESTONE("M07_BEFORE_TransformProcessType");
    status = TransformProcessType(active, kProcessTransformToForegroundApplication);
    log_status("TransformProcessType", status);
    MILESTONE("M08_AFTER_TransformProcessType");
    if (status != noErr)
        return 34;

    MILESTONE("M09_BEFORE_SetFrontProcess");
    status = SetFrontProcess(active);
    log_status("SetFrontProcess", status);
    MILESTONE("M10_AFTER_SetFrontProcess");
    if (status != noErr)
        return 35;

    attributes = kWindowStandardDocumentAttributes | kWindowStandardHandlerAttribute;

    MILESTONE("M11_BEFORE_CreateNewWindow");
    status = CreateNewWindow(kDocumentWindowClass, attributes, &bounds, &window);
    log_status("CreateNewWindow", status);
    MILESTONE("M12_AFTER_CreateNewWindow");
    if (status != noErr || window == NULL)
        return 36;

    title = CFStringCreateWithCString(NULL,
                                      "Rosetta PPC Process Manager Alternate",
                                      kCFStringEncodingUTF8);
    if (title == NULL)
        return 37;

    status = SetWindowTitleWithCFString(window, title);
    if (status != noErr)
        return 38;

    MILESTONE("M13_BEFORE_ShowWindow");
    ShowWindow(window);
    MILESTONE("M14_AFTER_ShowWindow");

    timerUPP = NewEventLoopTimerUPP(QuitTimer);
    if (timerUPP == NULL)
        return 39;

    MILESTONE("M15_BEFORE_InstallEventLoopTimer");
    status = InstallEventLoopTimer(GetMainEventLoop(),
                                   2.0 * kEventDurationSecond,
                                   0.0,
                                   timerUPP,
                                   &gTimerFired,
                                   &timer);
    log_status("InstallEventLoopTimer", status);
    MILESTONE("M16_AFTER_InstallEventLoopTimer");
    if (status != noErr)
        return 40;

    MILESTONE("M17_BEFORE_RunApplicationEventLoop");
    RunApplicationEventLoop();
    MILESTONE("M18_AFTER_RunApplicationEventLoop");

    RemoveEventLoopTimer(timer);
    DisposeEventLoopTimerUPP(timerUPP);
    CFRelease(title);
    DisposeWindow(window);

    if (!gTimerFired) {
        append_line("PM_ALT_FAILURE:TIMER_NOT_FIRED\n");
        return 41;
    }

    MILESTONE("M19_SUCCESS");
    return 0;
}
