#include <CoreFoundation/CoreFoundation.h>
#include <arpa/inet.h>
#include <errno.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <sys/types.h>
#include <unistd.h>

#define BUILD_ID "distributed-notifications-runapplicationeventloop-tenth-registration-broker-v1"
#define BUILD_MARKER \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_BUILD_ID:" BUILD_ID
#define SIXTH_POLICY_MARKER \
    "PM_DISTRIBUTED_NOTIFICATIONS_SHOWWINDOW_SIXTH_REGISTRATION_POLICY:index=6 allowed=3 counter=2"
#define SEVENTH_POLICY_MARKER \
    "PM_DISTRIBUTED_NOTIFICATIONS_SHOWWINDOW_SEVENTH_REGISTRATION_POLICY:index=7 allowed=5 counter=1"
#define EIGHTH_POLICY_MARKER \
    "PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_POLICY:index=8 allowed=6 counter=1"
#define NINTH_POLICY_MARKER \
    "PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_POLICY:index=9 allowed=7 counter=1"
#define TENTH_POLICY_MARKER \
    "PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_POLICY:index=10 allowed=8 counter=1"

#define FRAME_MAGIC 0x44504e31U
#define FRAME_VERSION 1U
#define FRAME_REQUEST 1U
#define FRAME_CALLBACK 2U
#define FRAME_MAX_PAYLOAD (256U * 1024U)
#define MAX_REGISTRATIONS 10U
#define EXPECTED_CLIENT \
    "ppc-process-manager-cgs-session-bootstrap-integration-private-dyld"
#define ANY_OBJECT_SENTINEL "kCFNotificationAnyObject"

enum {
    BROKER_OK = 0,
    BROKER_REJECT_SCHEMA = 20,
    BROKER_REJECT_OPERATION = 21,
    BROKER_REJECT_BEHAVIOR = 22,
    BROKER_REJECT_SCOPE = 24,
    BROKER_REJECT_NAME = 25,
    BROKER_REJECT_STATE = 26
};

typedef struct FrameHeader {
    uint32_t magic;
    uint32_t version;
    uint32_t type;
    uint32_t length;
} FrameHeader;

typedef struct AllowedRegistration {
    const char *name;
    const char *object;
    int any_object;
    int32_t behavior;
} AllowedRegistration;

typedef struct BrokerRegistration {
    int active;
    int allowed_index;
    int any_object;
    CFNotificationCenterRef center;
    CFStringRef name;
    CFStringRef object;
    CFStringRef sessionid;
    int64_t entry;
    int32_t counter;
    int callback_count;
} BrokerRegistration;

static const AllowedRegistration kAllowed[] = {
    {
        "com.apple.MCX._managementStatusChangedForDomains",
        "com.apple.MCX",
        0,
        1
    },
    {
        "com.apple.CFPreferences._domainsChangedExternally",
        "com.apple.CFPreferences",
        0,
        1
    },
    {
        "AppleColorPreferencesChangedNotification",
        ANY_OBJECT_SENTINEL,
        1,
        4
    },
    {
        "AppleAquaColorVariantChanged",
        ANY_OBJECT_SENTINEL,
        1,
        4
    },
    {
        "com_apple_CoreText_FontManagerChangedNotification",
        ANY_OBJECT_SENTINEL,
        1,
        1
    },
    {
        "com.apple.ColorSync.DisplayProfileNotification",
        ANY_OBJECT_SENTINEL,
        1,
        4
    },
    {
        "AppleDatePreferencesChangedNotification",
        ANY_OBJECT_SENTINEL,
        1,
        4
    },
    {
        "AppleTimePreferencesChangedNotification",
        ANY_OBJECT_SENTINEL,
        1,
        4
    },
    {
        "AppleNumberPreferencesChangedNotification",
        ANY_OBJECT_SENTINEL,
        1,
        4
    }
};

static const int kExpectedAllowedIndex[] = { 0, 1, 2, 3, 4, 3, 5, 6, 7, 8 };
static const int32_t kExpectedCounter[] = { 1, 1, 1, 1, 1, 2, 1, 1, 1, 1 };

