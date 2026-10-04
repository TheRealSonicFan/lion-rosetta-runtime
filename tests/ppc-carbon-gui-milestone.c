#include <Carbon/Carbon.h>
#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>

static Boolean gTimerFired = false;

#define MILESTONE(name) do { \
    static const char marker[] = "CARBON_MILESTONE:" name "\n"; \
    (void)write(STDERR_FILENO, marker, sizeof(marker) - 1); \
} while (0)

static pascal void
QuitTimer(EventLoopTimerRef timer, void *userData)
{
    Boolean *fired = (Boolean *)userData;
    (void)timer;

    MILESTONE("M23_TIMER_CALLBACK_ENTER");
    *fired = true;
    QuitApplicationEventLoop();
    MILESTONE("M24_TIMER_CALLBACK_EXIT");
}

static int
fail_status(const char *operation, OSStatus status, int code)
{
    fprintf(stderr, "Carbon milestone probe: %s failed (OSStatus=%ld)\n",
            operation, (long)status);
    return code;
}

int
main(void)
{
    ProcessSerialNumber psn;
    WindowRef window = NULL;
    EventLoopTimerRef timer = NULL;
    EventLoopTimerUPP timerUPP = NULL;
    CFStringRef title = NULL;
    Rect bounds = { 120, 120, 320, 520 };
    WindowAttributes attributes;
    OSStatus status;
    Boolean visible;

    MILESTONE("M00_MAIN_ENTER");

    MILESTONE("M01_BEFORE_GetCurrentProcess");
    status = GetCurrentProcess(&psn);
    MILESTONE("M02_AFTER_GetCurrentProcess");
    if (status != noErr)
        return fail_status("GetCurrentProcess", status, 11);

    MILESTONE("M03_BEFORE_TransformProcessType");
    status = TransformProcessType(&psn, kProcessTransformToForegroundApplication);
    MILESTONE("M04_AFTER_TransformProcessType");
    if (status != noErr)
        return fail_status("TransformProcessType", status, 12);

    MILESTONE("M05_BEFORE_SetFrontProcess");
    status = SetFrontProcess(&psn);
    MILESTONE("M06_AFTER_SetFrontProcess");
    if (status != noErr)
        return fail_status("SetFrontProcess", status, 13);

    attributes = kWindowStandardDocumentAttributes | kWindowStandardHandlerAttribute;

    MILESTONE("M07_BEFORE_CreateNewWindow");
    status = CreateNewWindow(kDocumentWindowClass, attributes, &bounds, &window);
    MILESTONE("M08_AFTER_CreateNewWindow");
    if (status != noErr || window == NULL)
        return fail_status("CreateNewWindow", status, 14);

    MILESTONE("M09_BEFORE_CFStringCreateWithCString");
    title = CFStringCreateWithCString(NULL,
                                      "Rosetta PPC Carbon Milestone",
                                      kCFStringEncodingUTF8);
    MILESTONE("M10_AFTER_CFStringCreateWithCString");
    if (title == NULL) {
        DisposeWindow(window);
        fprintf(stderr, "Carbon milestone probe: title allocation failed\n");
        return 15;
    }

    MILESTONE("M11_BEFORE_SetWindowTitleWithCFString");
    status = SetWindowTitleWithCFString(window, title);
    MILESTONE("M12_AFTER_SetWindowTitleWithCFString");
    if (status != noErr) {
        CFRelease(title);
        DisposeWindow(window);
        return fail_status("SetWindowTitleWithCFString", status, 16);
    }

    MILESTONE("M13_BEFORE_ShowWindow");
    ShowWindow(window);
    MILESTONE("M14_AFTER_ShowWindow");

    MILESTONE("M15_BEFORE_SelectWindow");
    SelectWindow(window);
    MILESTONE("M16_AFTER_SelectWindow");

    MILESTONE("M17_BEFORE_IsWindowVisible");
    visible = IsWindowVisible(window);
    MILESTONE("M18_AFTER_IsWindowVisible");
    if (!visible) {
        CFRelease(title);
        DisposeWindow(window);
        fprintf(stderr, "Carbon milestone probe: window did not become visible\n");
        return 17;
    }

    MILESTONE("M19_BEFORE_NewEventLoopTimerUPP");
    timerUPP = NewEventLoopTimerUPP(QuitTimer);
    MILESTONE("M20_AFTER_NewEventLoopTimerUPP");
    if (timerUPP == NULL) {
        CFRelease(title);
        DisposeWindow(window);
        fprintf(stderr, "Carbon milestone probe: NewEventLoopTimerUPP failed\n");
        return 18;
    }

    MILESTONE("M21_BEFORE_InstallEventLoopTimer");
    status = InstallEventLoopTimer(GetMainEventLoop(),
                                   2.0 * kEventDurationSecond,
                                   0.0,
                                   timerUPP,
                                   &gTimerFired,
                                   &timer);
    MILESTONE("M22_AFTER_InstallEventLoopTimer");
    if (status != noErr) {
        DisposeEventLoopTimerUPP(timerUPP);
        CFRelease(title);
        DisposeWindow(window);
        return fail_status("InstallEventLoopTimer", status, 19);
    }

    MILESTONE("M25_BEFORE_RunApplicationEventLoop");
    RunApplicationEventLoop();
    MILESTONE("M26_AFTER_RunApplicationEventLoop");

    RemoveEventLoopTimer(timer);
    DisposeEventLoopTimerUPP(timerUPP);
    CFRelease(title);
    DisposeWindow(window);

    if (!gTimerFired) {
        fprintf(stderr, "Carbon milestone probe: event loop returned before timer fired\n");
        return 20;
    }

    MILESTONE("M27_SUCCESS");
    return 0;
}
