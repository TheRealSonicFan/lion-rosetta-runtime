#include <mach/mach.h>
#include <mach/mig_errors.h>
#include <servers/bootstrap.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define TRACE_BUILD_ID "security-session-rpc-trace-v1"
#define TRACE_BUILD_MARKER "PM_SECURITY_SESSION_TRACE_BUILD_ID:" TRACE_BUILD_ID

#define UCSP_BASE_ID 0x000003e8U
#define UCSP_LAST_ID 0x00000441U

#define UCSP_SETUP_ID 0x000003e8U
#define UCSP_SETUPNEW_ID 0x000003e9U
#define UCSP_SETUPTHREAD_ID 0x000003eaU
#define UCSP_GETSESSIONINFO_ID 0x00000428U
#define UCSP_VERIFYPRIVILEGED2_ID 0x00000441U

static const char *kSecurityServerName = "com.apple.SecurityServer";

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
static unsigned int gSecurityRpcCount = 0;

static uint32_t
get_u32(const unsigned char *p)
{
    uint32_t value;
    memcpy(&value, p, sizeof(value));
    return value;
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
is_known_security_rpc(uint32_t id)
{
    return id == UCSP_SETUP_ID ||
           id == UCSP_SETUPNEW_ID ||
           id == UCSP_SETUPTHREAD_ID ||
           id == UCSP_GETSESSIONINFO_ID ||
           id == UCSP_VERIFYPRIVILEGED2_ID;
}

static kern_return_t
rosetta_security_bootstrap_look_up(mach_port_t bp,
                                   const char *service_name,
                                   mach_port_t *service_port)
{
    bootstrap_lookup_fn fn = original_lookup();
    kern_return_t kr;
    int target;

    if (fn == NULL ||
        fn == (bootstrap_lookup_fn)&rosetta_security_bootstrap_look_up) {
        if (service_port != NULL)
            *service_port = MACH_PORT_NULL;
        return MIG_BAD_ID;
    }

    target = service_name != NULL &&
             strcmp(service_name, kSecurityServerName) == 0;

    if (target) {
        ++gSecurityLookupCount;
        fprintf(stderr, "%s\n", TRACE_BUILD_MARKER);
        fprintf(stderr,
                "PM_SECURITY_SESSION_TRACE_BOOTSTRAP_REQUEST:index=%u bp=0x%08lx name=%s\n",
                gSecurityLookupCount,
                (unsigned long)bp,
                service_name);
        fflush(stderr);
    }

    kr = fn(bp, service_name, service_port);

    if (target) {
        if (kr == KERN_SUCCESS && service_port != NULL)
            gSecurityServerPort = *service_port;
        fprintf(stderr,
                "PM_SECURITY_SESSION_TRACE_BOOTSTRAP_REPLY:index=%u kr=%ld hex=0x%08lx servicePort=0x%08lx\n",
                gSecurityLookupCount,
                (long)kr,
                (unsigned long)(uint32_t)kr,
                (unsigned long)((service_port != NULL) ?
                                *service_port : MACH_PORT_NULL));
        fflush(stderr);
    }

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
    mach_msg_fn fn = original_mach_msg();
    mach_msg_return_t mr;
    uint32_t request_id = 0;
    uint32_t remote_port = 0;
    uint32_t request_bits = 0;
    uint32_t header_size = 0;
    int target = 0;
    unsigned int index = 0;

    if (fn == NULL || fn == (mach_msg_fn)&rosetta_security_mach_msg)
        return MIG_BAD_ID;

    if (msg != NULL && send_size >= sizeof(mach_msg_header_t)) {
        request_id = (uint32_t)msg->msgh_id;
        remote_port = (uint32_t)msg->msgh_remote_port;
        request_bits = (uint32_t)msg->msgh_bits;
        header_size = (uint32_t)msg->msgh_size;

        target = is_known_security_rpc(request_id) ||
                 ((request_id >= UCSP_BASE_ID &&
                   request_id <= UCSP_LAST_ID) &&
                  gSecurityServerPort != MACH_PORT_NULL &&
                  remote_port == (uint32_t)gSecurityServerPort);
    }

    if (target) {
        index = ++gSecurityRpcCount;
        fprintf(stderr, "%s\n", TRACE_BUILD_MARKER);
        fprintf(stderr,
                "PM_SECURITY_SESSION_TRACE_RPC_REQUEST:index=%u name=%s id=0x%08lx remote=0x%08lx bits=0x%08lx headerSizeObserved=0x%08lx option=0x%08lx send=0x%08lx recv=0x%08lx receivePort=0x%08lx timeout=0x%08lx notify=0x%08lx\n",
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

    mr = fn(msg, option, send_size, rcv_size,
            rcv_name, timeout, notify);

    if (target) {
        fprintf(stderr,
                "PM_SECURITY_SESSION_TRACE_RPC_MACH_RETURN:index=%u name=%s id=0x%08lx kr=%ld hex=0x%08lx\n",
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
                    "PM_SECURITY_SESSION_TRACE_RPC_REPLY:index=%u name=%s requestId=0x%08lx bits=0x%08lx size=0x%08lx replyId=0x%08lx",
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
