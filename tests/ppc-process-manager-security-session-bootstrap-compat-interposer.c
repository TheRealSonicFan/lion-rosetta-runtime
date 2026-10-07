#include <mach/mach.h>
#include <mach/mig_errors.h>
#include <mach/ndr.h>
#include <servers/bootstrap.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define COMPAT_BUILD_ID "security-session-bootstrap-compat-v1"
#define COMPAT_BUILD_MARKER "PM_SECURITY_COMPAT_BUILD_ID:" COMPAT_BUILD_ID
#define COMPAT_MODE_ENV "ROSETTA_SECURITY_SESSION_COMPAT_MODE"
#define COMPAT_MODE_PASSTHROUGH "passthrough"
#define COMPAT_MODE_LION_BOOTSTRAP "lion-bootstrap-v1"

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

#define UCSP_BASE_ID 0x000003e8U
#define UCSP_LAST_ID 0x00000441U
#define UCSP_SETUP_ID 0x000003e8U
#define UCSP_SETUPNEW_ID 0x000003e9U
#define UCSP_SETUPTHREAD_ID 0x000003eaU
#define UCSP_GETSESSIONINFO_ID 0x00000428U
#define UCSP_VERIFYPRIVILEGED2_ID 0x00000441U

static const char *kSecurityServerName = "com.apple.SecurityServer";

extern mach_port_t mig_get_reply_port(void);

typedef kern_return_t (*bootstrap_lookup_fn)(mach_port_t,
                                             const char *,
                                             mach_port_t *);
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

static kern_return_t rosetta_security_bootstrap_look_up(mach_port_t,
                                                        const char *,
                                                        mach_port_t *);
static mach_msg_return_t rosetta_security_mach_msg(mach_msg_header_t *,
                                                    mach_msg_option_t,
                                                    mach_msg_size_t,
                                                    mach_msg_size_t,
                                                    mach_port_name_t,
                                                    mach_msg_timeout_t,
                                                    mach_port_name_t);

static struct interpose_tuple sInterposes[2];

static bootstrap_lookup_fn gOriginalLookup = NULL;
static mach_msg_fn gOriginalMachMsg = NULL;
static mach_port_t gSecurityServerPort = MACH_PORT_NULL;
static unsigned int gSecurityLookupCount = 0;
static unsigned int gSecurityAdaptedLookupCount = 0;
static unsigned int gSecurityRpcCount = 0;

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

