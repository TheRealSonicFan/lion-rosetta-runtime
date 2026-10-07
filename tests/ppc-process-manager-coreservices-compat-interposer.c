#include <mach/mach.h>
#include <mach/mig_errors.h>
#include <mach/ndr.h>
#include <servers/bootstrap.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>

extern kern_return_t bootstrap_look_up2(mach_port_t,
                                         const char *,
                                         mach_port_t *,
                                         pid_t,
                                         uint64_t);
extern mach_port_t mig_get_reply_port(void);

#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-v2"
#define COMPAT_BUILD_MARKER "PM_CORESERVICES_COMPAT_BUILD_ID:" COMPAT_BUILD_ID
#define COMPAT_MODE_ENV "ROSETTA_CORESERVICES_COMPAT_MODE"
#define COMPAT_MODE_PASSTHROUGH "passthrough"
#define COMPAT_MODE_LION_DUAL "lion-dual-adapter"

#define LOOKUP_REQUEST_ID 0x00000194U
#define LOOKUP_REPLY_ID 0x000001f8U
#define LOOKUP_SEND_SIZE 0x000000bcU
#define LOOKUP_RECV_SIZE 0x0000006cU
#define LOOKUP_SUCCESS_SIZE 0x00000028U
#define LOOKUP_ERROR_SIZE 0x00000024U
#define LOOKUP_SERVICE_OFF 0x20U
#define LOOKUP_PID_OFF 0xa0U
#define LOOKUP_UUID_OFF 0xa4U
#define LOOKUP_FLAGS_OFF 0xb4U
#define LOOKUP_REPLY_DESC_COUNT_OFF 0x18U
#define LOOKUP_REPLY_PORT_OFF 0x1cU
#define LOOKUP_REPLY_RETCODE_OFF 0x20U
#define LOOKUP_MSG_OPTIONS 0x03000003U

#define CHECKIN_REQUEST_ID 0x00002710U
#define CHECKIN_REPLY_ID 0x00002774U
#define CHECKIN_LEGACY_BITS 0x80001513U
#define CHECKIN_LION_BITS 0x00001513U
#define CHECKIN_LEGACY_SEND_SIZE 0x00000028U
#define CHECKIN_LION_SEND_SIZE 0x00000018U
#define CHECKIN_RECV_SIZE 0x0000003cU
#define CHECKIN_SUCCESS_SIZE 0x00000034U
#define CHECKIN_REPLY_DESC_COUNT_OFF 0x18U
#define CHECKIN_REPLY_PORT_OFF 0x1cU
#define CHECKIN_REPLY_DISPOSITION_OFF 0x26U
#define CHECKIN_REPLY_TYPE_OFF 0x27U
#define CHECKIN_REPLY_OPTIONS_OFF 0x30U

#define PRIVILEGED_SERVER_FLAG 0x0000000000000008ULL

static const char *kCoreServicesDName =
    "com.apple.CoreServices.coreservicesd";

typedef kern_return_t (*bootstrap_lookup2_fn)(mach_port_t,
                                              const char *,
                                              mach_port_t *,
                                              pid_t,
                                              uint64_t);
typedef mach_msg_return_t (*mach_msg_fn)(mach_msg_header_t *,
                                         mach_msg_option_t,
                                         mach_msg_size_t,
                                         mach_msg_size_t,
                                         mach_port_name_t,
                                         mach_msg_timeout_t,
                                         mach_port_name_t);

struct interpose_tuple {
    const void *replacement;
    const void *replacee;
};

static kern_return_t rosetta_bootstrap_look_up2(mach_port_t,
                                                 const char *,
                                                 mach_port_t *,
                                                 pid_t,
                                                 uint64_t);
static mach_msg_return_t rosetta_mach_msg(mach_msg_header_t *,
                                           mach_msg_option_t,
                                           mach_msg_size_t,
                                           mach_msg_size_t,
                                           mach_port_name_t,
                                           mach_msg_timeout_t,
                                           mach_port_name_t);

static struct interpose_tuple sInterposes[2];