static int gIpcFd = -1;
static BrokerRegistration gRegistrations[MAX_REGISTRATIONS];
static CFStringRef gSessionId = NULL;
static unsigned int gRegisterCount = 0;
static unsigned int gCallbackCount = 0;
static unsigned int gRejectCount = 0;
static unsigned int gAllowedSeen[sizeof(kAllowed) / sizeof(kAllowed[0])];
static pthread_mutex_t gLock = PTHREAD_MUTEX_INITIALIZER;

static int
write_full(int fd, const void *buffer, size_t length)
{
    const unsigned char *p = (const unsigned char *)buffer;

    while (length > 0) {
        ssize_t n = write(fd, p, length);
        if (n < 0) {
            if (errno == EINTR)
                continue;
            return 0;
        }
        if (n == 0)
            return 0;
        p += n;
        length -= (size_t)n;
    }
    return 1;
}

static int
read_full(int fd, void *buffer, size_t length)
{
    unsigned char *p = (unsigned char *)buffer;

    while (length > 0) {
        ssize_t n = read(fd, p, length);
        if (n < 0) {
            if (errno == EINTR)
                continue;
            return 0;
        }
        if (n == 0)
            return 0;
        p += n;
        length -= (size_t)n;
    }
    return 1;
}

static int
send_frame(uint32_t type, const void *payload, uint32_t length)
{
    FrameHeader header;

    if (gIpcFd < 0 || payload == NULL || length == 0 ||
        length > FRAME_MAX_PAYLOAD)
        return 0;

    header.magic = htonl(FRAME_MAGIC);
    header.version = htonl(FRAME_VERSION);
    header.type = htonl(type);
    header.length = htonl(length);

    return write_full(gIpcFd, &header, sizeof(header)) &&
           write_full(gIpcFd, payload, length);
}

static int
cf_string_equals_cstr(CFStringRef value, const char *expected)
{
    CFStringRef want;
    Boolean equal;

    if (value == NULL || expected == NULL ||
        CFGetTypeID(value) != CFStringGetTypeID())
        return 0;

    want = CFStringCreateWithCString(
        kCFAllocatorDefault, expected, kCFStringEncodingUTF8);
    if (want == NULL)
        return 0;
    equal = CFEqual(value, want);
    CFRelease(want);
    return equal ? 1 : 0;
}

static int
get_sint32(CFDictionaryRef dict, CFStringRef key, int32_t *out)
{
    CFTypeRef value = CFDictionaryGetValue(dict, key);
    if (value == NULL || CFGetTypeID(value) != CFNumberGetTypeID())
        return 0;
    return CFNumberGetValue(
        (CFNumberRef)value, kCFNumberSInt32Type, out) ? 1 : 0;
}

static int
get_sint64(CFDictionaryRef dict, CFStringRef key, int64_t *out)
{
    CFTypeRef value = CFDictionaryGetValue(dict, key);
    if (value == NULL || CFGetTypeID(value) != CFNumberGetTypeID())
        return 0;
    return CFNumberGetValue(
        (CFNumberRef)value, kCFNumberSInt64Type, out) ? 1 : 0;
}

static int
legacy_behavior_to_public(int32_t legacy,
                          CFNotificationSuspensionBehavior *out)
{
    switch (legacy) {
        case 1:
            *out = CFNotificationSuspensionBehaviorDeliverImmediately;
            return 1;
        case 2:
            *out = CFNotificationSuspensionBehaviorDrop;
            return 1;
        case 4:
            *out = CFNotificationSuspensionBehaviorCoalesce;
            return 1;
        case 8:
            *out = CFNotificationSuspensionBehaviorHold;
            return 1;
        default:
            return 0;
    }
}

static CFDataRef
serialize_binary_plist(CFPropertyListRef plist)
{
    CFErrorRef error = NULL;
    CFDataRef data;

    data = CFPropertyListCreateData(
        kCFAllocatorDefault,
        plist,
        kCFPropertyListBinaryFormat_v1_0,
        0,
        &error);
    if (error != NULL)
        CFRelease(error);
    return data;
}

