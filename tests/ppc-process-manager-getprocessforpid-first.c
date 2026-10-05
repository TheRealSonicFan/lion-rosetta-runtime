#include <Carbon/Carbon.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

#define MILESTONE_LOG_PATH "/tmp/rosetta-processmanager-pidfirst-milestone.log"

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

#define MILESTONE(name) append_line("PM_PIDFIRST_MILESTONE:" name "\n")

static void
log_status(const char *name, OSStatus status)
{
    char line[256];
    snprintf(line, sizeof(line), "PM_PIDFIRST_STATUS:%s=%ld\n", name, (long)status);
    append_line(line);
}

static void
log_psn(const char *name, const ProcessSerialNumber *psn)
{
    char line[256];
    snprintf(line, sizeof(line),
             "PM_PIDFIRST_PSN:%s=0x%08lx:0x%08lx\n",
             name,
             (unsigned long)psn->highLongOfPSN,
             (unsigned long)psn->lowLongOfPSN);
    append_line(line);
}

static void
log_pid(const char *name, pid_t pid)
{
    char line[256];
    snprintf(line, sizeof(line), "PM_PIDFIRST_PID:%s=%ld\n", name, (long)pid);
    append_line(line);
}

static pascal void
QuitTimer(EventLoopTimerRef timer, void *userData)
{
    Boolean *fired = (Boolean *)userData;
    (void)timer;

    MILESTONE("M17_TIMER_CALLBACK_ENTER");
    *fired = true;
    QuitApplicationEventLoop();
    MILESTONE("M18_TIMER_CALLBACK_EXIT");
}

int
main(void)
{
    ProcessSerialNumber resolved = { 0, 0 };
    pid_t self = getpid();
    WindowRef window = NULL;
    EventLoopTimerRef timer = NULL;
    EventLoopTimerUPP timerUPP = NULL;
    CFStringRef title = NULL;
    Rect bounds = { 140, 140, 340, 560 };
    WindowAttributes attributes;
    OSStatus status;

    MILESTONE("M00_MAIN_ENTER");
    log_pid("SELF", self);

    MILESTONE("M01_BEFORE_GetProcessForPID");
    status = GetProcessForPID(self, &resolved);
    log_status("GetProcessForPID", status);
    MILESTONE("M02_AFTER_GetProcessForPID");
    if (status != noErr) {
        append_line("PM_PIDFIRST_FAILURE:GetProcessForPID\n");
        return 31;
    }

    log_psn("RESOLVED", &resolved);

    MILESTONE("M03_BEFORE_TransformProcessType");
    status = TransformProcessType(&resolved, kProcessTransformToForegroundApplication);
    log_status("TransformProcessType", status);
    MILESTONE("M04_AFTER_TransformProcessType");
    if (status != noErr)
        return 32;

    MILESTONE("M05_BEFORE_SetFrontProcess");
    status = SetFrontProcess(&resolved);
    log_status("SetFrontProcess", status);
    MILESTONE("M06_AFTER_SetFrontProcess");
    if (status != noErr)
        return 33;

    attributes = kWindowStandardDocumentAttributes | kWindowStandardHandlerAttribute;

    MILESTONE("M07_BEFORE_CreateNewWindow");
    status = CreateNewWindow(kDocumentWindowClass, attributes, &bounds, &window);
    log_status("CreateNewWindow", status);
    MILESTONE("M08_AFTER_CreateNewWindow");
    if (status != noErr || window == NULL)
        return 34;

    title = CFStringCreateWithCString(NULL,
                                      "Rosetta PPC GetProcessForPID First",
                                      kCFStringEncodingUTF8);
    if (title == NULL)
        return 35;

    status = SetWindowTitleWithCFString(window, title);
    log_status("SetWindowTitleWithCFString", status);
    if (status != noErr)
        return 36;

    MILESTONE("M09_BEFORE_ShowWindow");
    ShowWindow(window);
    MILESTONE("M10_AFTER_ShowWindow");

    timerUPP = NewEventLoopTimerUPP(QuitTimer);
    if (timerUPP == NULL)
        return 37;

    MILESTONE("M11_BEFORE_InstallEventLoopTimer");
    status = InstallEventLoopTimer(GetMainEventLoop(),
                                   2.0 * kEventDurationSecond,
                                   0.0,
                                   timerUPP,
                                   &gTimerFired,
                                   &timer);
    log_status("InstallEventLoopTimer", status);
    MILESTONE("M12_AFTER_InstallEventLoopTimer");
    if (status != noErr)
        return 38;

    MILESTONE("M13_BEFORE_RunApplicationEventLoop");
    RunApplicationEventLoop();
    MILESTONE("M14_AFTER_RunApplicationEventLoop");

    RemoveEventLoopTimer(timer);
    DisposeEventLoopTimerUPP(timerUPP);
    CFRelease(title);
    DisposeWindow(window);

    if (!gTimerFired) {
        append_line("PM_PIDFIRST_FAILURE:TIMER_NOT_FIRED\n");
        return 39;
    }

    MILESTONE("M15_SUCCESS");
    return 0;
}