static bootstrap_lookup2_fn gOriginalLookup = NULL;
static mach_msg_fn gOriginalMachMsg = NULL;
static unsigned int gBootstrapExactCallCount = 0;
static unsigned int gBootstrapAdaptedCallCount = 0;
static unsigned int gServerCheckinExactCallCount = 0;
static unsigned int gServerCheckinAdaptedCallCount = 0;
static mach_port_t gCoreServicesServerPort = MACH_PORT_NULL;

static void
put_u32(unsigned char *p, uint32_t value)
{
    memcpy(p, &value, sizeof(value));
}

static uint32_t
get_u32(const unsigned char *p)
{
    uint32_t value;
    memcpy(&value, p, sizeof(value));
    return value;
}

static void
put_u64(unsigned char *p, uint64_t value)
{
    memcpy(p, &value, sizeof(value));
}

static bootstrap_lookup2_fn
original_lookup(void)
{
    if (gOriginalLookup == NULL) {
        gOriginalLookup = (bootstrap_lookup2_fn)
            (uintptr_t)sInterposes[0].replacee;
    }
    return gOriginalLookup;
}

static mach_msg_fn
original_mach_msg(void)
{
    if (gOriginalMachMsg == NULL) {
        gOriginalMachMsg = (mach_msg_fn)
            (uintptr_t)sInterposes[1].replacee;
    }
    return gOriginalMachMsg;
}

static mach_msg_return_t
call_original_mach_msg(mach_msg_header_t *msg,
                       mach_msg_option_t option,
                       mach_msg_size_t send_size,
                       mach_msg_size_t rcv_size,
                       mach_port_name_t rcv_name,
                       mach_msg_timeout_t timeout,
                       mach_port_name_t notify)
{
    mach_msg_fn fn = original_mach_msg();

    if (fn == NULL || fn == (mach_msg_fn)&rosetta_mach_msg)
        return MIG_BAD_ID;

    return fn(msg, option, send_size, rcv_size,
              rcv_name, timeout, notify);
}

static kern_return_t
call_original_lookup(mach_port_t bp,
                     const char *service_name,
                     mach_port_t *service_port,
                     pid_t target_pid,
                     uint64_t flags,
                     const char *reason)
{
    bootstrap_lookup2_fn fn = original_lookup();
    kern_return_t kr;

    if (fn == NULL ||
        fn == (bootstrap_lookup2_fn)&rosetta_bootstrap_look_up2) {
        if (service_port != NULL)
            *service_port = MACH_PORT_NULL;
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_BOOTSTRAP_ORIGINAL_UNAVAILABLE:reason=%s\n",
                reason);
        fflush(stderr);
        return MIG_BAD_ID;
    }

    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_BOOTSTRAP_PASSTHROUGH:reason=%s name=%s pid=%ld flags=0x%08lx%08lx\n",
            reason,
            service_name ? service_name : "(null)",
            (long)target_pid,
            (unsigned long)(uint32_t)(flags >> 32),
            (unsigned long)(uint32_t)flags);
    fflush(stderr);

    kr = fn(bp, service_name, service_port, target_pid, flags);

    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_BOOTSTRAP_PASSTHROUGH_RETURN:kr=%ld hex=0x%08lx servicePort=0x%08lx\n",
            (long)kr,
            (unsigned long)(uint32_t)kr,
            (unsigned long)((service_port != NULL) ?
                            *service_port : MACH_PORT_NULL));
    fflush(stderr);

    return kr;
}

