#include <mach/mach.h>
#include <mach/mig_errors.h>
#include <mach/ndr.h>
#include <servers/bootstrap.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>

extern kern_return_t bootstrap_look_up(mach_port_t,
                                       const char *,
                                       mach_port_t *);
extern mach_port_t mig_get_reply_port(void);

#define COMPAT_BUILD_ID "cgs-session-bootstrap-compat-v1"
#define COMPAT_BUILD_MARKER "PM_CGS_SESSION_BOOTSTRAP_COMPAT_BUILD_ID:" COMPAT_BUILD_ID
#define COMPAT_MODE_ENV "ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE"
#define COMPAT_MODE_PASSTHROUGH "passthrough"
#define COMPAT_MODE_LION "lion-session-port-v1"

#define LION_LOOKUP_REQUEST_ID 0x00000194U
#define LION_LOOKUP_REQUEST_BITS 0x00001513U
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

#define CGS_REQUEST_BITS 0x00001513U
#define CGS_MSG_OPTIONS 0x00000003U
#define CGS_SEND_SIZE 0x00000018U
#define CGS_RECV_SIZE 0x00000030U
#define CGS_SUCCESS_SIZE 0x00000028U
#define CGS_ERROR_SIZE 0x00000024U
#define CGS_GET_SESSION_PORT_REQUEST_ID 0x00007151U
#define CGS_GET_SESSION_PORT_REPLY_ID 0x000071b5U
#define CGS_REPLY_DESC_COUNT_OFF 0x18U
#define CGS_REPLY_PORT_OFF 0x1cU
#define CGS_REPLY_RETCODE_OFF 0x20U
#define CGS_REPLY_DESCRIPTOR_DISPOSITION_OFF 0x26U
#define CGS_REPLY_DESCRIPTOR_TYPE_OFF 0x27U
#define CGS_EXPECTED_PORT_DISPOSITION 0x11U
#define CGS_EXPECTED_PORT_TYPE 0x00U

static const char *kLegacySessionService =
    "com.apple.windowserver.session";
static const char *kLionActiveService =
    "com.apple.windowserver.active";

typedef kern_return_t (*bootstrap_lookup_fn)(mach_port_t,
                                             const char *,
                                             mach_port_t *);

struct interpose_tuple {
    const void *replacement;
    const void *replacee;
};

static kern_return_t rosetta_bootstrap_look_up(mach_port_t,
                                                const char *,
                                                mach_port_t *);
static struct interpose_tuple sInterpose;

static bootstrap_lookup_fn gOriginalLookup = NULL;
static unsigned int gExactCallCount = 0;
static unsigned int gAdaptedCallCount = 0;

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

static uint64_t
get_u64(const unsigned char *p)
{
    uint64_t value;
    memcpy(&value, p, sizeof(value));
    return value;
}

static bootstrap_lookup_fn
original_lookup(void)
{
    if (gOriginalLookup == NULL) {
        gOriginalLookup =
            (bootstrap_lookup_fn)(uintptr_t)sInterpose.replacee;
    }
    return gOriginalLookup;
}

static kern_return_t
call_original_lookup(mach_port_t bp,
                     const char *service_name,
                     mach_port_t *service_port,
                     const char *reason)
{
    bootstrap_lookup_fn fn = original_lookup();
    kern_return_t kr;

    if (service_port != NULL)
        *service_port = MACH_PORT_NULL;

    if (fn == NULL || fn == (bootstrap_lookup_fn)&rosetta_bootstrap_look_up) {
        fprintf(stderr,
                "PM_CGS_SESSION_BOOTSTRAP_COMPAT_ORIGINAL_UNAVAILABLE:reason=%s\n",
                reason != NULL ? reason : "(null)");
        fflush(stderr);
        return MIG_BAD_ID;
    }

    fprintf(stderr,
            "PM_CGS_SESSION_BOOTSTRAP_COMPAT_PASSTHROUGH:reason=%s bp=0x%08lx name=%s\n",
            reason != NULL ? reason : "(null)",
            (unsigned long)bp,
            service_name != NULL ? service_name : "(null)");
    fflush(stderr);

    kr = fn(bp, service_name, service_port);

    fprintf(stderr,
            "PM_CGS_SESSION_BOOTSTRAP_COMPAT_PASSTHROUGH_RETURN:kr=%ld hex=0x%08lx servicePort=0x%08lx\n",
            (long)kr,
            (unsigned long)(uint32_t)kr,
            (unsigned long)((service_port != NULL) ?
                            *service_port : MACH_PORT_NULL));
    fflush(stderr);

    return kr;
}

