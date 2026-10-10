#include <CoreFoundation/CoreFoundation.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BUILD_ID "distributed-notifications-native-broker-proof-v1"
#define BUILD_MARKER \
    "PM_DISTRIBUTED_NOTIFICATIONS_NATIVE_BROKER_PROOF_BUILD_ID:" BUILD_ID

#define PROOF_TIMEOUT_SECONDS 10.0

enum {
    BROKER_OK = 0,
    BROKER_REJECT_OPERATION = 20,
    BROKER_REJECT_SCHEMA = 21,
    BROKER_REJECT_BEHAVIOR = 22,
    BROKER_REJECT_SUX = 23,
    BROKER_REJECT_ALL_SESSIONS = 24
};

typedef struct BrokerRegistration {
    CFNotificationCenterRef center;
    CFStringRef name;
    CFStringRef object;
    CFStringRef expected_nonce;
    uint64_t entry;
    int32_t counter;
    volatile int callback_count;
    volatile int callback_valid;
} BrokerRegistration;

static const char *const build_marker = BUILD_MARKER;

static int cf_is_string(CFTypeRef value) {
    return value != NULL && CFGetTypeID(value) == CFStringGetTypeID();
}

static int cf_is_dictionary(CFTypeRef value) {
    return value != NULL && CFGetTypeID(value) == CFDictionaryGetTypeID();
}

static int cf_is_number(CFTypeRef value) {
    return value != NULL && CFGetTypeID(value) == CFNumberGetTypeID();
}

static int cf_is_boolean(CFTypeRef value) {
    return value != NULL && CFGetTypeID(value) == CFBooleanGetTypeID();
}

