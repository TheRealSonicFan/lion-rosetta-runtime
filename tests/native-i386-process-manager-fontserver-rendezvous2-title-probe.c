#include <Carbon/Carbon.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>

#define PROBE_BUILD_ID "native-i386-fontserver-rendezvous2-title-probe-v1"
#define PROBE_BUILD_MARKER "PM_NATIVE_FONTSERVER_RENDEZVOUS2_PROBE_BUILD_ID:" PROBE_BUILD_ID

int
main(void)
{
    Rect bounds;
    WindowRef window = NULL;
    CFStringRef title = NULL;
    OSStatus status;

    fprintf(stderr, "%s\n", PROBE_BUILD_MARKER);
    fflush(stderr);

    bounds.top = 80;
    bounds.left = 80;
    bounds.bottom = 280;
    bounds.right = 480;

    status = CreateNewWindow(kDocumentWindowClass,
                             kWindowStandardDocumentAttributes,
                             &bounds,
                             &window);
    fprintf(stderr,
            "PM_NATIVE_FONTSERVER_RENDEZVOUS2_PROBE_CREATEWINDOW:status=%ld window=%p\n",
            (long)status, window);
    fflush(stderr);
    if (status != noErr || window == NULL)
        return 71;

    title = CFStringCreateWithCString(kCFAllocatorDefault,
                                      "Rosetta Lion native FontServer Rendezvous2 trace",
                                      kCFStringEncodingUTF8);
    fprintf(stderr,
            "PM_NATIVE_FONTSERVER_RENDEZVOUS2_PROBE_TITLE_CREATE:result=%s\n",
            title != NULL ? "PASS" : "FAIL");
    fflush(stderr);
    if (title == NULL) {
        DisposeWindow(window);
        return 72;
    }

    fprintf(stderr,
            "PM_NATIVE_FONTSERVER_RENDEZVOUS2_PROBE_BEFORE_SETWINDOWTITLE\n");
    fflush(stderr);

    status = SetWindowTitleWithCFString(window, title);

    fprintf(stderr,
            "PM_NATIVE_FONTSERVER_RENDEZVOUS2_PROBE_UNEXPECTED_RETURN:status=%ld\n",
            (long)status);
    fflush(stderr);

    CFRelease(title);
    DisposeWindow(window);
    return 73;
}
