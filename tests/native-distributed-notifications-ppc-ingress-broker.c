#include <CoreFoundation/CoreFoundation.h>
#include <arpa/inet.h>
#include <errno.h>
#include <pthread.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

#define BUILD_ID "distributed-notifications-ppc-ingress-broker-v1"
#define BUILD_MARKER \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_BUILD_ID:" BUILD_ID

#define FRAME_MAGIC 0x44504e31U
#define FRAME_VERSION 1U
#define FRAME_REQUEST 1U
#define FRAME_CALLBACK 2U
#define FRAME_MAX_PAYLOAD (256U * 1024U)
#define PROOF_PREFIX "com.openai.rosetta.distnotify.ppcingress."

enum {
    BROKER_OK = 0,
    BROKER_REJECT_SCHEMA = 20,
    BROKER_REJECT_OPERATION = 21,
    BROKER_REJECT_BEHAVIOR = 22,
    BROKER_REJECT_SUX = 23,
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

typedef struct BrokerRegistration {
    int active;
    CFNotificationCenterRef center;
    CFStringRef name;
    CFStringRef object;
    CFStringRef sessionid;
    int64_t entry;
    int32_t counter;
    int callback_count;
} BrokerRegistration;

static int gIpcFd = -1;
static BrokerRegistration gRegistration;
static unsigned int gRegisterCount = 0;
static unsigned int gPostCount = 0;
static unsigned int gUnregisterCount = 0;
static unsigned int gRejectCount = 0;
static pthread_mutex_t gRegistrationLock = PTHREAD_MUTEX_INITIALIZER;

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
has_proof_prefix(CFStringRef value)
{
    CFStringRef prefix;
    Boolean result;

    if (value == NULL || CFGetTypeID(value) != CFStringGetTypeID())
        return 0;

    prefix = CFStringCreateWithCString(
        kCFAllocatorDefault, PROOF_PREFIX, kCFStringEncodingUTF8);
    if (prefix == NULL)
        return 0;
    result = CFStringHasPrefix(value, prefix);
    CFRelease(prefix);
    return result ? 1 : 0;
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
get_boolean(CFDictionaryRef dict, CFStringRef key, Boolean *out)
{
    CFTypeRef value = CFDictionaryGetValue(dict, key);
    if (value == NULL || CFGetTypeID(value) != CFBooleanGetTypeID())
        return 0;
    *out = CFBooleanGetValue((CFBooleanRef)value);
    return 1;
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

static void
release_registration(void)
{
    if (gRegistration.object != NULL) {
        CFRelease(gRegistration.object);
        gRegistration.object = NULL;
    }
    if (gRegistration.name != NULL) {
        CFRelease(gRegistration.name);
        gRegistration.name = NULL;
    }
    if (gRegistration.sessionid != NULL) {
        CFRelease(gRegistration.sessionid);
        gRegistration.sessionid = NULL;
    }
    gRegistration.center = NULL;
    gRegistration.entry = 0;
    gRegistration.counter = 0;
    gRegistration.active = 0;
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

    (void)center;

    if (reg == NULL)
        return;

    (void)pthread_mutex_lock(&gRegistrationLock);
    if (!reg->active) {
        (void)pthread_mutex_unlock(&gRegistrationLock);
        return;
    }

    reg->callback_count += 1;

    ok = ok && name != NULL && CFEqual(name, reg->name);
    if (reg->object != NULL)
        ok = ok && object != NULL &&
             CFEqual((CFTypeRef)object, reg->object);
    else
        ok = ok && object == NULL;

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
    if (reg->object != NULL)
        CFDictionarySetValue(dict, CFSTR("object"), reg->object);
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
            (uint32_t)CFDataGetLength(encoded))) {
        ok = 0;
        goto done;
    }

done:
    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_CALLBACK:index=%d valid=%s entry=0x%llx counter=0x%x\n",
            reg->callback_count,
            ok ? "YES" : "NO",
            (unsigned long long)(uint64_t)reg->entry,
            (unsigned int)reg->counter);
    fflush(stderr);