static CFPropertyListRef
parse_binary_plist(const unsigned char *bytes, uint32_t length)
{
    CFDataRef data;
    CFPropertyListRef plist;
    CFPropertyListFormat format = kCFPropertyListBinaryFormat_v1_0;
    CFErrorRef error = NULL;

    data = CFDataCreate(kCFAllocatorDefault, bytes, (CFIndex)length);
    if (data == NULL)
        return NULL;

    plist = CFPropertyListCreateWithData(
        kCFAllocatorDefault,
        data,
        kCFPropertyListImmutable,
        &format,
        &error);
    if (error != NULL)
        CFRelease(error);
    CFRelease(data);
    return plist;
}

static int
find_allowed(CFStringRef name, CFStringRef object, int32_t behavior)
{
    size_t i;

    for (i = 0; i < sizeof(kAllowed) / sizeof(kAllowed[0]); ++i) {
        if (!cf_string_equals_cstr(name, kAllowed[i].name))
            continue;
        if (!cf_string_equals_cstr(object, kAllowed[i].object))
            return -1;
        if (behavior != kAllowed[i].behavior)
            return -2;
        return (int)i;
    }
    return -3;
}

static BrokerRegistration *
allocate_registration(void)
{
    unsigned int i;

    for (i = 0; i < MAX_REGISTRATIONS; ++i) {
        if (!gRegistrations[i].active)
            return &gRegistrations[i];
    }
    return NULL;
}

static int
entry_is_active(int64_t entry)
{
    unsigned int i;

    for (i = 0; i < MAX_REGISTRATIONS; ++i) {
        if (gRegistrations[i].active && gRegistrations[i].entry == entry)
            return 1;
    }
    return 0;
}

static void
broker_callback(CFNotificationCenterRef center,
                void *observer,
                CFStringRef name,
                const void *object,
                CFDictionaryRef userInfo)
{
    BrokerRegistration *reg = (BrokerRegistration *)observer;
    CFMutableDictionaryRef dict = NULL;
    CFNumberRef entry_number = NULL;
    CFNumberRef counter_number = NULL;
    CFDataRef encoded = NULL;
    int ok = 1;
    int callback_index;

    (void)center;

    if (reg == NULL)
        return;

    (void)pthread_mutex_lock(&gLock);
    if (!reg->active) {
        (void)pthread_mutex_unlock(&gLock);
        return;
    }

    reg->callback_count += 1;
    gCallbackCount += 1;
    callback_index = reg->callback_count;

    ok = ok && name != NULL && CFEqual(name, reg->name);
    if (!reg->any_object) {
        ok = ok && object != NULL &&
             CFGetTypeID((CFTypeRef)object) == CFStringGetTypeID() &&
             CFEqual((CFTypeRef)object, reg->object);
    } else if (object != NULL) {
        ok = ok && CFGetTypeID((CFTypeRef)object) == CFStringGetTypeID();
    }

    if (userInfo != NULL &&
        CFGetTypeID(userInfo) != CFDictionaryGetTypeID())
        ok = 0;

    dict = CFDictionaryCreateMutable(
        kCFAllocatorDefault,
        0,
        &kCFTypeDictionaryKeyCallBacks,
        &kCFTypeDictionaryValueCallBacks);
    if (dict == NULL) {
        ok = 0;
        goto done;
    }

    entry_number = CFNumberCreate(
        kCFAllocatorDefault, kCFNumberSInt64Type, &reg->entry);
    counter_number = CFNumberCreate(
        kCFAllocatorDefault, kCFNumberSInt32Type, &reg->counter);
    if (entry_number == NULL || counter_number == NULL) {
        ok = 0;
        goto done;
    }

    CFDictionarySetValue(dict, CFSTR("message_type"), CFSTR("post"));
    CFDictionarySetValue(dict, CFSTR("name"), reg->name);
    if (object != NULL &&
        CFGetTypeID((CFTypeRef)object) == CFStringGetTypeID())
        CFDictionarySetValue(dict, CFSTR("object"), (CFTypeRef)object);
    if (userInfo != NULL)
        CFDictionarySetValue(dict, CFSTR("userinfo"), userInfo);
    CFDictionarySetValue(dict, CFSTR("counter"), counter_number);
    CFDictionarySetValue(dict, CFSTR("entry"), entry_number);

    encoded = serialize_binary_plist(dict);
    if (encoded == NULL ||
        CFDataGetLength(encoded) <= 0 ||
        CFDataGetLength(encoded) > (CFIndex)FRAME_MAX_PAYLOAD) {
        ok = 0;
        goto done;
    }

    if (!send_frame(
            FRAME_CALLBACK,
            CFDataGetBytePtr(encoded),
            (uint32_t)CFDataGetLength(encoded)))
        ok = 0;

done:
    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_CALLBACK:allowed=%d index=%d valid=%s entry=0x%llx counter=0x%x\n",
            reg->allowed_index,
            callback_index,
            ok ? "YES" : "NO",
            (unsigned long long)(uint64_t)reg->entry,
            (unsigned int)reg->counter);
    fflush(stderr);

    if (!ok)
        ++gRejectCount;
    if (encoded != NULL) CFRelease(encoded);
    if (counter_number != NULL) CFRelease(counter_number);
    if (entry_number != NULL) CFRelease(entry_number);
    if (dict != NULL) CFRelease(dict);
    (void)pthread_mutex_unlock(&gLock);
}