static bootstrap_lookup_fn
original_lookup(void)
{
    if (gOriginalLookup == NULL) {
        gOriginalLookup = (bootstrap_lookup_fn)
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

    if (fn == NULL || fn == (mach_msg_fn)&rosetta_security_mach_msg)
        return MIG_BAD_ID;

    return fn(msg, option, send_size, rcv_size,
              rcv_name, timeout, notify);
}

static const char *
rpc_name(uint32_t id)
{
    switch (id) {
    case UCSP_SETUP_ID:
        return "setup";
    case UCSP_SETUPNEW_ID:
        return "setupNew";
    case UCSP_SETUPTHREAD_ID:
        return "setupThread";
    case UCSP_GETSESSIONINFO_ID:
        return "getSessionInfo";
    case UCSP_VERIFYPRIVILEGED2_ID:
        return "verifyPrivileged2";
    default:
        return "other-ucsp";
    }
}

static int
is_security_rpc(uint32_t id)
{
    return id >= UCSP_BASE_ID && id <= UCSP_LAST_ID;
}

static int
build_lion_lookup_request(unsigned char *buffer,
                          mach_port_t remote_port,
                          mach_port_t reply_port,
                          const char *service_name)
{
    uint32_t bits;
    pid_t target_pid = 0;
    uint64_t flags = 0;

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
           get_u32(buffer + 0x14) == LOOKUP_REQUEST_ID &&
           get_u32(buffer + LOOKUP_FLAGS_OFF) == 0U &&
           get_u32(buffer + LOOKUP_FLAGS_OFF + 4U) == 0U;
}

static kern_return_t
lion_format_security_lookup(mach_port_t bp,
                            const char *service_name,
                            mach_port_t *service_port)
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

    if (service_port == NULL)
        return MIG_BAD_ARGUMENTS;

    *service_port = MACH_PORT_NULL;

    reply_port = mig_get_reply_port();
    if (reply_port == MACH_PORT_NULL)
        return MIG_NO_REPLY;

    if (!build_lion_lookup_request(message, bp, reply_port, service_name))
        return MIG_BAD_ARGUMENTS;

    fprintf(stderr, "%s\n", COMPAT_BUILD_MARKER);
    fprintf(stderr,
            "PM_SECURITY_COMPAT_BOOTSTRAP_ADAPTER_REQUEST:bp=0x%08lx reply=0x%08lx name=%s id=0x%08lx send=0x%08lx recv=0x%08lx pid=0 uuid=ZERO flags=0x0000000000000000\n",
            (unsigned long)bp,
            (unsigned long)reply_port,
            service_name,
            (unsigned long)LOOKUP_REQUEST_ID,
            (unsigned long)LOOKUP_SEND_SIZE,
            (unsigned long)LOOKUP_RECV_SIZE);
    fflush(stderr);

    mr = call_original_mach_msg((mach_msg_header_t *)message,
                                (mach_msg_option_t)LOOKUP_MSG_OPTIONS,
                                (mach_msg_size_t)LOOKUP_SEND_SIZE,
                                (mach_msg_size_t)LOOKUP_RECV_SIZE,
                                reply_port,
                                MACH_MSG_TIMEOUT_NONE,
                                MACH_PORT_NULL);

    fprintf(stderr,
            "PM_SECURITY_COMPAT_BOOTSTRAP_ADAPTER_MACH_MSG:kr=%ld hex=0x%08lx\n",
            (long)mr,
            (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    reply_bits = get_u32(message + 0x00);
    reply_size = get_u32(message + 0x04);
    reply_id = get_u32(message + 0x14);

    fprintf(stderr,
            "PM_SECURITY_COMPAT_BOOTSTRAP_ADAPTER_REPLY:bits=0x%08lx size=0x%08lx id=0x%08lx\n",
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
        fprintf(stderr,
                "PM_SECURITY_COMPAT_BOOTSTRAP_ADAPTER_SIMPLE_REPLY:retcode=%ld hex=0x%08lx\n",
                (long)retcode,
                (unsigned long)(uint32_t)retcode);
        fflush(stderr);
        return (kern_return_t)retcode;
    }

    descriptor_count =
        get_u32(message + LOOKUP_REPLY_DESC_COUNT_OFF);
    returned_port =
        (mach_port_t)get_u32(message + LOOKUP_REPLY_PORT_OFF);

    fprintf(stderr,
            "PM_SECURITY_COMPAT_BOOTSTRAP_ADAPTER_COMPLEX_REPLY:descriptor_count=%lu servicePort=0x%08lx\n",
            (unsigned long)descriptor_count,
            (unsigned long)returned_port);
    fflush(stderr);

    if (reply_size != LOOKUP_SUCCESS_SIZE ||
        descriptor_count != 1U ||
        returned_port == MACH_PORT_NULL) {
        if (returned_port != MACH_PORT_NULL)
            (void)mach_port_deallocate(mach_task_self(), returned_port);
        return MIG_TYPE_ERROR;
    }

    *service_port = returned_port;
    fprintf(stderr,
            "PM_SECURITY_COMPAT_BOOTSTRAP_ADAPTER_RESULT:PASS servicePort=0x%08lx\n",
            (unsigned long)returned_port);
    fflush(stderr);
    return KERN_SUCCESS;
}

static kern_return_t
call_original_lookup(mach_port_t bp,
                     const char *service_name,
                     mach_port_t *service_port)
{
    bootstrap_lookup_fn fn = original_lookup();
    kern_return_t kr;

    if (fn == NULL ||
        fn == (bootstrap_lookup_fn)&rosetta_security_bootstrap_look_up) {
        if (service_port != NULL)
            *service_port = MACH_PORT_NULL;
        return MIG_BAD_ID;
    }

    kr = fn(bp, service_name, service_port);

    fprintf(stderr,
            "PM_SECURITY_COMPAT_BOOTSTRAP_PASSTHROUGH_RETURN:kr=%ld hex=0x%08lx servicePort=0x%08lx\n",
            (long)kr,
            (unsigned long)(uint32_t)kr,
            (unsigned long)((service_port != NULL) ?
                            *service_port : MACH_PORT_NULL));
    fflush(stderr);

    return kr;
}

static kern_return_t
rosetta_security_bootstrap_look_up(mach_port_t bp,
                                   const char *service_name,
                                   mach_port_t *service_port)
{
    const char *mode;
    int target;
    kern_return_t kr;

    target = service_name != NULL &&
             strcmp(service_name, kSecurityServerName) == 0;

    if (!target)
        return call_original_lookup(bp, service_name, service_port);

    ++gSecurityLookupCount;
    mode = getenv(COMPAT_MODE_ENV);

    fprintf(stderr, "%s\n", COMPAT_BUILD_MARKER);
    fprintf(stderr,
            "PM_SECURITY_COMPAT_BOOTSTRAP_EXACT_CALL:index=%u mode=%s bp=0x%08lx name=%s\n",
            gSecurityLookupCount,
            mode ? mode : "(unset)",
            (unsigned long)bp,
            service_name);
    fflush(stderr);

    if (mode != NULL && strcmp(mode, COMPAT_MODE_PASSTHROUGH) == 0) {
        kr = call_original_lookup(bp, service_name, service_port);
        if (kr == KERN_SUCCESS && service_port != NULL)
            gSecurityServerPort = *service_port;
        return kr;
    }

    if (mode == NULL || strcmp(mode, COMPAT_MODE_LION_BOOTSTRAP) != 0) {
        if (service_port != NULL)
            *service_port = MACH_PORT_NULL;
        return MIG_BAD_ARGUMENTS;
    }

    if (gSecurityAdaptedLookupCount != 0) {
        if (service_port != NULL)
            *service_port = MACH_PORT_NULL;
        fprintf(stderr,
                "PM_SECURITY_COMPAT_BOOTSTRAP_ADAPTER_RESULT:SECOND_EXACT_CALL_BLOCKED\n");
        fflush(stderr);
        return MIG_BAD_ARGUMENTS;
    }

    ++gSecurityAdaptedLookupCount;
    kr = lion_format_security_lookup(bp, service_name, service_port);
    if (kr == KERN_SUCCESS && service_port != NULL)
        gSecurityServerPort = *service_port;
    return kr;
}

static mach_msg_return_t
rosetta_security_mach_msg(mach_msg_header_t *msg,
                          mach_msg_option_t option,
                          mach_msg_size_t send_size,
                          mach_msg_size_t rcv_size,
                          mach_port_name_t rcv_name,
                          mach_msg_timeout_t timeout,
                          mach_port_name_t notify)
{
    mach_msg_return_t mr;
    uint32_t request_id = 0;
    uint32_t remote_port = 0;
    uint32_t request_bits = 0;
    uint32_t header_size = 0;
    int target = 0;
    unsigned int index = 0;

    if (msg != NULL && send_size >= sizeof(mach_msg_header_t)) {
        request_id = (uint32_t)msg->msgh_id;
        remote_port = (uint32_t)msg->msgh_remote_port;
        request_bits = (uint32_t)msg->msgh_bits;
        header_size = (uint32_t)msg->msgh_size;

        target = gSecurityServerPort != MACH_PORT_NULL &&
                 remote_port == (uint32_t)gSecurityServerPort &&
                 is_security_rpc(request_id);
    }

    if (target) {
        index = ++gSecurityRpcCount;
        fprintf(stderr, "%s\n", COMPAT_BUILD_MARKER);
        fprintf(stderr,
                "PM_SECURITY_COMPAT_RPC_REQUEST:index=%u name=%s id=0x%08lx remote=0x%08lx bits=0x%08lx headerSizeObserved=0x%08lx option=0x%08lx send=0x%08lx recv=0x%08lx receivePort=0x%08lx timeout=0x%08lx notify=0x%08lx\n",
                index,
                rpc_name(request_id),
                (unsigned long)request_id,
                (unsigned long)remote_port,
                (unsigned long)request_bits,
                (unsigned long)header_size,
                (unsigned long)(uint32_t)option,
                (unsigned long)send_size,
                (unsigned long)rcv_size,
                (unsigned long)rcv_name,
                (unsigned long)timeout,
                (unsigned long)notify);
        fflush(stderr);
    }

    mr = call_original_mach_msg(msg, option, send_size, rcv_size,
                                rcv_name, timeout, notify);

    if (target) {
        fprintf(stderr,
                "PM_SECURITY_COMPAT_RPC_MACH_RETURN:index=%u name=%s id=0x%08lx kr=%ld hex=0x%08lx\n",
                index,
                rpc_name(request_id),
                (unsigned long)request_id,
                (long)mr,
                (unsigned long)(uint32_t)mr);

        if (mr == MACH_MSG_SUCCESS && msg != NULL) {
            uint32_t reply_bits = (uint32_t)msg->msgh_bits;
            uint32_t reply_size = (uint32_t)msg->msgh_size;
            uint32_t reply_id = (uint32_t)msg->msgh_id;

            fprintf(stderr,
                    "PM_SECURITY_COMPAT_RPC_REPLY:index=%u name=%s requestId=0x%08lx bits=0x%08lx size=0x%08lx replyId=0x%08lx",
                    index,
                    rpc_name(request_id),
                    (unsigned long)request_id,
                    (unsigned long)reply_bits,
                    (unsigned long)reply_size,
                    (unsigned long)reply_id);

            if ((reply_bits & MACH_MSGH_BITS_COMPLEX) == 0 &&
                reply_size >= 0x24U) {
                int32_t word20 =
                    (int32_t)get_u32(((unsigned char *)msg) + 0x20U);
                fprintf(stderr,
                        " word0x20=%ld word0x20Hex=0x%08lx",
                        (long)word20,
                        (unsigned long)(uint32_t)word20);
                if (reply_size == 0x24U)
                    fprintf(stderr, " simpleMigErrorReply=YES");
            }
            fprintf(stderr, "\n");
        }
        fflush(stderr);
    }

    return mr;
}

__attribute__((used))
static struct interpose_tuple sInterposes[2]
__attribute__((section("__DATA,__interpose"))) = {
    {
        (const void *)(uintptr_t)&rosetta_security_bootstrap_look_up,
        (const void *)(uintptr_t)&bootstrap_look_up
    },
    {
        (const void *)(uintptr_t)&rosetta_security_mach_msg,
        (const void *)(uintptr_t)&mach_msg
    }
};
