#include <Carbon/Carbon.h>
#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>

static Boolean gTimerFired = false;

static pascal void
QuitTimer(EventLoopTimerRef timer, void *userData)
{
    Boolean *fired = (Boolean *)userData;
    (void)timer;
    *fired = true;
    QuitApplicationEventLoop();
}

static int
fail_status(const char *operation, OSStatus status)
{
    fprintf(stderr, "Carbon GUI probe: %s failed (OSStatus=%ld)\n",
            operation, (long)status);
    return 1;
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

    status = GetCurrentProcess(&psn);
    if (status != noErr)
        return fail_status("GetCurrentProcess", status);

    status = TransformProcessType(&psn, kProcessTransformToForegroundApplication);
    if (status != noErr)
        return fail_status("TransformProcessType", status);

    status = SetFrontProcess(&psn);
    if (status != noErr)
        return fail_status("SetFrontProcess", status);

    attributes = kWindowStandardDocumentAttributes | kWindowStandardHandlerAttribute;
    status = CreateNewWindow(kDocumentWindowClass, attributes, &bounds, &window);
    if (status != noErr || window == NULL)
        return fail_status("CreateNewWindow", status);

    title = CFStringCreateWithCString(NULL,
                                      "Rosetta PPC Carbon GUI",
                                      kCFStringEncodingUTF8);
    if (title == NULL) {
        DisposeWindow(window);
        fprintf(stderr, "Carbon GUI probe: title allocation failed\n");
        return 2;
    }

    status = SetWindowTitleWithCFString(window, title);
    if (status != noErr) {
        CFRelease(title);
        DisposeWindow(window);
        return fail_status("SetWindowTitleWithCFString", status);
    }

    ShowWindow(window);
    SelectWindow(window);
    visible = IsWindowVisible(window);
    if (!visible) {
        CFRelease(title);
        DisposeWindow(window);
        fprintf(stderr, "Carbon GUI probe: window did not become visible\n");
        return 3;
    }

    timerUPP = NewEventLoopTimerUPP(QuitTimer);
    if (timerUPP == NULL) {
        CFRelease(title);
        DisposeWindow(window);
        fprintf(stderr, "Carbon GUI probe: NewEventLoopTimerUPP failed\n");
        return 4;
    }

    status = InstallEventLoopTimer(GetMainEventLoop(),
                                   2.0 * kEventDurationSecond,
                                   0.0,
                                   timerUPP,
                                   &gTimerFired,
                                   &timer);
    if (status != noErr) {
        DisposeEventLoopTimerUPP(timerUPP);
        CFRelease(title);
        DisposeWindow(window);
        return fail_status("InstallEventLoopTimer", status);
    }

    printf("Rosetta PPC Carbon GUI window shown: pid=%ld visible=1\n",
           (long)getpid());
    fflush(stdout);

    RunApplicationEventLoop();

    RemoveEventLoopTimer(timer);
    DisposeEventLoopTimerUPP(timerUPP);
    CFRelease(title);
    DisposeWindow(window);

    if (!gTimerFired) {
        fprintf(stderr, "Carbon GUI probe: event loop returned before timer fired\n");
        return 5;
    }

    printf("Rosetta PPC Carbon GUI smoke test: pid=%ld timer=1\n",
           (long)getpid());
    return 0;
}