static int
handle_register(CFDictionaryRef dict)
{
    CFTypeRef client;
    CFTypeRef name;
    CFTypeRef object;
    CFTypeRef sessionid;
    CFNotificationSuspensionBehavior public_behavior;
    BrokerRegistration *reg;
    int32_t behavior;
    int32_t counter;
    int64_t entry;
    int allowed_index;

    if (CFDictionaryGetCount(dict) != 8)
        return BROKER_REJECT_SCHEMA;

    client = CFDictionaryGetValue(dict, CFSTR("client"));
    name = CFDictionaryGetValue(dict, CFSTR("name"));
    object = CFDictionaryGetValue(dict, CFSTR("object"));
    sessionid = CFDictionaryGetValue(dict, CFSTR("sessionid"));

    if (!cf_string_equals_cstr((CFStringRef)client, EXPECTED_CLIENT) ||
        name == NULL || CFGetTypeID(name) != CFStringGetTypeID() ||
        object == NULL || CFGetTypeID(object) != CFStringGetTypeID() ||
        sessionid == NULL || CFGetTypeID(sessionid) != CFStringGetTypeID() ||
        CFStringGetLength((CFStringRef)sessionid) == 0 ||
        !get_sint32(dict, CFSTR("behavior"), &behavior) ||
        !get_sint32(dict, CFSTR("counter"), &counter) ||
        !get_sint64(dict, CFSTR("entry"), &entry) ||
        counter <= 0 || entry <= 0)
        return BROKER_REJECT_SCHEMA;

    allowed_index = find_allowed(
        (CFStringRef)name, (CFStringRef)object, behavior);
    if (allowed_index == -2)
        return BROKER_REJECT_BEHAVIOR;
    if (allowed_index == -3)
        return BROKER_REJECT_NAME;
    if (allowed_index < 0)
        return BROKER_REJECT_SCHEMA;

    if (gRegisterCount >=
            sizeof(kExpectedAllowedIndex) / sizeof(kExpectedAllowedIndex[0]))
        return BROKER_REJECT_STATE;
    if (allowed_index != kExpectedAllowedIndex[gRegisterCount])
        return BROKER_REJECT_STATE;
    if (counter != kExpectedCounter[gRegisterCount])
        return BROKER_REJECT_SCHEMA;

    if (!legacy_behavior_to_public(behavior, &public_behavior))
        return BROKER_REJECT_BEHAVIOR;

    (void)pthread_mutex_lock(&gLock);

    if (entry_is_active(entry)) {
        (void)pthread_mutex_unlock(&gLock);
        return BROKER_REJECT_STATE;
    }

    if (gSessionId == NULL) {
        gSessionId = CFRetain((CFStringRef)sessionid);
    } else if (!CFEqual(gSessionId, sessionid)) {
        (void)pthread_mutex_unlock(&gLock);
        return BROKER_REJECT_SCOPE;
    }

    reg = allocate_registration();
    if (reg == NULL) {
        (void)pthread_mutex_unlock(&gLock);
        return BROKER_REJECT_STATE;
    }

    memset(reg, 0, sizeof(*reg));
    reg->allowed_index = allowed_index;
    reg->any_object = kAllowed[allowed_index].any_object;
    reg->center = CFNotificationCenterGetDistributedCenter();
    if (reg->center == NULL) {
        (void)pthread_mutex_unlock(&gLock);
        return BROKER_REJECT_STATE;
    }

    reg->name = CFRetain((CFStringRef)name);
    reg->object = reg->any_object ? NULL : CFRetain((CFStringRef)object);
    reg->sessionid = CFRetain((CFStringRef)sessionid);
    reg->entry = entry;
    reg->counter = counter;
    reg->active = 1;

    CFNotificationCenterAddObserver(
        reg->center,
        reg,
        broker_callback,
        reg->name,
        reg->object,
        public_behavior);

    gAllowedSeen[allowed_index] += 1U;
    ++gRegisterCount;

    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:index=%u allowed=%d behavior=%d publicBehavior=%ld anyObject=%s entry=0x%llx counter=0x%x\n",
            gRegisterCount,
            allowed_index,
            behavior,
            (long)public_behavior,
            reg->any_object ? "YES" : "NO",
            (unsigned long long)(uint64_t)entry,
            (unsigned int)counter);
    fflush(stderr);

    (void)pthread_mutex_unlock(&gLock);
    return BROKER_OK;
}

