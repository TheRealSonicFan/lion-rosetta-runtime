#include <mach/mach.h>
#include <mach/mig_errors.h>
#include <mach/ndr.h>
#include <servers/bootstrap.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>

extern mach_port_t bootstrap_port;
extern kern_return_t bootstrap_look_up2(mach_port_t bp,
                                         const char *service_name,
                                         mach_port_t *service_port,
                                         pid_t target_pid,
                                         uint64_t flags);
extern mach_port_t mig_get_reply_port(void);

#define COMPAT_BUILD_ID "interpose-replacee-v3"
#define COMPAT_BUILD_MARKER "PM_BOOTSTRAP_COMPAT_BUILD_ID:" COMPAT_BUILD_ID
#define COMPAT_MODE_ENV "ROSETTA_BOOTSTRAP_COMPAT_MODE"
#define COMPAT_MODE_PASSTHROUGH "passthrough"
#define COMPAT_MODE_LION_ADAPTER "lion-adapter"

#define LION_LOOKUP_REQUEST_ID 0x00000194U
#define LION_LOOKUP_REPLY_ID 0x000001f8U
#define LION_LOOKUP_SEND_SIZE 0x000000bcU
#define LION_LOOKUP_RECV_SIZE 0x0000006cU
#define LION_LOOKUP_SUCCESS_SIZE 0x00000028U
#define LION_LOOKUP_ERROR_SIZE 0x00000024U
#define LION_LOOKUP_SERVICE_OFF 0x20U
#define LION_LOOKUP_PID_OFF 0xa0U
#define LION_LOOKUP_UUID_OFF 0xa4U
#define LION_LOOKUP_FLAGS_OFF 0xb4U
#define LION_LOOKUP_REPLY_DESC_COUNT_OFF 0x18U
#define LION_LOOKUP_REPLY_PORT_OFF 0x1cU
#define LION_LOOKUP_REPLY_RETCODE_OFF 0x20U
#define LION_LOOKUP_MSG_OPTIONS 0x03000003U
#define PRIVILEGED_SERVER_FLAG 0x0000000000000008ULL

static const char *kCoreServicesDName =
    "com.apple.CoreServices.coreservicesd";

typedef kern_return_t (*bootstrap_lookup2_fn)(mach_port_t,
                                              const char *,
                                              mach_port_t *,
                                              pid_t,
                                              uint64_t);

struct bootstrap_interpose_tuple {
    const void *replacement;
    const void *replacee;
};

static struct bootstrap_interpose_tuple sBootstrapLookupInterpose;

static bootstrap_lookup2_fn gOriginalLookup = NULL;
static int gOriginalResolutionLogged = 0;
static unsigned int gExactCallCount = 0;
static unsigned int gAdaptedCallCount = 0;

static kern_return_t
rosetta_bootstrap_look_up2(mach_port_t bp,
                           const char *service_name,
                           mach_port_t *service_port,
                           pid_t target_pid,
                           uint64_t flags);

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
            (uintptr_t)sBootstrapLookupInterpose.replacee;
    }

    if (!gOriginalResolutionLogged) {
        fprintf(stderr,
                "PM_BOOTSTRAP_COMPAT_ORIGINAL_RESOLUTION:source=interpose_replacee original=0x%08lx replacement=0x%08lx\n",
                (unsigned long)(uintptr_t)gOriginalLookup,
                (unsigned long)(uintptr_t)&rosetta_bootstrap_look_up2);
        fflush(stderr);
        gOriginalResolutionLogged = 1;
    }

    return gOriginalLookup;
}

