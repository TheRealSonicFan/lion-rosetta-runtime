#include <CoreFoundation/CoreFoundation.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <unistd.h>

#define BUILD_ID "distributed-notifications-ppc-ingress-probe-v1"
#define BUILD_MARKER \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_PROBE_BUILD_ID:" BUILD_ID
#define PROOF_PREFIX "com.openai.rosetta.distnotify.ppcingress."
#define PROOF_TIMEOUT_SECONDS 10.0

typedef struct ProbeState {
    CFStringRef expected_name;
    CFStringRef expected_object;
    CFStringRef expected_nonce;
    volatile int callback_count;
    volatile int callback_valid;
} ProbeState;

static void
proof_callback(CFNotificationCenterRef center,
               void *observer,
               CFStringRef name,
               const void *object,
               CFDictionaryRef userInfo)
{
    ProbeState *state = (ProbeState *)observer;
    CFTypeRef nonce = NULL;
    int ok = 1;

    (void)center;

    if (state == NULL)
        return;

    state->callback_count += 1;

    ok = ok && name != NULL && CFEqual(name, state->expected_name);
    ok = ok && object != NULL &&
         CFEqual((CFTypeRef)object, state->expected_object);
    ok = ok && userInfo != NULL &&
         CFGetTypeID(userInfo) == CFDictionaryGetTypeID();

    if (userInfo != NULL)
        nonce = CFDictionaryGetValue(userInfo, CFSTR("proof_nonce"));
    ok = ok && nonce != NULL &&
         CFGetTypeID(nonce) == CFStringGetTypeID() &&
         CFEqual(nonce, state->expected_nonce);

    state->callback_valid = ok ? 1 : 0;

    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_CALLBACK:index=%d valid=%s\n",
            state->callback_count,
            ok ? "YES" : "NO");
    fflush(stderr);
}

static CFStringRef
string_from_utf8(const char *value)
{
    return CFStringCreateWithCString(
        kCFAllocatorDefault, value, kCFStringEncodingUTF8);
}

int
main(void)
{
    CFNotificationCenterRef center;
    CFMutableDictionaryRef userInfo = NULL;
    CFStringRef name = NULL;
    CFStringRef object = NULL;
    CFStringRef nonce = NULL;
    ProbeState state;
    CFAbsoluteTime deadline;
    char name_buffer[256];
    char nonce_buffer[128];

    fprintf(stderr, "%s\n", BUILD_MARKER);
    fflush(stderr);

    state.expected_name = NULL;
    state.expected_object = NULL;
    state.expected_nonce = NULL;
    state.callback_count = 0;
    state.callback_valid = 0;

    snprintf(name_buffer, sizeof(name_buffer),
             PROOF_PREFIX "%ld", (long)getpid());
    snprintf(nonce_buffer, sizeof(nonce_buffer),
             "ppc-ingress-nonce-%ld", (long)getpid());

    name = string_from_utf8(name_buffer);
    object = CFStringCreateCopy(
        kCFAllocatorDefault, CFSTR("ppc-ingress-proof-object"));
    nonce = string_from_utf8(nonce_buffer);
    if (name == NULL || object == NULL || nonce == NULL) {
        fprintf(stderr,
                "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_RESULT:SETUP_FAILED\n");
        goto fail;
    }

    userInfo = CFDictionaryCreateMutable(
        kCFAllocatorDefault,
        0,
        &kCFTypeDictionaryKeyCallBacks,
        &kCFTypeDictionaryValueCallBacks);
    if (userInfo == NULL)
        goto fail;
    CFDictionarySetValue(userInfo, CFSTR("proof_nonce"), nonce);

    state.expected_name = name;
    state.expected_object = object;
    state.expected_nonce = nonce;

    center = CFNotificationCenterGetDistributedCenter();
    if (center == NULL) {
        fprintf(stderr,
                "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_RESULT:NO_CENTER\n");
        goto fail;
    }

    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_REGISTER:behavior=%ld\n",
            (long)CFNotificationSuspensionBehaviorDeliverImmediately);
    fflush(stderr);

    CFNotificationCenterAddObserver(
        center,
        &state,
        proof_callback,
        name,
        object,
        CFNotificationSuspensionBehaviorDeliverImmediately);

    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.25, false);
    usleep(50000);

    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_POST:options=0x%lx\n",
            (unsigned long)kCFNotificationDeliverImmediately);
    fflush(stderr);

    CFNotificationCenterPostNotificationWithOptions(
        center,
        name,
        object,
        userInfo,
        kCFNotificationDeliverImmediately);

    deadline = CFAbsoluteTimeGetCurrent() + PROOF_TIMEOUT_SECONDS;
    while (state.callback_count == 0 &&
           CFAbsoluteTimeGetCurrent() < deadline) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.10, true);
        usleep(10000);
    }

    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_CALLBACK_SUMMARY:count=%d valid=%s\n",
            state.callback_count,
            state.callback_valid ? "YES" : "NO");
    fflush(stderr);

    CFNotificationCenterRemoveObserver(
        center, &state, name, object);
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.25, false);
    usleep(50000);

    if (state.callback_count != 1 || !state.callback_valid)
        goto fail;

    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_RESULT:PASS\n");
    fflush(stderr);

    if (userInfo != NULL) CFRelease(userInfo);
    if (nonce != NULL) CFRelease(nonce);
    if (object != NULL) CFRelease(object);
    if (name != NULL) CFRelease(name);
    return 0;

fail:
    if (userInfo != NULL) CFRelease(userInfo);
    if (nonce != NULL) CFRelease(nonce);
    if (object != NULL) CFRelease(object);
    if (name != NULL) CFRelease(name);
    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_RESULT:FAIL\n");
    fflush(stderr);
    return 1;
}