    if (encoded != NULL) CFRelease(encoded);
    if (counter_number != NULL) CFRelease(counter_number);
    if (entry_number != NULL) CFRelease(entry_number);
    if (dict != NULL) CFRelease(dict);
    (void)pthread_mutex_unlock(&gRegistrationLock);
}

static int
handle_register(CFDictionaryRef dict)
{
    CFTypeRef name;
    CFTypeRef object;
    CFTypeRef sessionid;
    CFNotificationSuspensionBehavior public_behavior;
    int32_t behavior;
    int32_t counter;
    int64_t entry;

    if (gRegistration.active)
        return BROKER_REJECT_STATE;

    name = CFDictionaryGetValue(dict, CFSTR("name"));
    object = CFDictionaryGetValue(dict, CFSTR("object"));
    sessionid = CFDictionaryGetValue(dict, CFSTR("sessionid"));

    if (!has_proof_prefix((CFStringRef)name) ||
        (object != NULL && CFGetTypeID(object) != CFStringGetTypeID()) ||
        sessionid == NULL ||
        CFGetTypeID(sessionid) != CFStringGetTypeID() ||
        !get_sint32(dict, CFSTR("behavior"), &behavior) ||
        !get_sint32(dict, CFSTR("counter"), &counter) ||
        !get_sint64(dict, CFSTR("entry"), &entry))
        return BROKER_REJECT_SCHEMA;

    if (!legacy_behavior_to_public(behavior, &public_behavior))
        return BROKER_REJECT_BEHAVIOR;

    memset(&gRegistration, 0, sizeof(gRegistration));
    gRegistration.center = CFNotificationCenterGetDistributedCenter();
    if (gRegistration.center == NULL)
        return BROKER_REJECT_STATE;

    gRegistration.name = CFRetain((CFStringRef)name);
    gRegistration.object =
        object != NULL ? CFRetain((CFStringRef)object) : NULL;
    gRegistration.sessionid = CFRetain((CFStringRef)sessionid);
    gRegistration.entry = entry;
    gRegistration.counter = counter;
    gRegistration.active = 1;

    CFNotificationCenterAddObserver(
        gRegistration.center,
        &gRegistration,
        broker_callback,
        gRegistration.name,
        gRegistration.object,
        public_behavior);

    ++gRegisterCount;
    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_REGISTER:index=%u legacyBehavior=%d publicBehavior=%ld entry=0x%llx counter=0x%x\n",
            gRegisterCount,
            behavior,
            (long)public_behavior,
            (unsigned long long)(uint64_t)entry,
            (unsigned int)counter);
    fflush(stderr);
    return BROKER_OK;
}

static int
handle_post(CFDictionaryRef dict)
{
    CFTypeRef name;
    CFTypeRef object;
    CFTypeRef userinfo;
    CFTypeRef sessionid;
    Boolean immediately;
    Boolean sux;
    CFOptionFlags options = 0;

    if (!gRegistration.active)
        return BROKER_REJECT_STATE;

    name = CFDictionaryGetValue(dict, CFSTR("name"));
    object = CFDictionaryGetValue(dict, CFSTR("object"));
    userinfo = CFDictionaryGetValue(dict, CFSTR("userinfo"));
    sessionid = CFDictionaryGetValue(dict, CFSTR("sessionid"));

    if (!has_proof_prefix((CFStringRef)name) ||
        !CFEqual(name, gRegistration.name) ||
        (gRegistration.object != NULL &&
         (object == NULL || !CFEqual(object, gRegistration.object))) ||
        (gRegistration.object == NULL && object != NULL) ||
        (userinfo != NULL &&
         CFGetTypeID(userinfo) != CFDictionaryGetTypeID()) ||
        sessionid == NULL ||
        CFGetTypeID(sessionid) != CFStringGetTypeID() ||
        !get_boolean(dict, CFSTR("immediately"), &immediately) ||
        !get_boolean(dict, CFSTR("sux"), &sux))
        return BROKER_REJECT_SCHEMA;

    if (sux)
        return BROKER_REJECT_SUX;

    /*
     * Register has no all-session variant.  Requiring the post's sessionid
     * to equal the registered sessionid rejects the all-session post path
     * without guessing Snow's private all-session sentinel.
     */
    if (!CFEqual(sessionid, gRegistration.sessionid))
        return BROKER_REJECT_SCOPE;

    if (immediately)
        options |= kCFNotificationDeliverImmediately;

    CFNotificationCenterPostNotificationWithOptions(
        gRegistration.center,
        (CFStringRef)name,
        object,
        (CFDictionaryRef)userinfo,
        options);

    ++gPostCount;
    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_POST:index=%u options=0x%lx currentSession=YES sux=NO\n",
            gPostCount,
            (unsigned long)options);
    fflush(stderr);
    return BROKER_OK;
}