static int
build_lion_lookup_request(unsigned char *buffer,
                          mach_port_t remote_port,
                          mach_port_t reply_port,
                          const char *service_name,
                          pid_t target_pid,
                          uint64_t flags)
{
    uint32_t bits;

    if (buffer == NULL || service_name == NULL)
        return 0;

    memset(buffer, 0, LOOKUP_SEND_SIZE);

    bits = (uint32_t)MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND,
                                    MACH_MSG_TYPE_MAKE_SEND_ONCE);

    put_u32(buffer + 0x00, bits);
    put_u32(buffer + 0x04, LOOKUP_SEND_SIZE);
    put_u32(buffer + 0x08, (uint32_t)remote_port);
    put_u32(buffer + 0x0c, (uint32_t)reply_port);
    put_u32(buffer + 0x10, 0U);
    put_u32(buffer + 0x14, LOOKUP_REQUEST_ID);
    memcpy(buffer + 0x18, &NDR_record, sizeof(NDR_record));

    strncpy((char *)(buffer + LOOKUP_SERVICE_OFF),
            service_name, 0x7f);
    ((char *)(buffer + LOOKUP_SERVICE_OFF))[0x7f] = '\0';

    memcpy(buffer + LOOKUP_PID_OFF, &target_pid, sizeof(target_pid));
    memset(buffer + LOOKUP_UUID_OFF, 0, 16);
    put_u64(buffer + LOOKUP_FLAGS_OFF, flags);

    return get_u32(buffer + 0x00) == 0x00001513U &&
           get_u32(buffer + 0x04) == LOOKUP_SEND_SIZE &&
           get_u32(buffer + 0x14) == LOOKUP_REQUEST_ID;
}

static int
extract_server_euid(unsigned char *message,
                    uint32_t reply_size,
                    uid_t *server_euid)
{
    uintptr_t trailer_addr;
    mach_msg_audit_trailer_t *trailer;

    if (message == NULL || server_euid == NULL)
        return 0;

    trailer_addr = (uintptr_t)(message + ((reply_size + 3U) & ~3U));
    trailer = (mach_msg_audit_trailer_t *)trailer_addr;

    if (trailer->msgh_trailer_type != MACH_MSG_TRAILER_FORMAT_0)
        return 0;
    if (trailer->msgh_trailer_size < sizeof(mach_msg_audit_trailer_t))
        return 0;

    *server_euid = (uid_t)trailer->msgh_audit.val[1];
    return 1;
}

static kern_return_t
lion_format_lookup(mach_port_t bp,
                   const char *service_name,
                   mach_port_t *service_port,
                   pid_t target_pid,
                   uint64_t flags)
{
    uint32_t storage[LOOKUP_SEND_SIZE / sizeof(uint32_t)];
    unsigned char *message = (unsigned char *)storage;
    mach_port_t reply_port;
    mach_port_t returned_port;
    mach_msg_return_t mr;
    uint32_t reply_bits;
    uint32_t reply_size;
    uint32_t reply_id;
    uint32_t descriptor_count;
    int32_t retcode;
    uid_t server_euid = (uid_t)-1;

    if (service_port == NULL)
        return MIG_BAD_ARGUMENTS;

    *service_port = MACH_PORT_NULL;

    reply_port = mig_get_reply_port();
    if (reply_port == MACH_PORT_NULL)
        return MIG_NO_REPLY;

    if (!build_lion_lookup_request(message, bp, reply_port,
                                   service_name, target_pid, flags))
        return MIG_BAD_ARGUMENTS;

    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_BOOTSTRAP_ADAPTER_REQUEST:bp=0x%08lx reply=0x%08lx id=0x%08lx send=0x%08lx recv=0x%08lx pid=%ld uuid=ZERO flags=0x%08lx%08lx\n",
            (unsigned long)bp,
            (unsigned long)reply_port,
            (unsigned long)LOOKUP_REQUEST_ID,
            (unsigned long)LOOKUP_SEND_SIZE,
            (unsigned long)LOOKUP_RECV_SIZE,
            (long)target_pid,
            (unsigned long)(uint32_t)(flags >> 32),
            (unsigned long)(uint32_t)flags);
    fflush(stderr);

    mr = call_original_mach_msg((mach_msg_header_t *)message,
                                (mach_msg_option_t)LOOKUP_MSG_OPTIONS,
                                (mach_msg_size_t)LOOKUP_SEND_SIZE,
                                (mach_msg_size_t)LOOKUP_RECV_SIZE,
                                reply_port,
                                MACH_MSG_TIMEOUT_NONE,
                                MACH_PORT_NULL);

    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_BOOTSTRAP_ADAPTER_MACH_MSG:kr=%ld hex=0x%08lx\n",
            (long)mr, (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    reply_bits = get_u32(message + 0x00);
    reply_size = get_u32(message + 0x04);
    reply_id = get_u32(message + 0x14);

    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_BOOTSTRAP_ADAPTER_REPLY:bits=0x%08lx size=0x%08lx id=0x%08lx\n",
            (unsigned long)reply_bits,
            (unsigned long)reply_size,
            (unsigned long)reply_id);
    fflush(stderr);

    if (reply_id != LOOKUP_REPLY_ID)
        return MIG_REPLY_MISMATCH;

    if ((reply_bits & MACH_MSGH_BITS_COMPLEX) == 0) {
        if (reply_size != LOOKUP_ERROR_SIZE)
            return MIG_TYPE_ERROR;

        retcode =
            (int32_t)get_u32(message + LOOKUP_REPLY_RETCODE_OFF);
        return (kern_return_t)retcode;
    }

    descriptor_count =
        get_u32(message + LOOKUP_REPLY_DESC_COUNT_OFF);
    returned_port =
        (mach_port_t)get_u32(message + LOOKUP_REPLY_PORT_OFF);

    if (reply_size != LOOKUP_SUCCESS_SIZE ||
        descriptor_count != 1U ||
        returned_port == MACH_PORT_NULL) {
        if (returned_port != MACH_PORT_NULL)
            (void)mach_port_deallocate(mach_task_self(), returned_port);
        return MIG_TYPE_ERROR;
    }

    if (!extract_server_euid(message, reply_size, &server_euid)) {
        (void)mach_port_deallocate(mach_task_self(), returned_port);
        return MIG_TYPE_ERROR;
    }

    if ((flags & PRIVILEGED_SERVER_FLAG) != 0 &&
        server_euid != 0) {
        (void)mach_port_deallocate(mach_task_self(), returned_port);
        return BOOTSTRAP_NOT_PRIVILEGED;
    }

    *service_port = returned_port;
    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_BOOTSTRAP_ADAPTER_RESULT:LOOKUP_PASS servicePort=0x%08lx serverEuid=%lu\n",
            (unsigned long)returned_port,
            (unsigned long)server_euid);
    fflush(stderr);
    return KERN_SUCCESS;
}