static int
handle_request(CFDictionaryRef dict)
{
    CFTypeRef operation;

    operation = CFDictionaryGetValue(dict, CFSTR("message_type"));
    if (operation == NULL || CFGetTypeID(operation) != CFStringGetTypeID())
        return BROKER_REJECT_SCHEMA;

    if (CFEqual(operation, CFSTR("register")))
        return handle_register(dict);

    return BROKER_REJECT_OPERATION;
}

static int
process_request_bytes(const unsigned char *bytes, uint32_t length)
{
    CFPropertyListRef plist;
    int status;

    plist = parse_binary_plist(bytes, length);
    if (plist == NULL) {
        fprintf(stderr,
                "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_REQUEST:parse=FAIL length=%u\n",
                length);
        fflush(stderr);
        return BROKER_REJECT_SCHEMA;
    }

    if (CFGetTypeID(plist) != CFDictionaryGetTypeID()) {
        CFRelease(plist);
        return BROKER_REJECT_SCHEMA;
    }

    status = handle_request((CFDictionaryRef)plist);
    if (status != BROKER_OK)
        ++gRejectCount;

    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_REQUEST:length=%u status=%d createwindowRegister=YES\n",
            length,
            status);
    fflush(stderr);

    CFRelease(plist);
    return status;
}

static int
read_one_frame(int fd)
{
    FrameHeader header;
    uint32_t magic;
    uint32_t version;
    uint32_t type;
    uint32_t length;
    unsigned char *payload;
    int status;

    if (!read_full(fd, &header, sizeof(header)))
        return 0;

    magic = ntohl(header.magic);
    version = ntohl(header.version);
    type = ntohl(header.type);
    length = ntohl(header.length);

    if (magic != FRAME_MAGIC ||
        version != FRAME_VERSION ||
        type != FRAME_REQUEST ||
        length == 0 ||
        length > FRAME_MAX_PAYLOAD) {
        fprintf(stderr,
                "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_FRAME:REJECT magic=0x%08x version=%u type=%u length=%u\n",
                magic, version, type, length);
        fflush(stderr);
        return -1;
    }

    payload = (unsigned char *)malloc(length);
    if (payload == NULL)
        return -1;
    if (!read_full(fd, payload, length)) {
        free(payload);
        return 0;
    }

    status = process_request_bytes(payload, length);
    free(payload);

    if (status != BROKER_OK) {
        fprintf(stderr,
                "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_REJECT:status=%d createwindowRegister=YES\n",
                status);
        fflush(stderr);
    }

    return 1;
}