static int
array_contains_entry(CFArrayRef entries, int64_t wanted)
{
    CFIndex count;
    CFIndex i;

    if (entries == NULL || CFGetTypeID(entries) != CFArrayGetTypeID())
        return 0;

    count = CFArrayGetCount(entries);
    for (i = 0; i < count; ++i) {
        CFTypeRef value = CFArrayGetValueAtIndex(entries, i);
        int64_t entry = 0;
        if (value != NULL &&
            CFGetTypeID(value) == CFNumberGetTypeID() &&
            CFNumberGetValue(
                (CFNumberRef)value, kCFNumberSInt64Type, &entry) &&
            entry == wanted)
            return 1;
    }
    return 0;
}

static int
handle_unregister(CFDictionaryRef dict)
{
    CFTypeRef entries;
    int result = BROKER_OK;

    (void)pthread_mutex_lock(&gRegistrationLock);

    if (!gRegistration.active) {
        result = BROKER_REJECT_STATE;
        goto done;
    }

    entries = CFDictionaryGetValue(dict, CFSTR("entries"));
    if (!array_contains_entry((CFArrayRef)entries, gRegistration.entry)) {
        result = BROKER_REJECT_SCHEMA;
        goto done;
    }

    CFNotificationCenterRemoveObserver(
        gRegistration.center,
        &gRegistration,
        gRegistration.name,
        gRegistration.object);

    ++gUnregisterCount;
    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_UNREGISTER:index=%u entry=0x%llx\n",
            gUnregisterCount,
            (unsigned long long)(uint64_t)gRegistration.entry);
    fflush(stderr);

    release_registration();

done:
    (void)pthread_mutex_unlock(&gRegistrationLock);
    return result;
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
    if (CFEqual(operation, CFSTR("post")))
        return handle_post(dict);
    if (CFEqual(operation, CFSTR("unregister")))
        return handle_unregister(dict);

    if (CFEqual(operation, CFSTR("suspend")) ||
        CFEqual(operation, CFSTR("session_reset")))
        return BROKER_REJECT_OPERATION;

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
            "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_REQUEST:length=%u status=%d\n",
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
                "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_REJECT:status=%d\n",
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

int
main(int argc, char **argv)
{
    int running = 1;

    fprintf(stderr, "%s\n", BUILD_MARKER);
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

    memset(&gRegistration, 0, sizeof(gRegistration));

    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_READY:fd=%d pid=%ld\n",
            gIpcFd, (long)getpid());
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

    (void)pthread_mutex_lock(&gRegistrationLock);
    if (gRegistration.active) {
        CFNotificationCenterRemoveObserver(
            gRegistration.center,
            &gRegistration,
            gRegistration.name,
            gRegistration.object);
        release_registration();
    }
    (void)pthread_mutex_unlock(&gRegistrationLock);

    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_EXIT:register=%u post=%u callback=%d unregister=%u rejects=%u\n",
            gRegisterCount,
            gPostCount,
            gRegistration.callback_count,
            gUnregisterCount,
            gRejectCount);
    fflush(stderr);

    close(gIpcFd);

    if (gRegisterCount == 1U &&
        gPostCount == 1U &&
        gUnregisterCount == 1U &&
        gRejectCount == 0U) {
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