static int
is_servercheckin_candidate(mach_msg_header_t *msg)
{
    unsigned char *m = (unsigned char *)msg;

    if (msg == NULL || gCoreServicesServerPort == MACH_PORT_NULL)
        return 0;

    return get_u32(m + 0x08) == (uint32_t)gCoreServicesServerPort &&
           get_u32(m + 0x14) == CHECKIN_REQUEST_ID;
}

static int
is_exact_legacy_servercheckin(mach_msg_header_t *msg,
                              mach_msg_option_t option,
                              mach_msg_size_t send_size,
                              mach_msg_size_t rcv_size,
                              mach_port_name_t rcv_name,
                              mach_msg_timeout_t timeout,
                              mach_port_name_t notify)
{
    unsigned char *m = (unsigned char *)msg;

    if (!is_servercheckin_candidate(msg))
        return 0;

    if ((uint32_t)option != 0x00000003U ||
        send_size != CHECKIN_LEGACY_SEND_SIZE ||
        rcv_size != CHECKIN_RECV_SIZE ||
        timeout != MACH_MSG_TIMEOUT_NONE ||
        notify != MACH_PORT_NULL)
        return 0;

    if (get_u32(m + 0x00) != CHECKIN_LEGACY_BITS ||
        get_u32(m + 0x04) != CHECKIN_LEGACY_SEND_SIZE ||
        get_u32(m + 0x0c) != (uint32_t)rcv_name ||
        get_u32(m + 0x18) != 1U)
        return 0;

    if (get_u32(m + 0x1c) == (uint32_t)MACH_PORT_NULL ||
        m[0x26] != 0x13 ||
        m[0x27] != 0x00)
        return 0;

    return 1;
}