static int
parse_fd(const char *text)
{
    char *end = NULL;
    long value;

    if (text == NULL || *text == '\0')
        return -1;
    errno = 0;
    value = strtol(text, &end, 10);
    if (errno != 0 || end == text || *end != '\0' ||
        value < 0 || value > 65535)
        return -1;
    return (int)value;
}

static void
release_registrations(void)
{
    unsigned int i;

    (void)pthread_mutex_lock(&gLock);
    for (i = 0; i < MAX_REGISTRATIONS; ++i) {
        BrokerRegistration *reg = &gRegistrations[i];
        if (!reg->active)
            continue;

        CFNotificationCenterRemoveObserver(
            reg->center,
            reg,
            reg->name,
            reg->object);

        if (reg->object != NULL)
            CFRelease(reg->object);
        if (reg->name != NULL)
            CFRelease(reg->name);
        if (reg->sessionid != NULL)
            CFRelease(reg->sessionid);
        memset(reg, 0, sizeof(*reg));
    }
    if (gSessionId != NULL) {
        CFRelease(gSessionId);
        gSessionId = NULL;
    }
    (void)pthread_mutex_unlock(&gLock);
}

int
main(int argc, char **argv)
{
    int running = 1;
    int exact;

    fprintf(stderr, "%s\n", BUILD_MARKER);
    fprintf(stderr, "%s\n", SIXTH_POLICY_MARKER);
    fprintf(stderr, "%s\n", SEVENTH_POLICY_MARKER);
    fprintf(stderr, "%s\n", EIGHTH_POLICY_MARKER);
    fprintf(stderr, "%s\n", NINTH_POLICY_MARKER);
    fprintf(stderr, "%s\n", TENTH_POLICY_MARKER);
    fflush(stderr);

    if (argc != 3 || strcmp(argv[1], "--ipc-fd") != 0) {
        fprintf(stderr, "usage: %s --ipc-fd FD\n", argv[0]);
        return 64;
    }

    gIpcFd = parse_fd(argv[2]);
    if (gIpcFd < 0) {
        fprintf(stderr,
                "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:BAD_FD\n");
        return 65;
    }

    memset(gRegistrations, 0, sizeof(gRegistrations));
    memset(gAllowedSeen, 0, sizeof(gAllowedSeen));

    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_READY:fd=%d pid=%ld createwindowRegister=YES\n",
            gIpcFd,
            (long)getpid());
    fflush(stderr);

    while (running) {
        fd_set readfds;
        struct timeval tv;
        int rc;

        FD_ZERO(&readfds);
        FD_SET(gIpcFd, &readfds);
        tv.tv_sec = 0;
        tv.tv_usec = 50000;

        rc = select(gIpcFd + 1, &readfds, NULL, NULL, &tv);
        if (rc < 0) {
            if (errno == EINTR)
                continue;
            break;
        }

        if (rc > 0 && FD_ISSET(gIpcFd, &readfds)) {
            int frame_rc = read_one_frame(gIpcFd);
            if (frame_rc <= 0)
                running = 0;
        }

        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, true);
    }

    exact = gRegisterCount == 10U &&
            gAllowedSeen[0] == 1U &&
            gAllowedSeen[1] == 1U &&
            gAllowedSeen[2] == 1U &&
            gAllowedSeen[3] == 2U &&
            gAllowedSeen[4] == 1U &&
            gAllowedSeen[5] == 1U &&
            gAllowedSeen[6] == 1U &&
            gAllowedSeen[7] == 1U &&
            gAllowedSeen[8] == 1U &&
            gRejectCount == 0U;

    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=%u callback=%u rejects=%u exact=%s\n",
            gRegisterCount,
            gCallbackCount,
            gRejectCount,
            exact ? "YES" : "NO");
    fflush(stderr);

    release_registrations();
    close(gIpcFd);

    if (exact) {
        fprintf(stderr,
                "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS\n");
        fflush(stderr);
        return 0;
    }

    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:FAIL\n");
    fflush(stderr);
    return 1;
}