static int
has_send_right(mach_port_t port)
{
    mach_port_type_t type = 0;
    kern_return_t kr;

    if (port == MACH_PORT_NULL)
        return 0;

    kr = mach_port_type(mach_task_self(), port, &type);
    fprintf(stderr,
            "PM_CGS_SESSION_BOOTSTRAP_COMPAT_RIGHT:port=0x%08lx kr=%ld type=0x%08lx send=%s\n",
            (unsigned long)port,
            (long)kr,
            (unsigned long)type,
            (kr == KERN_SUCCESS && (type & MACH_PORT_TYPE_SEND) != 0) ?
                "YES" : "NO");
    fflush(stderr);

    return kr == KERN_SUCCESS && (type & MACH_PORT_TYPE_SEND) != 0;
}

static int
build_lion_lookup_request(unsigned char *buffer,
                          mach_port_t remote_port,
                          mach_port_t reply_port)
{
    uint32_t bits;
    pid_t target_pid = 0;

    if (buffer == NULL)
        return 0;

    memset(buffer, 0, LION_LOOKUP_SEND_SIZE);

    bits = (uint32_t)MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND,
                                    MACH_MSG_TYPE_MAKE_SEND_ONCE);

    put_u32(buffer + 0x00, bits);
    put_u32(buffer + 0x04, LION_LOOKUP_SEND_SIZE);
    put_u32(buffer + 0x08, (uint32_t)remote_port);
    put_u32(buffer + 0x0c, (uint32_t)reply_port);
    put_u32(buffer + 0x10, 0U);
    put_u32(buffer + 0x14, LION_LOOKUP_REQUEST_ID);
    memcpy(buffer + 0x18, &NDR_record, sizeof(NDR_record));

    strncpy((char *)(buffer + LION_LOOKUP_SERVICE_OFF),
            kLionActiveService, 0x7f);
    ((char *)(buffer + LION_LOOKUP_SERVICE_OFF))[0x7f] = '\0';

    memcpy(buffer + LION_LOOKUP_PID_OFF, &target_pid, sizeof(target_pid));
    memset(buffer + LION_LOOKUP_UUID_OFF, 0, 16);
    put_u64(buffer + LION_LOOKUP_FLAGS_OFF, PRIVILEGED_SERVER_FLAG);

    return get_u32(buffer + 0x00) == LION_LOOKUP_REQUEST_BITS &&
           get_u32(buffer + 0x04) == LION_LOOKUP_SEND_SIZE &&
           get_u32(buffer + 0x14) == LION_LOOKUP_REQUEST_ID &&
           get_u64(buffer + LION_LOOKUP_FLAGS_OFF) ==
               PRIVILEGED_SERVER_FLAG;
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
lookup_lion_root_windowserver(mach_port_t bp,
                              mach_port_t *root_port)
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

    if (root_port == NULL)
        return MIG_BAD_ARGUMENTS;
    *root_port = MACH_PORT_NULL;

    reply_port = mig_get_reply_port();
    if (reply_port == MACH_PORT_NULL)
        return MIG_NO_REPLY;

    if (!build_lion_lookup_request(message, bp, reply_port))
        return MIG_BAD_ARGUMENTS;

    fprintf(stderr,
            "PM_CGS_SESSION_BOOTSTRAP_COMPAT_ROOT_REQUEST:bp=0x%08lx reply=0x%08lx name=%s id=0x%08lx send=0x%08lx recv=0x%08lx pid=0 uuid=ZERO flags=0x%08lx%08lx\n",
            (unsigned long)bp,
            (unsigned long)reply_port,
            kLionActiveService,
            (unsigned long)LION_LOOKUP_REQUEST_ID,
            (unsigned long)LION_LOOKUP_SEND_SIZE,
            (unsigned long)LION_LOOKUP_RECV_SIZE,
            (unsigned long)(uint32_t)(PRIVILEGED_SERVER_FLAG >> 32),
            (unsigned long)(uint32_t)PRIVILEGED_SERVER_FLAG);
    fflush(stderr);

    mr = mach_msg((mach_msg_header_t *)message,
                  (mach_msg_option_t)LION_LOOKUP_MSG_OPTIONS,
                  (mach_msg_size_t)LION_LOOKUP_SEND_SIZE,
                  (mach_msg_size_t)LION_LOOKUP_RECV_SIZE,
                  reply_port,
                  MACH_MSG_TIMEOUT_NONE,
                  MACH_PORT_NULL);

    fprintf(stderr,
            "PM_CGS_SESSION_BOOTSTRAP_COMPAT_ROOT_MACH_RETURN:kr=%ld hex=0x%08lx\n",
            (long)mr,
            (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    reply_bits = get_u32(message + 0x00);
    reply_size = get_u32(message + 0x04);
    reply_id = get_u32(message + 0x14);

    fprintf(stderr,
            "PM_CGS_SESSION_BOOTSTRAP_COMPAT_ROOT_REPLY:bits=0x%08lx size=0x%08lx id=0x%08lx\n",
            (unsigned long)reply_bits,
            (unsigned long)reply_size,
            (unsigned long)reply_id);
    fflush(stderr);

    if (reply_id != LION_LOOKUP_REPLY_ID)
        return MIG_REPLY_MISMATCH;

    if ((reply_bits & MACH_MSGH_BITS_COMPLEX) == 0) {
        if (reply_size != LION_LOOKUP_ERROR_SIZE)
            return MIG_TYPE_ERROR;
        retcode =
            (int32_t)get_u32(message + LION_LOOKUP_REPLY_RETCODE_OFF);
        fprintf(stderr,
                "PM_CGS_SESSION_BOOTSTRAP_COMPAT_ROOT_SIMPLE_REPLY:retcode=%ld hex=0x%08lx\n",
                (long)retcode,
                (unsigned long)(uint32_t)retcode);
        fflush(stderr);
        return (kern_return_t)retcode;
    }

    descriptor_count =
        get_u32(message + LION_LOOKUP_REPLY_DESC_COUNT_OFF);
    returned_port =
        (mach_port_t)get_u32(message + LION_LOOKUP_REPLY_PORT_OFF);

    if (reply_size != LION_LOOKUP_SUCCESS_SIZE ||
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

    fprintf(stderr,
            "PM_CGS_SESSION_BOOTSTRAP_COMPAT_ROOT_COMPLEX_REPLY:descriptor_count=%lu rootPort=0x%08lx serverEuid=%lu\n",
            (unsigned long)descriptor_count,
            (unsigned long)returned_port,
            (unsigned long)server_euid);
    fflush(stderr);

    if (server_euid != 0) {
        (void)mach_port_deallocate(mach_task_self(), returned_port);
        return BOOTSTRAP_NOT_PRIVILEGED;
    }

    if (!has_send_right(returned_port)) {
        (void)mach_port_deallocate(mach_task_self(), returned_port);
        return MIG_TYPE_ERROR;
    }

    *root_port = returned_port;
    fprintf(stderr,
            "PM_CGS_SESSION_BOOTSTRAP_COMPAT_ROOT_RESULT:PASS\n");
    fflush(stderr);
    return KERN_SUCCESS;
}

static kern_return_t
get_lion_session_port(mach_port_t root_port,
                      mach_port_t *session_port)
{
    uint32_t storage[CGS_RECV_SIZE / sizeof(uint32_t)];
    unsigned char *message = (unsigned char *)storage;
    mach_port_t reply_port;
    mach_msg_return_t mr;
    uint32_t reply_bits;
    uint32_t reply_size;
    uint32_t reply_id;
    uint32_t descriptor_count;
    uint32_t disposition;
    uint32_t descriptor_type;
    mach_port_t returned_port;
    int32_t retcode;

    if (root_port == MACH_PORT_NULL || session_port == NULL)
        return MIG_BAD_ARGUMENTS;
    *session_port = MACH_PORT_NULL;

    memset(storage, 0, sizeof(storage));

    reply_port = mig_get_reply_port();
    if (reply_port == MACH_PORT_NULL)
        return MIG_NO_REPLY;

    put_u32(message + 0x00, CGS_REQUEST_BITS);
    put_u32(message + 0x04, CGS_SEND_SIZE);
    put_u32(message + 0x08, (uint32_t)root_port);
    put_u32(message + 0x0c, (uint32_t)reply_port);
    put_u32(message + 0x10, 0U);
    put_u32(message + 0x14, CGS_GET_SESSION_PORT_REQUEST_ID);

    fprintf(stderr,
            "PM_CGS_SESSION_BOOTSTRAP_COMPAT_GETSESSION_REQUEST:root=0x%08lx reply=0x%08lx id=0x%08lx bits=0x%08lx send=0x%08lx recv=0x%08lx options=0x%08lx\n",
            (unsigned long)root_port,
            (unsigned long)reply_port,
            (unsigned long)CGS_GET_SESSION_PORT_REQUEST_ID,
            (unsigned long)CGS_REQUEST_BITS,
            (unsigned long)CGS_SEND_SIZE,
            (unsigned long)CGS_RECV_SIZE,
            (unsigned long)CGS_MSG_OPTIONS);
    fflush(stderr);

    mr = mach_msg((mach_msg_header_t *)message,
                  (mach_msg_option_t)CGS_MSG_OPTIONS,
                  (mach_msg_size_t)CGS_SEND_SIZE,
                  (mach_msg_size_t)CGS_RECV_SIZE,
                  reply_port,
                  MACH_MSG_TIMEOUT_NONE,
                  MACH_PORT_NULL);

    fprintf(stderr,
            "PM_CGS_SESSION_BOOTSTRAP_COMPAT_GETSESSION_MACH_RETURN:kr=%ld hex=0x%08lx\n",
            (long)mr,
            (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    reply_bits = get_u32(message + 0x00);
    reply_size = get_u32(message + 0x04);
    reply_id = get_u32(message + 0x14);

    fprintf(stderr,
            "PM_CGS_SESSION_BOOTSTRAP_COMPAT_GETSESSION_REPLY:bits=0x%08lx size=0x%08lx id=0x%08lx\n",
            (unsigned long)reply_bits,
            (unsigned long)reply_size,
            (unsigned long)reply_id);
    fflush(stderr);

    if (reply_id != CGS_GET_SESSION_PORT_REPLY_ID)
        return MIG_REPLY_MISMATCH;

    if ((reply_bits & MACH_MSGH_BITS_COMPLEX) == 0) {
        if (reply_size != CGS_ERROR_SIZE)
            return MIG_TYPE_ERROR;
        retcode = (int32_t)get_u32(message + CGS_REPLY_RETCODE_OFF);
        fprintf(stderr,
                "PM_CGS_SESSION_BOOTSTRAP_COMPAT_GETSESSION_SIMPLE_REPLY:retcode=%ld hex=0x%08lx\n",
                (long)retcode,
                (unsigned long)(uint32_t)retcode);
        fflush(stderr);
        return (kern_return_t)retcode;
    }

    descriptor_count = get_u32(message + CGS_REPLY_DESC_COUNT_OFF);
    returned_port =
        (mach_port_t)get_u32(message + CGS_REPLY_PORT_OFF);
    disposition =
        (uint32_t)message[CGS_REPLY_DESCRIPTOR_DISPOSITION_OFF];
    descriptor_type =
        (uint32_t)message[CGS_REPLY_DESCRIPTOR_TYPE_OFF];

    fprintf(stderr,
            "PM_CGS_SESSION_BOOTSTRAP_COMPAT_GETSESSION_COMPLEX_REPLY:descriptor_count=%lu sessionPort=0x%08lx disposition=0x%02lx type=0x%02lx\n",
            (unsigned long)descriptor_count,
            (unsigned long)returned_port,
            (unsigned long)disposition,
            (unsigned long)descriptor_type);
    fflush(stderr);

    if (reply_size != CGS_SUCCESS_SIZE ||
        descriptor_count != 1U ||
        returned_port == MACH_PORT_NULL ||
        disposition != CGS_EXPECTED_PORT_DISPOSITION ||
        descriptor_type != CGS_EXPECTED_PORT_TYPE) {
        if (returned_port != MACH_PORT_NULL)
            (void)mach_port_deallocate(mach_task_self(), returned_port);
        return MIG_TYPE_ERROR;
    }

    if (!has_send_right(returned_port)) {
        (void)mach_port_deallocate(mach_task_self(), returned_port);
        return MIG_TYPE_ERROR;
    }

    *session_port = returned_port;
    fprintf(stderr,
            "PM_CGS_SESSION_BOOTSTRAP_COMPAT_GETSESSION_RESULT:PASS\n");
    fflush(stderr);
    return KERN_SUCCESS;
}

static kern_return_t
adapt_session_lookup(mach_port_t bp,
                     mach_port_t *service_port)
{
    mach_port_t root_port = MACH_PORT_NULL;
    mach_port_t session_port = MACH_PORT_NULL;
    kern_return_t kr;

    if (bp == MACH_PORT_NULL || service_port == NULL)
        return MIG_BAD_ARGUMENTS;
    *service_port = MACH_PORT_NULL;

    kr = lookup_lion_root_windowserver(bp, &root_port);
    if (kr != KERN_SUCCESS)
        return kr;

    kr = get_lion_session_port(root_port, &session_port);
    (void)mach_port_deallocate(mach_task_self(), root_port);

    if (kr != KERN_SUCCESS)
        return kr;

    *service_port = session_port;
    return KERN_SUCCESS;
}

static kern_return_t
rosetta_bootstrap_look_up(mach_port_t bp,
                          const char *service_name,
                          mach_port_t *service_port)
{
    const char *mode;
    int exact_match;
    kern_return_t kr;

    exact_match =
        service_name != NULL &&
        strcmp(service_name, kLegacySessionService) == 0;

    if (!exact_match) {
        return call_original_lookup(bp, service_name, service_port,
                                    "NON_TARGET");
    }

    ++gExactCallCount;
    mode = getenv(COMPAT_MODE_ENV);

    fprintf(stderr, "%s\n", COMPAT_BUILD_MARKER);
    fprintf(stderr,
            "PM_CGS_SESSION_BOOTSTRAP_COMPAT_CALL:index=%u mode=%s bp=0x%08lx name=%s\n",
            gExactCallCount,
            mode != NULL ? mode : "(unset)",
            (unsigned long)bp,
            service_name);
    fflush(stderr);

    if (mode != NULL && strcmp(mode, COMPAT_MODE_PASSTHROUGH) == 0) {
        return call_original_lookup(bp, service_name, service_port,
                                    "SNOW_EXACT_TARGET");
    }

    if (mode == NULL || strcmp(mode, COMPAT_MODE_LION) != 0) {
        if (service_port != NULL)
            *service_port = MACH_PORT_NULL;
        fprintf(stderr,
                "PM_CGS_SESSION_BOOTSTRAP_COMPAT_RESULT:MODE_REJECTED\n");
        fflush(stderr);
        return MIG_BAD_ARGUMENTS;
    }

    ++gAdaptedCallCount;
    kr = adapt_session_lookup(bp, service_port);

    fprintf(stderr,
            "PM_CGS_SESSION_BOOTSTRAP_COMPAT_ADAPTER_RETURN:index=%u kr=%ld hex=0x%08lx sessionPort=0x%08lx\n",
            gAdaptedCallCount,
            (long)kr,
            (unsigned long)(uint32_t)kr,
            (unsigned long)((service_port != NULL) ?
                            *service_port : MACH_PORT_NULL));
    fflush(stderr);

    if (kr == KERN_SUCCESS &&
        service_port != NULL &&
        *service_port != MACH_PORT_NULL) {
        fprintf(stderr,
                "PM_CGS_SESSION_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS\n");
        fflush(stderr);
    } else {
        fprintf(stderr,
                "PM_CGS_SESSION_BOOTSTRAP_COMPAT_RESULT:ADAPTER_FAIL\n");
        fflush(stderr);
    }

    return kr;
}

__attribute__((used))
static struct interpose_tuple sInterpose
__attribute__((section("__DATA,__interpose"))) = {
    (const void *)(uintptr_t)&rosetta_bootstrap_look_up,
    (const void *)(uintptr_t)&bootstrap_look_up
};