static mach_msg_return_t
rosetta_mach_msg(mach_msg_header_t *msg,
                 mach_msg_option_t option,
                 mach_msg_size_t send_size,
                 mach_msg_size_t rcv_size,
                 mach_port_name_t rcv_name,
                 mach_msg_timeout_t timeout,
                 mach_port_name_t notify)
{
    const char *mode;
    unsigned char *m = (unsigned char *)msg;
    mach_msg_return_t mr;

    if (is_servercheckin_candidate(msg)) {
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_SERVERCHECKIN_CANDIDATE:bits=0x%08lx headerSize=0x%08lx id=0x%08lx option=0x%08lx send=0x%08lx recv=0x%08lx serverPort=0x%08lx headerReplyPort=0x%08lx receivePort=0x%08lx descriptorCount=%lu descriptorPort=0x%08lx disposition=0x%02x type=0x%02x timeout=0x%08lx notify=0x%08lx\n",
                (unsigned long)get_u32(m + 0x00),
                (unsigned long)get_u32(m + 0x04),
                (unsigned long)get_u32(m + 0x14),
                (unsigned long)(uint32_t)option,
                (unsigned long)send_size,
                (unsigned long)rcv_size,
                (unsigned long)get_u32(m + 0x08),
                (unsigned long)get_u32(m + 0x0c),
                (unsigned long)rcv_name,
                (unsigned long)get_u32(m + 0x18),
                (unsigned long)get_u32(m + 0x1c),
                (unsigned int)m[0x26],
                (unsigned int)m[0x27],
                (unsigned long)timeout,
                (unsigned long)notify);
        fflush(stderr);
    }

    if (!is_exact_legacy_servercheckin(msg, option, send_size,
                                       rcv_size, rcv_name,
                                       timeout, notify)) {
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    ++gServerCheckinExactCallCount;
    mode = getenv(COMPAT_MODE_ENV);

    fprintf(stderr, "%s\n", COMPAT_BUILD_MARKER);
    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_SERVERCHECKIN_EXACT_CALL:index=%u mode=%s serverPort=0x%08lx replyPort=0x%08lx descriptorPort=0x%08lx\n",
            gServerCheckinExactCallCount,
            mode ? mode : "(unset)",
            (unsigned long)gCoreServicesServerPort,
            (unsigned long)rcv_name,
            (unsigned long)get_u32(m + 0x1c));
    fflush(stderr);

    if (mode != NULL && strcmp(mode, COMPAT_MODE_PASSTHROUGH) == 0) {
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_SERVERCHECKIN_PASSTHROUGH:bits=0x%08lx send=0x%08lx recv=0x%08lx\n",
                (unsigned long)get_u32(m + 0x00),
                (unsigned long)send_size,
                (unsigned long)rcv_size);
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    if (mode == NULL || strcmp(mode, COMPAT_MODE_LION_DUAL) != 0)
        return MIG_BAD_ARGUMENTS;

    if (gServerCheckinAdaptedCallCount != 0) {
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_SERVERCHECKIN_ADAPTER_RESULT:SECOND_EXACT_CALL_BLOCKED\n");
        fflush(stderr);
        return MIG_BAD_ARGUMENTS;
    }

    ++gServerCheckinAdaptedCallCount;

    put_u32(m + 0x00, CHECKIN_LION_BITS);
    put_u32(m + 0x04, CHECKIN_LION_SEND_SIZE);

    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_SERVERCHECKIN_ADAPTER_REQUEST:bits=0x%08lx id=0x%08lx legacy_send=0x%08lx adapted_send=0x%08lx recv=0x%08lx\n",
            (unsigned long)get_u32(m + 0x00),
            (unsigned long)get_u32(m + 0x14),
            (unsigned long)send_size,
            (unsigned long)CHECKIN_LION_SEND_SIZE,
            (unsigned long)rcv_size);
    fflush(stderr);

    mr = call_original_mach_msg(msg, option,
                                (mach_msg_size_t)CHECKIN_LION_SEND_SIZE,
                                rcv_size, rcv_name, timeout, notify);

    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_SERVERCHECKIN_ADAPTER_MACH_MSG:kr=%ld hex=0x%08lx\n",
            (long)mr, (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr == MACH_MSG_SUCCESS) {
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_SERVERCHECKIN_ADAPTER_REPLY:bits=0x%08lx size=0x%08lx id=0x%08lx\n",
                (unsigned long)get_u32(m + 0x00),
                (unsigned long)get_u32(m + 0x04),
                (unsigned long)get_u32(m + 0x14));
        fflush(stderr);

        if (get_u32(m + 0x14) == CHECKIN_REPLY_ID &&
            get_u32(m + 0x04) == CHECKIN_SUCCESS_SIZE &&
            (get_u32(m + 0x00) & MACH_MSGH_BITS_COMPLEX) != 0 &&
            get_u32(m + CHECKIN_REPLY_DESC_COUNT_OFF) == 1U &&
            get_u32(m + CHECKIN_REPLY_PORT_OFF) != 0U &&
            m[CHECKIN_REPLY_DISPOSITION_OFF] == 0x11 &&
            m[CHECKIN_REPLY_TYPE_OFF] == 0x00) {
            fprintf(stderr,
                    "PM_CORESERVICES_COMPAT_SERVERCHECKIN_ADAPTER_RESULT:PASS sessionPort=0x%08lx options=0x%08lx\n",
                    (unsigned long)get_u32(m + CHECKIN_REPLY_PORT_OFF),
                    (unsigned long)get_u32(m + CHECKIN_REPLY_OPTIONS_OFF));
            fflush(stderr);
        } else {
            fprintf(stderr,
                    "PM_CORESERVICES_COMPAT_SERVERCHECKIN_ADAPTER_RESULT:REPLY_SHAPE_UNEXPECTED\n");
            fflush(stderr);
        }
    }

    return mr;
}