static int legacy_behavior_to_public(int32_t legacy,
                                     CFNotificationSuspensionBehavior *out) {
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

static int check_public_enum_contract(void) {
    int ok = 1;
    ok = ok && (CFNotificationSuspensionBehaviorDrop == 1);
    ok = ok && (CFNotificationSuspensionBehaviorCoalesce == 2);
    ok = ok && (CFNotificationSuspensionBehaviorHold == 3);
    ok = ok && (CFNotificationSuspensionBehaviorDeliverImmediately == 4);
    ok = ok && (kCFNotificationDeliverImmediately == (1UL << 0));
    ok = ok && (kCFNotificationPostToAllSessions == (1UL << 1));

    printf("enum_drop=%ld\n", (long)CFNotificationSuspensionBehaviorDrop);
    printf("enum_coalesce=%ld\n", (long)CFNotificationSuspensionBehaviorCoalesce);
    printf("enum_hold=%ld\n", (long)CFNotificationSuspensionBehaviorHold);
    printf("enum_deliver_immediately=%ld\n",
           (long)CFNotificationSuspensionBehaviorDeliverImmediately);
    printf("post_option_deliver_immediately=0x%lx\n",
           (unsigned long)kCFNotificationDeliverImmediately);
    printf("post_option_all_sessions=0x%lx\n",
           (unsigned long)kCFNotificationPostToAllSessions);
    printf("enum_contract=%s\n", ok ? "PASS" : "FAIL");
    return ok;
}

static CFMutableDictionaryRef make_base_request(CFStringRef operation) {
    CFMutableDictionaryRef dict = CFDictionaryCreateMutable(
        kCFAllocatorDefault,
        0,
        &kCFTypeDictionaryKeyCallBacks,
        &kCFTypeDictionaryValueCallBacks);
    if (dict != NULL) {
        CFDictionarySetValue(dict, CFSTR("message_type"), operation);
    }
    return dict;
}

static int get_sint32(CFDictionaryRef dict, CFStringRef key, int32_t *out) {
    CFTypeRef value = CFDictionaryGetValue(dict, key);
    if (!cf_is_number(value)) {
        return 0;
    }
    return CFNumberGetValue((CFNumberRef)value, kCFNumberSInt32Type, out);
}

static int get_sint64(CFDictionaryRef dict, CFStringRef key, int64_t *out) {
    CFTypeRef value = CFDictionaryGetValue(dict, key);
    if (!cf_is_number(value)) {
        return 0;
    }
    return CFNumberGetValue((CFNumberRef)value, kCFNumberSInt64Type, out);
}

static int validate_operation(CFDictionaryRef request, CFStringRef expected) {
    CFTypeRef operation = CFDictionaryGetValue(request, CFSTR("message_type"));
    return cf_is_string(operation) && CFEqual(operation, expected);
}

static int broker_reject_excluded_operation(CFDictionaryRef request) {
    CFTypeRef operation = CFDictionaryGetValue(request, CFSTR("message_type"));
    if (!cf_is_string(operation)) {
        return BROKER_REJECT_SCHEMA;
    }
    if (CFEqual(operation, CFSTR("suspend")) ||
        CFEqual(operation, CFSTR("session_reset"))) {
        return BROKER_REJECT_OPERATION;
    }
    return BROKER_OK;
}

static void translated_callback(CFNotificationCenterRef center,
                                void *observer,
                                CFStringRef name,
                                const void *object,
                                CFDictionaryRef userInfo) {
    BrokerRegistration *reg = (BrokerRegistration *)observer;
    CFMutableDictionaryRef legacy = NULL;
    CFNumberRef counter_number = NULL;
    CFNumberRef entry_number = NULL;
    int64_t entry_signed;
    int32_t counter;
    int ok = 1;
    CFTypeRef nonce = NULL;

    (void)center;

    if (reg == NULL) {
        return;
    }

    reg->callback_count += 1;

    ok = ok && (name != NULL) && CFEqual(name, reg->name);
    if (reg->object != NULL) {
        ok = ok && (object != NULL) && CFEqual((CFTypeRef)object, reg->object);
    } else {
        ok = ok && (object == NULL);
    }

    if (reg->expected_nonce != NULL) {
        ok = ok && (userInfo != NULL);
        if (userInfo != NULL) {
            nonce = CFDictionaryGetValue(userInfo, CFSTR("proof_nonce"));
            ok = ok && cf_is_string(nonce) &&
                 CFEqual(nonce, reg->expected_nonce);
        }
    }

    legacy = CFDictionaryCreateMutable(
        kCFAllocatorDefault,
        0,
        &kCFTypeDictionaryKeyCallBacks,
        &kCFTypeDictionaryValueCallBacks);
    if (legacy == NULL) {
        ok = 0;
        goto done;
    }

    entry_signed = (int64_t)reg->entry;
    counter = reg->counter;
    entry_number = CFNumberCreate(
        kCFAllocatorDefault, kCFNumberSInt64Type, &entry_signed);
    counter_number = CFNumberCreate(
        kCFAllocatorDefault, kCFNumberSInt32Type, &counter);
    if (entry_number == NULL || counter_number == NULL) {
        ok = 0;
        goto done;
    }

    CFDictionarySetValue(legacy, CFSTR("message_type"), CFSTR("post"));
    CFDictionarySetValue(legacy, CFSTR("name"), reg->name);
    if (reg->object != NULL) {
        CFDictionarySetValue(legacy, CFSTR("object"), reg->object);
    }
    if (userInfo != NULL) {
        CFDictionarySetValue(legacy, CFSTR("userinfo"), userInfo);
    }
    CFDictionarySetValue(legacy, CFSTR("counter"), counter_number);
    CFDictionarySetValue(legacy, CFSTR("entry"), entry_number);

    {
        int64_t check_entry = 0;
        int32_t check_counter = 0;
        CFTypeRef message_type =
            CFDictionaryGetValue(legacy, CFSTR("message_type"));
        ok = ok && cf_is_string(message_type) &&
             CFEqual(message_type, CFSTR("post"));
        ok = ok && get_sint64(legacy, CFSTR("entry"), &check_entry);
        ok = ok && get_sint32(legacy, CFSTR("counter"), &check_counter);
        ok = ok && ((uint64_t)check_entry == reg->entry);
        ok = ok && (check_counter == reg->counter);
    }

done:
    reg->callback_valid = ok ? 1 : 0;
    printf("callback_translation=%s entry=0x%llx counter=0x%x\n",
           ok ? "PASS" : "FAIL",
           (unsigned long long)reg->entry,
           (unsigned int)reg->counter);
    fflush(stdout);

    if (counter_number != NULL) {
        CFRelease(counter_number);
    }
    if (entry_number != NULL) {
        CFRelease(entry_number);
    }
    if (legacy != NULL) {
        CFRelease(legacy);
    }
}

static int broker_register_from_legacy(CFNotificationCenterRef center,
                                       CFDictionaryRef request,
                                       BrokerRegistration *reg,
                                       int *api_calls) {
    CFTypeRef name;
    CFTypeRef object;
    int32_t behavior;
    int32_t counter;
    int64_t entry;
    CFNotificationSuspensionBehavior public_behavior;

    if (!validate_operation(request, CFSTR("register"))) {
        return BROKER_REJECT_OPERATION;
    }

    name = CFDictionaryGetValue(request, CFSTR("name"));
    object = CFDictionaryGetValue(request, CFSTR("object"));
    if (!cf_is_string(name) || (object != NULL && !cf_is_string(object))) {
        return BROKER_REJECT_SCHEMA;
    }
    if (!get_sint32(request, CFSTR("behavior"), &behavior) ||
        !get_sint32(request, CFSTR("counter"), &counter) ||
        !get_sint64(request, CFSTR("entry"), &entry)) {
        return BROKER_REJECT_SCHEMA;
    }
    if (!legacy_behavior_to_public(behavior, &public_behavior)) {
        return BROKER_REJECT_BEHAVIOR;
    }

    memset(reg, 0, sizeof(*reg));
    reg->center = center;
    reg->name = CFRetain((CFStringRef)name);
    reg->object = object != NULL ? CFRetain((CFStringRef)object) : NULL;
    reg->entry = (uint64_t)entry;
    reg->counter = counter;

    *api_calls += 1;
    CFNotificationCenterAddObserver(
        center,
        reg,
        translated_callback,
        reg->name,
        reg->object,
        public_behavior);

    printf("register_translation=PASS legacy_behavior=%d public_behavior=%ld\n",
           behavior, (long)public_behavior);
    return BROKER_OK;
}

static int broker_post_from_legacy(CFNotificationCenterRef center,
                                   CFDictionaryRef request,
                                   int normalized_current_session,
                                   int *api_calls) {
    CFTypeRef name;
    CFTypeRef object;
    CFTypeRef userinfo;
    CFTypeRef immediately;
    CFTypeRef sux;
    CFOptionFlags options = 0;

    if (!validate_operation(request, CFSTR("post"))) {
        return BROKER_REJECT_OPERATION;
    }

    if (!normalized_current_session) {
        return BROKER_REJECT_ALL_SESSIONS;
    }

    sux = CFDictionaryGetValue(request, CFSTR("sux"));
    if (!cf_is_boolean(sux) || CFBooleanGetValue((CFBooleanRef)sux)) {
        return BROKER_REJECT_SUX;
    }

    name = CFDictionaryGetValue(request, CFSTR("name"));
    object = CFDictionaryGetValue(request, CFSTR("object"));
    userinfo = CFDictionaryGetValue(request, CFSTR("userinfo"));
    immediately = CFDictionaryGetValue(request, CFSTR("immediately"));

    if (!cf_is_string(name) ||
        (object != NULL && !cf_is_string(object)) ||
        (userinfo != NULL && !cf_is_dictionary(userinfo)) ||
        !cf_is_boolean(immediately)) {
        return BROKER_REJECT_SCHEMA;
    }

    if (CFBooleanGetValue((CFBooleanRef)immediately)) {
        options |= kCFNotificationDeliverImmediately;
    }

    *api_calls += 1;
    CFNotificationCenterPostNotificationWithOptions(
        center,
        (CFStringRef)name,
        object,
        (CFDictionaryRef)userinfo,
        options);

    printf("post_translation=PASS public_options=0x%lx current_session=YES\n",
           (unsigned long)options);
    return BROKER_OK;
}

static void broker_unregister(BrokerRegistration *reg, int *api_calls) {
    if (reg == NULL || reg->center == NULL || reg->name == NULL) {
        return;
    }

    *api_calls += 1;
    CFNotificationCenterRemoveObserver(
        reg->center, reg, reg->name, reg->object);
    printf("unregister_translation=PASS\n");

    if (reg->expected_nonce != NULL) {
        CFRelease(reg->expected_nonce);
        reg->expected_nonce = NULL;
    }
    if (reg->object != NULL) {
        CFRelease(reg->object);
        reg->object = NULL;
    }
    if (reg->name != NULL) {
        CFRelease(reg->name);
        reg->name = NULL;
    }
}

static CFMutableDictionaryRef make_register_request(CFStringRef name,
                                                    CFStringRef object,
                                                    int32_t behavior,
                                                    int32_t counter,
                                                    uint64_t entry) {
    CFMutableDictionaryRef request = make_base_request(CFSTR("register"));
    CFNumberRef behavior_number = NULL;
    CFNumberRef counter_number = NULL;
    CFNumberRef entry_number = NULL;
    int64_t entry_signed = (int64_t)entry;

    if (request == NULL) {
        return NULL;
    }

    behavior_number = CFNumberCreate(
        kCFAllocatorDefault, kCFNumberSInt32Type, &behavior);
    counter_number = CFNumberCreate(
        kCFAllocatorDefault, kCFNumberSInt32Type, &counter);
    entry_number = CFNumberCreate(
        kCFAllocatorDefault, kCFNumberSInt64Type, &entry_signed);
    if (behavior_number == NULL || counter_number == NULL ||
        entry_number == NULL) {
        if (behavior_number != NULL) CFRelease(behavior_number);
        if (counter_number != NULL) CFRelease(counter_number);
        if (entry_number != NULL) CFRelease(entry_number);
        CFRelease(request);
        return NULL;
    }

    CFDictionarySetValue(request, CFSTR("name"), name);
    if (object != NULL) {
        CFDictionarySetValue(request, CFSTR("object"), object);
    }
    CFDictionarySetValue(request, CFSTR("behavior"), behavior_number);
    CFDictionarySetValue(request, CFSTR("counter"), counter_number);
    CFDictionarySetValue(request, CFSTR("entry"), entry_number);

    CFRelease(behavior_number);
    CFRelease(counter_number);
    CFRelease(entry_number);
    return request;
}

static CFMutableDictionaryRef make_post_request(CFStringRef name,
                                                CFStringRef object,
                                                CFStringRef nonce,
                                                Boolean immediately,
                                                Boolean sux) {
    CFMutableDictionaryRef request = make_base_request(CFSTR("post"));
    CFMutableDictionaryRef userinfo = NULL;

    if (request == NULL) {
        return NULL;
    }

    userinfo = CFDictionaryCreateMutable(
        kCFAllocatorDefault,
        0,
        &kCFTypeDictionaryKeyCallBacks,
        &kCFTypeDictionaryValueCallBacks);
    if (userinfo == NULL) {
        CFRelease(request);
        return NULL;
    }

    CFDictionarySetValue(userinfo, CFSTR("proof_nonce"), nonce);
    CFDictionarySetValue(request, CFSTR("name"), name);
    if (object != NULL) {
        CFDictionarySetValue(request, CFSTR("object"), object);
    }
    CFDictionarySetValue(request, CFSTR("userinfo"), userinfo);
    CFDictionarySetValue(
        request, CFSTR("immediately"), immediately ? kCFBooleanTrue : kCFBooleanFalse);
    CFDictionarySetValue(
        request, CFSTR("sux"), sux ? kCFBooleanTrue : kCFBooleanFalse);
    CFDictionarySetValue(
        request, CFSTR("sessionid"), CFSTR("normalized-current-session"));

    CFRelease(userinfo);
    return request;
}

static int run_negative_controls(void) {
    int api_calls = 0;
    int ok = 1;
    int status;
    CFMutableDictionaryRef request;
    CFStringRef name = CFSTR("com.openai.rosetta.distnotify.negative");
    CFStringRef object = CFSTR("negative-object");
    CFStringRef nonce = CFSTR("negative-nonce");

    request = make_post_request(name, object, nonce, true, true);
    if (request == NULL) return 0;
    status = broker_post_from_legacy(NULL, request, 1, &api_calls);
    ok = ok && (status == BROKER_REJECT_SUX) && (api_calls == 0);
    CFRelease(request);

    request = make_post_request(name, object, nonce, true, false);
    if (request == NULL) return 0;
    status = broker_post_from_legacy(NULL, request, 0, &api_calls);
    ok = ok && (status == BROKER_REJECT_ALL_SESSIONS) && (api_calls == 0);
    CFRelease(request);

    request = make_base_request(CFSTR("suspend"));
    if (request == NULL) return 0;
    status = broker_reject_excluded_operation(request);
    ok = ok && (status == BROKER_REJECT_OPERATION) && (api_calls == 0);
    CFRelease(request);

    request = make_base_request(CFSTR("session_reset"));
    if (request == NULL) return 0;
    status = broker_reject_excluded_operation(request);
    ok = ok && (status == BROKER_REJECT_OPERATION) && (api_calls == 0);
    CFRelease(request);

    request = make_register_request(name, object, 3, 1, 1);
    if (request == NULL) return 0;
    {
        BrokerRegistration dummy;
        status = broker_register_from_legacy(NULL, request, &dummy, &api_calls);
    }
    ok = ok && (status == BROKER_REJECT_BEHAVIOR) && (api_calls == 0);
    CFRelease(request);

    printf("negative_sux_true=REJECTED\n");
    printf("negative_all_sessions=REJECTED\n");
    printf("negative_suspend=REJECTED\n");
    printf("negative_session_reset=REJECTED\n");
    printf("negative_unknown_behavior=REJECTED\n");
    printf("negative_api_call_count=%d\n", api_calls);
    printf("negative_controls=%s\n", ok ? "PASS" : "FAIL");
    return ok;
}

static CFStringRef string_from_utf8(const char *value) {
    return CFStringCreateWithCString(
        kCFAllocatorDefault, value, kCFStringEncodingUTF8);
}

static int run_poster(const char *name_c,
                      const char *object_c,
                      const char *nonce_c) {
    CFNotificationCenterRef center;
    CFStringRef name = NULL;
    CFStringRef object = NULL;
    CFStringRef nonce = NULL;
    CFMutableDictionaryRef request = NULL;
    int api_calls = 0;
    int status = 1;

    name = string_from_utf8(name_c);
    object = string_from_utf8(object_c);
    nonce = string_from_utf8(nonce_c);
    if (name == NULL || object == NULL || nonce == NULL) {
        goto done;
    }

    request = make_post_request(name, object, nonce, true, false);
    if (request == NULL) {
        goto done;
    }

    center = CFNotificationCenterGetDistributedCenter();
    if (center == NULL) {
        goto done;
    }

    status = broker_post_from_legacy(center, request, 1, &api_calls);
    if (status != BROKER_OK || api_calls != 1) {
        status = 1;
        goto done;
    }

    printf("poster_result=PASS\n");
    fflush(stdout);
    status = 0;

done:
    if (request != NULL) CFRelease(request);
    if (nonce != NULL) CFRelease(nonce);
    if (object != NULL) CFRelease(object);
    if (name != NULL) CFRelease(name);
    return status;
}

static int cfstring_to_cstring(CFStringRef value, char *buffer, size_t size) {
    if (value == NULL || buffer == NULL || size == 0) {
        return 0;
    }
    return CFStringGetCString(
        value, buffer, (CFIndex)size, kCFStringEncodingUTF8);
}

static int run_positive_proof(const char *exe_path) {
    CFNotificationCenterRef center;
    CFMutableDictionaryRef register_request = NULL;
    BrokerRegistration reg;
    int api_calls = 0;
    int status;
    int result = 1;
    int child_status = 0;
    pid_t child = -1;
    CFStringRef name = NULL;
    CFStringRef object = NULL;
    CFStringRef nonce = NULL;
    char name_c[512];
    char object_c[256];
    char nonce_c[256];
    char name_buf[256];
    char nonce_buf[128];
    int32_t counter = 0x13572468;
    uint64_t entry = UINT64_C(0x1122334455667788);
    CFAbsoluteTime deadline;

    memset(&reg, 0, sizeof(reg));

    snprintf(name_buf, sizeof(name_buf),
             "com.openai.rosetta.distnotify.brokerproof.%ld",
             (long)getpid());
    snprintf(nonce_buf, sizeof(nonce_buf),
             "nonce-%ld", (long)getpid());

    name = string_from_utf8(name_buf);
    object = CFSTR("native-broker-proof-object");
    CFRetain(object);
    nonce = string_from_utf8(nonce_buf);
    if (name == NULL || object == NULL || nonce == NULL) {
        goto done;
    }

    register_request = make_register_request(
        name, object, 1, counter, entry);
    if (register_request == NULL) {
        goto done;
    }

    center = CFNotificationCenterGetDistributedCenter();
    if (center == NULL) {
        printf("distributed_center=NULL\n");
        goto done;
    }

    status = broker_register_from_legacy(
        center, register_request, &reg, &api_calls);
    if (status != BROKER_OK) {
        printf("register_translation=FAIL status=%d\n", status);
        goto done;
    }

    reg.expected_nonce = CFRetain(nonce);

    if (!cfstring_to_cstring(name, name_c, sizeof(name_c)) ||
        !cfstring_to_cstring(object, object_c, sizeof(object_c)) ||
        !cfstring_to_cstring(nonce, nonce_c, sizeof(nonce_c))) {
        goto cleanup_registration;
    }

    child = fork();
    if (child < 0) {
        perror("fork");
        goto cleanup_registration;
    }
    if (child == 0) {
        execl(exe_path, exe_path, "--poster", name_c, object_c, nonce_c,
              (char *)NULL);
        perror("execl");
        _exit(127);
    }

    deadline = CFAbsoluteTimeGetCurrent() + PROOF_TIMEOUT_SECONDS;
    while (reg.callback_count == 0 &&
           CFAbsoluteTimeGetCurrent() < deadline) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.10, true);
        usleep(10000);
    }

    if (waitpid(child, &child_status, 0) < 0) {
        perror("waitpid");
        child_status = -1;
    }

    printf("child_exit_status=%d\n",
           (child_status >= 0 && WIFEXITED(child_status))
               ? WEXITSTATUS(child_status)
               : -1);
    printf("callback_count=%d\n", reg.callback_count);
    printf("callback_valid=%s\n", reg.callback_valid ? "YES" : "NO");

    if (child_status >= 0 && WIFEXITED(child_status) &&
        WEXITSTATUS(child_status) == 0 &&
        reg.callback_count == 1 && reg.callback_valid) {
        result = 0;
    }