static kern_return_t
call_original(mach_port_t bp,
              const char *service_name,
              mach_port_t *service_port,
              pid_t target_pid,
              uint64_t flags,
              const char *reason)
{
    bootstrap_lookup2_fn fn = original_lookup();
    kern_return_t kr;

    if (fn == NULL || fn == (bootstrap_lookup2_fn)&rosetta_bootstrap_look_up2) {
        if (service_port != NULL)
            *service_port = MACH_PORT_NULL;
        fprintf(stderr,
                "PM_BOOTSTRAP_COMPAT_ORIGINAL_UNAVAILABLE:reason=%s\n",
                reason);
        fflush(stderr);
        return MIG_BAD_ID;
    }

    fprintf(stderr,
            "PM_BOOTSTRAP_COMPAT_PASSTHROUGH:reason=%s name=%s pid=%ld flags=0x%08lx%08lx\n",
            reason,
            service_name ? service_name : "(null)",
            (long)target_pid,
            (unsigned long)(uint32_t)(flags >> 32),
            (unsigned long)(uint32_t)flags);
    fflush(stderr);

    kr = fn(bp, service_name, service_port, target_pid, flags);

    fprintf(stderr,
            "PM_BOOTSTRAP_COMPAT_PASSTHROUGH_RETURN:kr=%ld hex=0x%08lx servicePort=0x%08lx\n",
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

    memset(buffer, 0, LION_LOOKUP_SEND_SIZE);

    bits = (uint32_t)MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND,
                                    MACH_MSG_TYPE_MAKE_SEND_ONCE);

    put_u32(buffer + 0x00, bits);
    put_u32(buffer + 0x04, LION_LOOKUP_SEND_SIZE);
    put_u32(buffer + 0x08, (uint32_t)remote_port);
    put_u32(buffer + 0x0c, (uint32_t)reply_port);
    put_u32(buffer + 0x10, 0);
    put_u32(buffer + 0x14, LION_LOOKUP_REQUEST_ID);
    memcpy(buffer + 0x18, &NDR_record, sizeof(NDR_record));

    strncpy((char *)(buffer + LION_LOOKUP_SERVICE_OFF),
            service_name, 0x7f);
    ((char *)(buffer + LION_LOOKUP_SERVICE_OFF))[0x7f] = '\0';

    memcpy(buffer + LION_LOOKUP_PID_OFF,
           &target_pid, sizeof(target_pid));
    memset(buffer + LION_LOOKUP_UUID_OFF, 0, 16);
    put_u64(buffer + LION_LOOKUP_FLAGS_OFF, flags);

    if (get_u32(buffer + 0x00) != 0x00001513U)
        return 0;
    if (get_u32(buffer + 0x04) != LION_LOOKUP_SEND_SIZE)
        return 0;
    if (get_u32(buffer + 0x14) != LION_LOOKUP_REQUEST_ID)
        return 0;

    return 1;
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
    uint32_t storage[LION_LOOKUP_SEND_SIZE / sizeof(uint32_t)];
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
    if (reply_port == MACH_PORT_NULL) {
        fprintf(stderr,
                "PM_BOOTSTRAP_COMPAT_ADAPTER_RESULT:REPLY_PORT_NULL\n");
        fflush(stderr);
        return MIG_NO_REPLY;
    }

    if (!build_lion_lookup_request(message, bp, reply_port,
                                   service_name, target_pid, flags)) {
        fprintf(stderr,
                "PM_BOOTSTRAP_COMPAT_ADAPTER_RESULT:LAYOUT_BUILD_FAILED\n");
        fflush(stderr);
        return MIG_BAD_ARGUMENTS;
    }

    fprintf(stderr,
            "PM_BOOTSTRAP_COMPAT_ADAPTER_REQUEST:bp=0x%08lx reply=0x%08lx id=0x%08lx send=0x%08lx recv=0x%08lx pid=%ld uuid=ZERO flags=0x%08lx%08lx\n",
            (unsigned long)bp,
            (unsigned long)reply_port,
            (unsigned long)LION_LOOKUP_REQUEST_ID,
            (unsigned long)LION_LOOKUP_SEND_SIZE,
            (unsigned long)LION_LOOKUP_RECV_SIZE,
            (long)target_pid,
            (unsigned long)(uint32_t)(flags >> 32),
            (unsigned long)(uint32_t)flags);
    fflush(stderr);

    mr = mach_msg((mach_msg_header_t *)message,
                  (mach_msg_option_t)LION_LOOKUP_MSG_OPTIONS,
                  (mach_msg_size_t)LION_LOOKUP_SEND_SIZE,
                  (mach_msg_size_t)LION_LOOKUP_RECV_SIZE,
                  reply_port,
                  MACH_MSG_TIMEOUT_NONE,
                  MACH_PORT_NULL);

    fprintf(stderr,
            "PM_BOOTSTRAP_COMPAT_ADAPTER_MACH_MSG:kr=%ld hex=0x%08lx\n",
            (long)mr, (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    reply_bits = get_u32(message + 0x00);
    reply_size = get_u32(message + 0x04);
    reply_id = get_u32(message + 0x14);

    fprintf(stderr,
            "PM_BOOTSTRAP_COMPAT_ADAPTER_REPLY:bits=0x%08lx size=0x%08lx id=0x%08lx\n",
            (unsigned long)reply_bits,
            (unsigned long)reply_size,
            (unsigned long)reply_id);
    fflush(stderr);

    if (reply_id != LION_LOOKUP_REPLY_ID)
        return MIG_REPLY_MISMATCH;

    if ((reply_bits & MACH_MSGH_BITS_COMPLEX) == 0) {
        if (reply_size != LION_LOOKUP_ERROR_SIZE)
            return MIG_TYPE_ERROR;

        retcode = (int32_t)get_u32(message +
                                   LION_LOOKUP_REPLY_RETCODE_OFF);
        fprintf(stderr,
                "PM_BOOTSTRAP_COMPAT_ADAPTER_SERVER_ERROR:retcode=%ld hex=0x%08lx\n",
                (long)retcode, (unsigned long)(uint32_t)retcode);
        fflush(stderr);
        return (kern_return_t)retcode;
    }

    descriptor_count = get_u32(message +
                               LION_LOOKUP_REPLY_DESC_COUNT_OFF);
    returned_port = (mach_port_t)get_u32(message +
                                         LION_LOOKUP_REPLY_PORT_OFF);

    if (reply_size != LION_LOOKUP_SUCCESS_SIZE ||
        descriptor_count != 1 ||
        returned_port == MACH_PORT_NULL) {
        if (returned_port != MACH_PORT_NULL)
            (void)mach_port_deallocate(mach_task_self(),
                                       returned_port);
        return MIG_TYPE_ERROR;
    }

    if (!extract_server_euid(message, reply_size, &server_euid)) {
        (void)mach_port_deallocate(mach_task_self(), returned_port);
        fprintf(stderr,
                "PM_BOOTSTRAP_COMPAT_ADAPTER_RESULT:AUDIT_TRAILER_INVALID\n");
        fflush(stderr);
        return MIG_TYPE_ERROR;
    }

    if ((flags & PRIVILEGED_SERVER_FLAG) != 0 && server_euid != 0) {
        (void)mach_port_deallocate(mach_task_self(), returned_port);
        fprintf(stderr,
                "PM_BOOTSTRAP_COMPAT_ADAPTER_RESULT:SERVER_NOT_PRIVILEGED euid=%lu\n",
                (unsigned long)server_euid);
        fflush(stderr);
        return BOOTSTRAP_NOT_PRIVILEGED;
    }

    *service_port = returned_port;
    fprintf(stderr,
            "PM_BOOTSTRAP_COMPAT_ADAPTER_RESULT:LOOKUP_PASS servicePort=0x%08lx serverEuid=%lu\n",
            (unsigned long)returned_port,
            (unsigned long)server_euid);
    fflush(stderr);
    return KERN_SUCCESS;
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

    exact_match = (service_name != NULL &&
                   strcmp(service_name, kCoreServicesDName) == 0 &&
                   target_pid == (pid_t)0 &&
                   flags == PRIVILEGED_SERVER_FLAG);

    if (!exact_match) {
        return call_original(bp, service_name, service_port,
                             target_pid, flags, "NON_TARGET");
    }

    ++gExactCallCount;
    mode = getenv(COMPAT_MODE_ENV);

    fprintf(stderr, "%s\n", COMPAT_BUILD_MARKER);
    fprintf(stderr,
            "PM_BOOTSTRAP_COMPAT_EXACT_CALL:index=%u mode=%s\n",
            gExactCallCount, mode ? mode : "(unset)");
    fflush(stderr);

    if (mode != NULL && strcmp(mode, COMPAT_MODE_PASSTHROUGH) == 0) {
        return call_original(bp, service_name, service_port,
                             target_pid, flags,
                             "SNOW_CONTROL_EXACT_TARGET");
    }

    if (mode == NULL || strcmp(mode, COMPAT_MODE_LION_ADAPTER) != 0) {
        if (service_port != NULL)
            *service_port = MACH_PORT_NULL;
        fprintf(stderr,
                "PM_BOOTSTRAP_COMPAT_ADAPTER_RESULT:MODE_INVALID\n");
        fflush(stderr);
        return MIG_BAD_ARGUMENTS;
    }

    if (gAdaptedCallCount != 0) {
        if (service_port != NULL)
            *service_port = MACH_PORT_NULL;
        fprintf(stderr,
                "PM_BOOTSTRAP_COMPAT_ADAPTER_RESULT:SECOND_EXACT_CALL_BLOCKED\n");
        fflush(stderr);
        return MIG_BAD_ARGUMENTS;
    }

    ++gAdaptedCallCount;
    return lion_format_lookup(bp, service_name, service_port,
                              target_pid, flags);
}

__attribute__((used))
static struct bootstrap_interpose_tuple sBootstrapLookupInterpose
__attribute__((section("__DATA,__interpose"))) = {
    (const void *)(uintptr_t)&rosetta_bootstrap_look_up2,
    (const void *)(uintptr_t)&bootstrap_look_up2
};