static kern_return_t
rosetta_bootstrap_look_up2(mach_port_t bp,
                           const char *service_name,
                           mach_port_t *service_port,
                           pid_t target_pid,
                           uint64_t flags)
{
    const char *mode;
    int exact_match;
    kern_return_t kr;

    exact_match = (service_name != NULL &&
                   strcmp(service_name, kCoreServicesDName) == 0 &&
                   target_pid == (pid_t)0 &&
                   flags == PRIVILEGED_SERVER_FLAG);

    if (!exact_match) {
        return call_original_lookup(bp, service_name, service_port,
                                    target_pid, flags, "NON_TARGET");
    }

    ++gBootstrapExactCallCount;
    mode = getenv(COMPAT_MODE_ENV);

    fprintf(stderr, "%s\n", COMPAT_BUILD_MARKER);
    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_BOOTSTRAP_EXACT_CALL:index=%u mode=%s\n",
            gBootstrapExactCallCount,
            mode ? mode : "(unset)");
    fflush(stderr);

    if (mode != NULL && strcmp(mode, COMPAT_MODE_PASSTHROUGH) == 0) {
        kr = call_original_lookup(bp, service_name, service_port,
                                  target_pid, flags,
                                  "SNOW_CONTROL_EXACT_TARGET");
        if (kr == KERN_SUCCESS && service_port != NULL)
            gCoreServicesServerPort = *service_port;
        return kr;
    }

    if (mode == NULL || strcmp(mode, COMPAT_MODE_LION_DUAL) != 0) {
        if (service_port != NULL)
            *service_port = MACH_PORT_NULL;
        return MIG_BAD_ARGUMENTS;
    }

    if (gBootstrapAdaptedCallCount != 0) {
        if (service_port != NULL)
            *service_port = MACH_PORT_NULL;
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_BOOTSTRAP_ADAPTER_RESULT:SECOND_EXACT_CALL_BLOCKED\n");
        fflush(stderr);
        return MIG_BAD_ARGUMENTS;
    }

    ++gBootstrapAdaptedCallCount;
    kr = lion_format_lookup(bp, service_name, service_port,
                            target_pid, flags);
    if (kr == KERN_SUCCESS && service_port != NULL)
        gCoreServicesServerPort = *service_port;
    return kr;
}

__attribute__((used))
static struct interpose_tuple sInterposes[2]
__attribute__((section("__DATA,__interpose"))) = {
    {
        (const void *)(uintptr_t)&rosetta_bootstrap_look_up2,
        (const void *)(uintptr_t)&bootstrap_look_up2
    },
    {
        (const void *)(uintptr_t)&rosetta_mach_msg,
        (const void *)(uintptr_t)&mach_msg
    }
};