cleanup_registration:
    broker_unregister(&reg, &api_calls);
    printf("positive_api_call_count=%d\n", api_calls);

done:
    if (register_request != NULL) CFRelease(register_request);
    if (nonce != NULL) CFRelease(nonce);
    if (object != NULL) CFRelease(object);
    if (name != NULL) CFRelease(name);
    return result;
}

int main(int argc, char **argv) {
    printf("%s\n", build_marker);

    if (argc == 5 && strcmp(argv[1], "--poster") == 0) {
        return run_poster(argv[2], argv[3], argv[4]);
    }

    if (argc != 1) {
        fprintf(stderr, "usage: %s\n", argv[0]);
        return 64;
    }

    if (!check_public_enum_contract()) {
        printf("RESULT: DISTRIBUTED_NOTIFICATIONS_NATIVE_BROKER_PROOF_FAIL\n");
        return 1;
    }

    if (!run_negative_controls()) {
        printf("RESULT: DISTRIBUTED_NOTIFICATIONS_NATIVE_BROKER_PROOF_FAIL\n");
        return 1;
    }

    if (run_positive_proof(argv[0]) != 0) {
        printf("RESULT: DISTRIBUTED_NOTIFICATIONS_NATIVE_BROKER_PROOF_FAIL\n");
        return 1;
    }

    printf("RESULT: DISTRIBUTED_NOTIFICATIONS_NATIVE_BROKER_PROOF_PASS\n");
    return 0;
}
