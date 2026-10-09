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

#if defined(PM_CPS_REGISTRATION_TRACE)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-trace-v1"
#elif defined(PM_CGS_SERVER_VERSION_COMPAT_INTEGRATION)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-v1"
#elif defined(PM_CGS_CONNECTION_TRACE)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-trace-v2"
#else
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5"
#endif
#define COMPAT_BUILD_MARKER "PM_CORESERVICES_COMPAT_BUILD_ID:" COMPAT_BUILD_ID
#define COMPAT_MODE_ENV "ROSETTA_CORESERVICES_COMPAT_MODE"
#define COMPAT_MODE_PASSTHROUGH "passthrough"
#define COMPAT_MODE_LION_DUAL "lion-dual-adapter"
#define COMPAT_MODE_LION_SESSIONINIT "lion-dual-sessioninit-adapter"

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


#define SESSIONINIT_REQUEST_ID 0x00002712U
#define SESSIONINIT_REPLY_ID 0x00002776U
#define SESSIONINIT_BITS 0x00001513U
#define SESSIONINIT_LEGACY_SEND_SIZE 0x0000002cU
#define SESSIONINIT_LION_SEND_SIZE 0x00000028U
#define SESSIONINIT_RECV_SIZE 0x00000034U
#define SESSIONINIT_ERROR_SIZE 0x00000024U
#define SESSIONINIT_SUCCESS_SIZE 0x0000002cU
#define SESSIONINIT_NDR_OFF 0x18U
#define SESSIONINIT_LEGACY_PID_OFF 0x20U
#define SESSIONINIT_LEGACY_UID_OFF 0x24U
#define SESSIONINIT_LEGACY_LAYOUT_OFF 0x28U
#define SESSIONINIT_LION_UID_OFF 0x20U
#define SESSIONINIT_LION_LAYOUT_OFF 0x24U
#define SESSIONINIT_REPLY_RETCODE_OFF 0x20U

#define PRIVILEGED_SERVER_FLAG 0x0000000000000008ULL

#if defined(PM_CGS_CONNECTION_TRACE) || defined(PM_CGS_SERVER_VERSION_COMPAT_INTEGRATION)
#define CGS_SERVER_VERSION_REQUEST_ID 0x00007148U
#define CGS_SERVER_VERSION_REPLY_ID 0x000071acU
#define CGS_DEATHWATCH_REQUEST_ID 0x0000714cU
#define CGS_DEATHWATCH_REPLY_ID 0x000071b0U
#define CGS_NEW_CONNECTION_REQUEST_ID 0x00007469U
#define CGS_NEW_CONNECTION_REPLY_ID 0x000074cdU
#ifdef PM_CPS_REGISTRATION_TRACE
#define CGS_CHECKIN_APPLICATION_REQUEST_ID 0x00007372U
#define CGS_CHECKIN_APPLICATION_REPLY_ID 0x000073d6U
#define CGS_CREATE_APPLICATION_REQUEST_ID 0x000073c1U
#define CGS_CREATE_APPLICATION_REPLY_ID 0x00007425U
#endif
#endif

#ifdef PM_CGS_SERVER_VERSION_COMPAT_INTEGRATION
#define CGS_SERVER_VERSION_COMPAT_ENV "ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE"
#define CGS_SERVER_VERSION_COMPAT_PASSTHROUGH "passthrough"
#define CGS_SERVER_VERSION_COMPAT_LION_V1 "lion-server-version-v1"
#define CGS_SERVER_VERSION_REPLY_SIZE 0x00000040U
#define CGS_SERVER_VERSION_REPLY_DESC_COUNT_OFF 0x18U
#define CGS_SERVER_VERSION_REPLY_PORT_OFF 0x1cU
#define CGS_SERVER_VERSION_REPLY_DISPOSITION_OFF 0x26U
#define CGS_SERVER_VERSION_REPLY_TYPE_OFF 0x27U
#define CGS_SERVER_VERSION_REPLY_NDR_OFF 0x28U
#define CGS_SERVER_VERSION_REPLY_MAJOR_OFF 0x30U
#define CGS_SERVER_VERSION_REPLY_MINOR_OFF 0x34U
#define CGS_SERVER_VERSION_REPLY_AUX_OFF 0x38U
#define CGS_SERVER_VERSION_REPLY_FLAGS_OFF 0x3cU
#define CGS_SERVER_VERSION_EXPECTED_DISPOSITION 0x11U
#define CGS_SERVER_VERSION_EXPECTED_TYPE 0x00U
#define CGS_SERVER_VERSION_LION_MAJOR 600U
#define CGS_SERVER_VERSION_LION_MINOR 0U
#define CGS_SERVER_VERSION_SNOW_MAJOR 545U
#define CGS_SERVER_VERSION_SNOW_MINOR 0U
#define CGS_SERVER_VERSION_EXPECTED_AUX 0x69333836U
#define CGS_SERVER_VERSION_EXPECTED_FLAGS 0x00000001U
#endif

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
static unsigned int gSessionInitExactCallCount = 0;
static unsigned int gSessionInitAdaptedCallCount = 0;
#if defined(PM_CGS_CONNECTION_TRACE) || defined(PM_CGS_SERVER_VERSION_COMPAT_INTEGRATION)
static unsigned int gCGSTraceCallCount = 0;
#endif
#ifdef PM_CGS_SERVER_VERSION_COMPAT_INTEGRATION
static unsigned int gCGSServerVersionCompatCallCount = 0;
#endif
static mach_port_t gCoreServicesServerPort = MACH_PORT_NULL;
static mach_port_t gServerCheckinReplyPort = MACH_PORT_NULL;

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

#ifdef PM_CGS_SERVER_VERSION_COMPAT_INTEGRATION
static uint32_t
swap_u32(uint32_t value)
{
    return ((value & 0x000000ffU) << 24) |
           ((value & 0x0000ff00U) << 8) |
           ((value & 0x00ff0000U) >> 8) |
           ((value & 0xff000000U) >> 24);
}

static int
cgs_server_version_reply_is_swapped(const unsigned char *message)
{
    const unsigned char *local_ndr = (const unsigned char *)&NDR_record;

    return message[CGS_SERVER_VERSION_REPLY_NDR_OFF + 4U] !=
           local_ndr[4];
}

static uint32_t
decode_cgs_server_version_u32(const unsigned char *message, uint32_t off)
{
    uint32_t value = get_u32(message + off);

    if (cgs_server_version_reply_is_swapped(message))
        value = swap_u32(value);
    return value;
}

static void
encode_cgs_server_version_u32(unsigned char *message,
                              uint32_t off,
                              uint32_t value)
{
    if (cgs_server_version_reply_is_swapped(message))
        value = swap_u32(value);
    put_u32(message + off, value);
}

static void
maybe_normalize_cgs_server_version_reply(unsigned char *message,
                                         uint32_t request_id,
                                         int request_exact,
                                         mach_msg_size_t rcv_size,
                                         mach_msg_return_t mr,
                                         uint32_t reply_bits,
                                         uint32_t reply_size,
                                         uint32_t reply_id)
{
    const char *mode;
    unsigned char before[CGS_SERVER_VERSION_REPLY_SIZE];
    uint32_t descriptor_count;
    mach_port_t descriptor_port;
    uint32_t disposition;
    uint32_t descriptor_type;
    uint32_t major;
    uint32_t minor;
    uint32_t aux;
    uint32_t flags;
    unsigned int changed = 0;
    unsigned int outside_changed = 0;
    unsigned int off;

    if (request_id != CGS_SERVER_VERSION_REQUEST_ID ||
        mr != MACH_MSG_SUCCESS)
        return;

    ++gCGSServerVersionCompatCallCount;
    mode = getenv(CGS_SERVER_VERSION_COMPAT_ENV);

    if (!request_exact ||
        rcv_size < CGS_SERVER_VERSION_REPLY_SIZE ||
        (reply_bits & MACH_MSGH_BITS_COMPLEX) == 0 ||
        reply_size != CGS_SERVER_VERSION_REPLY_SIZE ||
        reply_id != CGS_SERVER_VERSION_REPLY_ID) {
        fprintf(stderr,
                "PM_CGS_SERVER_VERSION_COMPAT_RESULT:REQUEST_OR_REPLY_ENVELOPE_REJECTED index=%u mode=%s requestExact=%s replyBits=0x%08lx replySize=0x%08lx replyId=0x%08lx recv=0x%08lx\n",
                gCGSServerVersionCompatCallCount,
                mode ? mode : "(unset)",
                request_exact ? "YES" : "NO",
                (unsigned long)reply_bits,
                (unsigned long)reply_size,
                (unsigned long)reply_id,
                (unsigned long)rcv_size);
        fflush(stderr);
        return;
    }

    descriptor_count =
        get_u32(message + CGS_SERVER_VERSION_REPLY_DESC_COUNT_OFF);
    descriptor_port =
        (mach_port_t)get_u32(message + CGS_SERVER_VERSION_REPLY_PORT_OFF);
    disposition =
        (uint32_t)message[CGS_SERVER_VERSION_REPLY_DISPOSITION_OFF];
    descriptor_type =
        (uint32_t)message[CGS_SERVER_VERSION_REPLY_TYPE_OFF];

    major = decode_cgs_server_version_u32(
        message, CGS_SERVER_VERSION_REPLY_MAJOR_OFF);
    minor = decode_cgs_server_version_u32(
        message, CGS_SERVER_VERSION_REPLY_MINOR_OFF);
    aux = decode_cgs_server_version_u32(
        message, CGS_SERVER_VERSION_REPLY_AUX_OFF);
    flags = decode_cgs_server_version_u32(
        message, CGS_SERVER_VERSION_REPLY_FLAGS_OFF);

    fprintf(stderr,
            "PM_CGS_SERVER_VERSION_COMPAT_CALL:index=%u mode=%s replyBits=0x%08lx replySize=0x%08lx replyId=0x%08lx descriptorCount=%lu descriptorPort=0x%08lx disposition=0x%02lx type=0x%02lx ndrSwapped=%s major=%lu minor=%lu aux=0x%08lx flags=0x%08lx\n",
            gCGSServerVersionCompatCallCount,
            mode ? mode : "(unset)",
            (unsigned long)reply_bits,
            (unsigned long)reply_size,
            (unsigned long)reply_id,
            (unsigned long)descriptor_count,
            (unsigned long)descriptor_port,
            (unsigned long)disposition,
            (unsigned long)descriptor_type,
            cgs_server_version_reply_is_swapped(message) ? "YES" : "NO",
            (unsigned long)major,
            (unsigned long)minor,
            (unsigned long)aux,
            (unsigned long)flags);
    fflush(stderr);

    if (mode != NULL &&
        strcmp(mode, CGS_SERVER_VERSION_COMPAT_PASSTHROUGH) == 0) {
        fprintf(stderr,
                "PM_CGS_SERVER_VERSION_COMPAT_RESULT:PASSTHROUGH major=%lu minor=%lu\n",
                (unsigned long)major,
                (unsigned long)minor);
        fflush(stderr);
        return;
    }

    if (mode == NULL ||
        strcmp(mode, CGS_SERVER_VERSION_COMPAT_LION_V1) != 0) {
        fprintf(stderr,
                "PM_CGS_SERVER_VERSION_COMPAT_RESULT:MODE_REJECTED\n");
        fflush(stderr);
        return;
    }

    if (gCGSServerVersionCompatCallCount != 1U ||
        descriptor_count != 1U ||
        descriptor_port == MACH_PORT_NULL ||
        disposition != CGS_SERVER_VERSION_EXPECTED_DISPOSITION ||
        descriptor_type != CGS_SERVER_VERSION_EXPECTED_TYPE ||
        !cgs_server_version_reply_is_swapped(message) ||
        major != CGS_SERVER_VERSION_LION_MAJOR ||
        minor != CGS_SERVER_VERSION_LION_MINOR ||
        aux != CGS_SERVER_VERSION_EXPECTED_AUX ||
        flags != CGS_SERVER_VERSION_EXPECTED_FLAGS) {
        fprintf(stderr,
                "PM_CGS_SERVER_VERSION_COMPAT_RESULT:SHAPE_OR_VALUE_REJECTED\n");
        fflush(stderr);
        return;
    }

    memcpy(before, message, CGS_SERVER_VERSION_REPLY_SIZE);

    encode_cgs_server_version_u32(
        message,
        CGS_SERVER_VERSION_REPLY_MAJOR_OFF,
        CGS_SERVER_VERSION_SNOW_MAJOR);
    encode_cgs_server_version_u32(
        message,
        CGS_SERVER_VERSION_REPLY_MINOR_OFF,
        CGS_SERVER_VERSION_SNOW_MINOR);

    for (off = 0U; off < CGS_SERVER_VERSION_REPLY_SIZE; ++off) {
        if (before[off] != message[off]) {
            ++changed;
            if (off < CGS_SERVER_VERSION_REPLY_MAJOR_OFF ||
                off >= CGS_SERVER_VERSION_REPLY_MINOR_OFF + 4U)
                ++outside_changed;
        }
    }

    major = decode_cgs_server_version_u32(
        message, CGS_SERVER_VERSION_REPLY_MAJOR_OFF);
    minor = decode_cgs_server_version_u32(
        message, CGS_SERVER_VERSION_REPLY_MINOR_OFF);

    if (changed == 0U ||
        outside_changed != 0U ||
        major != CGS_SERVER_VERSION_SNOW_MAJOR ||
        minor != CGS_SERVER_VERSION_SNOW_MINOR ||
        get_u32(message + CGS_SERVER_VERSION_REPLY_DESC_COUNT_OFF) !=
            get_u32(before + CGS_SERVER_VERSION_REPLY_DESC_COUNT_OFF) ||
        get_u32(message + CGS_SERVER_VERSION_REPLY_PORT_OFF) !=
            get_u32(before + CGS_SERVER_VERSION_REPLY_PORT_OFF) ||
        message[CGS_SERVER_VERSION_REPLY_DISPOSITION_OFF] !=
            before[CGS_SERVER_VERSION_REPLY_DISPOSITION_OFF] ||
        message[CGS_SERVER_VERSION_REPLY_TYPE_OFF] !=
            before[CGS_SERVER_VERSION_REPLY_TYPE_OFF] ||
        decode_cgs_server_version_u32(
            message, CGS_SERVER_VERSION_REPLY_AUX_OFF) != aux ||
        decode_cgs_server_version_u32(
            message, CGS_SERVER_VERSION_REPLY_FLAGS_OFF) != flags) {
        memcpy(message, before, CGS_SERVER_VERSION_REPLY_SIZE);
        fprintf(stderr,
                "PM_CGS_SERVER_VERSION_COMPAT_RESULT:POSTCHECK_FAILED_RESTORED\n");
        fflush(stderr);
        return;
    }

    fprintf(stderr,
            "PM_CGS_SERVER_VERSION_COMPAT_ADAPTER:index=%u originalMajor=%lu originalMinor=%lu adaptedMajor=%lu adaptedMinor=%lu changedBytes=%u outsideVersionBytesChanged=%u raw30Before=0x%08lx raw30After=0x%08lx raw34Before=0x%08lx raw34After=0x%08lx\n",
            gCGSServerVersionCompatCallCount,
            (unsigned long)CGS_SERVER_VERSION_LION_MAJOR,
            (unsigned long)CGS_SERVER_VERSION_LION_MINOR,
            (unsigned long)major,
            (unsigned long)minor,
            changed,
            outside_changed,
            (unsigned long)get_u32(
                before + CGS_SERVER_VERSION_REPLY_MAJOR_OFF),
            (unsigned long)get_u32(
                message + CGS_SERVER_VERSION_REPLY_MAJOR_OFF),
            (unsigned long)get_u32(
                before + CGS_SERVER_VERSION_REPLY_MINOR_OFF),
            (unsigned long)get_u32(
                message + CGS_SERVER_VERSION_REPLY_MINOR_OFF));
    fprintf(stderr,
            "PM_CGS_SERVER_VERSION_COMPAT_RESULT:ADAPTER_PASS\n");
    fflush(stderr);
}
#endif

static int
is_lion_compat_mode(const char *mode)
{
    return mode != NULL &&
           (strcmp(mode, COMPAT_MODE_LION_DUAL) == 0 ||
            strcmp(mode, COMPAT_MODE_LION_SESSIONINIT) == 0);
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

#if defined(PM_CGS_CONNECTION_TRACE) || defined(PM_CGS_SERVER_VERSION_COMPAT_INTEGRATION)
static const char *
cgs_trace_kind(uint32_t request_id)
{
    if (request_id == CGS_SERVER_VERSION_REQUEST_ID)
        return "SERVER_VERSION";
    if (request_id == CGS_DEATHWATCH_REQUEST_ID)
        return "DEATHWATCH";
    if (request_id == CGS_NEW_CONNECTION_REQUEST_ID)
        return "NEW_CONNECTION";
#ifdef PM_CPS_REGISTRATION_TRACE
    if (request_id == CGS_CHECKIN_APPLICATION_REQUEST_ID)
        return "CPS_CHECKIN_APPLICATION";
    if (request_id == CGS_CREATE_APPLICATION_REQUEST_ID)
        return "CPS_CREATE_APPLICATION";
#endif
    return "UNKNOWN";
}

static uint32_t
cgs_trace_expected_reply(uint32_t request_id)
{
    if (request_id == CGS_SERVER_VERSION_REQUEST_ID)
        return CGS_SERVER_VERSION_REPLY_ID;
    if (request_id == CGS_DEATHWATCH_REQUEST_ID)
        return CGS_DEATHWATCH_REPLY_ID;
    if (request_id == CGS_NEW_CONNECTION_REQUEST_ID)
        return CGS_NEW_CONNECTION_REPLY_ID;
#ifdef PM_CPS_REGISTRATION_TRACE
    if (request_id == CGS_CHECKIN_APPLICATION_REQUEST_ID)
        return CGS_CHECKIN_APPLICATION_REPLY_ID;
    if (request_id == CGS_CREATE_APPLICATION_REQUEST_ID)
        return CGS_CREATE_APPLICATION_REPLY_ID;
#endif
    return 0U;
}

static int
is_cgs_trace_candidate(mach_msg_header_t *msg)
{
    unsigned char *m = (unsigned char *)msg;
    uint32_t request_id;

    if (msg == NULL)
        return 0;

    request_id = get_u32(m + 0x14);
    if (request_id == CGS_SERVER_VERSION_REQUEST_ID ||
        request_id == CGS_DEATHWATCH_REQUEST_ID ||
        request_id == CGS_NEW_CONNECTION_REQUEST_ID)
        return 1;
#ifdef PM_CPS_REGISTRATION_TRACE
    if (request_id == CGS_CHECKIN_APPLICATION_REQUEST_ID ||
        request_id == CGS_CREATE_APPLICATION_REQUEST_ID)
        return 1;
#endif
    return 0;
}

static mach_msg_return_t
trace_cgs_message(mach_msg_header_t *msg,
                  mach_msg_option_t option,
                  mach_msg_size_t send_size,
                  mach_msg_size_t rcv_size,
                  mach_port_name_t rcv_name,
                  mach_msg_timeout_t timeout,
                  mach_port_name_t notify)
{
    unsigned char *m = (unsigned char *)msg;
    mach_msg_return_t mr;
    uint32_t request_id;
    uint32_t expected_reply;
    uint32_t reply_bits;
    uint32_t reply_size;
    uint32_t reply_id;
    uint32_t limit;
    uint32_t off;
#ifdef PM_CGS_SERVER_VERSION_COMPAT_INTEGRATION
    int server_version_request_exact = 0;
#endif

    request_id = get_u32(m + 0x14);
    expected_reply = cgs_trace_expected_reply(request_id);
#ifdef PM_CGS_SERVER_VERSION_COMPAT_INTEGRATION
    if (request_id == CGS_SERVER_VERSION_REQUEST_ID) {
        server_version_request_exact =
            get_u32(m + 0x00) == 0x00001513U &&
            get_u32(m + 0x08) != 0U &&
            get_u32(m + 0x0c) == (uint32_t)rcv_name &&
            option == (mach_msg_option_t)0x00000003U &&
            send_size == (mach_msg_size_t)0x00000024U &&
            rcv_size == (mach_msg_size_t)0x00000048U &&
            rcv_name != MACH_PORT_NULL &&
            timeout == MACH_MSG_TIMEOUT_NONE &&
            notify == MACH_PORT_NULL;
    }
#endif
    ++gCGSTraceCallCount;

    fprintf(stderr, "%s\n", COMPAT_BUILD_MARKER);
    fprintf(stderr,
            "PM_CGS_CONNECTION_TRACE_REQUEST:index=%u kind=%s bits=0x%08lx headerSizeObserved=0x%08lx id=0x%08lx expectedReply=0x%08lx option=0x%08lx send=0x%08lx recv=0x%08lx remotePort=0x%08lx headerReplyPort=0x%08lx receivePort=0x%08lx timeout=0x%08lx notify=0x%08lx\n",
            gCGSTraceCallCount,
            cgs_trace_kind(request_id),
            (unsigned long)get_u32(m + 0x00),
            (unsigned long)get_u32(m + 0x04),
            (unsigned long)request_id,
            (unsigned long)expected_reply,
            (unsigned long)(uint32_t)option,
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            (unsigned long)get_u32(m + 0x08),
            (unsigned long)get_u32(m + 0x0c),
            (unsigned long)rcv_name,
            (unsigned long)timeout,
            (unsigned long)notify);
    fflush(stderr);

    limit = (uint32_t)send_size;
#ifdef PM_CPS_REGISTRATION_TRACE
    if ((request_id == CGS_CHECKIN_APPLICATION_REQUEST_ID ||
         request_id == CGS_CREATE_APPLICATION_REQUEST_ID) &&
        limit > 0x80U)
        limit = 0x80U;
    else
#endif
    if (limit > 0x44U)
        limit = 0x44U;

    fprintf(stderr,
            "PM_CGS_CONNECTION_TRACE_REQUEST_WORDS:index=%u kind=%s",
            gCGSTraceCallCount,
            cgs_trace_kind(request_id));
    for (off = 0x18U; off + 4U <= limit; off += 4U) {
        fprintf(stderr,
                " off%02lx=0x%08lx",
                (unsigned long)off,
                (unsigned long)get_u32(m + off));
    }
    fprintf(stderr, "\n");
    fflush(stderr);

    mr = call_original_mach_msg(msg, option, send_size,
                                rcv_size, rcv_name,
                                timeout, notify);

    fprintf(stderr,
            "PM_CGS_CONNECTION_TRACE_MACH_RETURN:index=%u kind=%s kr=%ld hex=0x%08lx\n",
            gCGSTraceCallCount,
            cgs_trace_kind(request_id),
            (long)mr,
            (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    reply_bits = get_u32(m + 0x00);
    reply_size = get_u32(m + 0x04);
    reply_id = get_u32(m + 0x14);

    fprintf(stderr,
            "PM_CGS_CONNECTION_TRACE_REPLY:index=%u kind=%s bits=0x%08lx size=0x%08lx id=0x%08lx expected=0x%08lx idMatch=%s\n",
            gCGSTraceCallCount,
            cgs_trace_kind(request_id),
            (unsigned long)reply_bits,
            (unsigned long)reply_size,
            (unsigned long)reply_id,
            (unsigned long)expected_reply,
            reply_id == expected_reply ? "YES" : "NO");
    fflush(stderr);

    limit = reply_size;
    if (limit > (uint32_t)rcv_size)
        limit = (uint32_t)rcv_size;
    if (limit > 0x44U)
        limit = 0x44U;

    fprintf(stderr,
            "PM_CGS_CONNECTION_TRACE_REPLY_WORDS:index=%u kind=%s",
            gCGSTraceCallCount,
            cgs_trace_kind(request_id));
    for (off = 0x18U; off + 4U <= limit; off += 4U) {
        fprintf(stderr,
                " off%02lx=0x%08lx",
                (unsigned long)off,
                (unsigned long)get_u32(m + off));
    }
    fprintf(stderr, "\n");
    fflush(stderr);

#ifdef PM_CGS_SERVER_VERSION_COMPAT_INTEGRATION
    maybe_normalize_cgs_server_version_reply(m,
                                             request_id,
                                             server_version_request_exact,
                                             rcv_size,
                                             mr,
                                             reply_bits,
                                             reply_size,
                                             reply_id);
#endif

    return mr;
}
#endif

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
        get_u32(m + 0x0c) != (uint32_t)rcv_name ||
        get_u32(m + 0x18) != 1U)
        return 0;

    if (get_u32(m + 0x1c) == (uint32_t)MACH_PORT_NULL ||
        m[0x26] != 0x13 ||
        m[0x27] != 0x00)
        return 0;

    return 1;
}


static void
record_servercheckin_session_port(unsigned char *m,
                                  mach_msg_return_t mr,
                                  const char *source)
{
    if (m == NULL || mr != MACH_MSG_SUCCESS)
        return;

    if (get_u32(m + 0x14) == CHECKIN_REPLY_ID &&
        get_u32(m + 0x04) == CHECKIN_SUCCESS_SIZE &&
        (get_u32(m + 0x00) & MACH_MSGH_BITS_COMPLEX) != 0 &&
        get_u32(m + CHECKIN_REPLY_DESC_COUNT_OFF) == 1U &&
        get_u32(m + CHECKIN_REPLY_PORT_OFF) != 0U &&
        m[CHECKIN_REPLY_DISPOSITION_OFF] == 0x11 &&
        m[CHECKIN_REPLY_TYPE_OFF] == 0x00) {
        gServerCheckinReplyPort =
            (mach_port_t)get_u32(m + CHECKIN_REPLY_PORT_OFF);
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_SERVERCHECKIN_REPLY_PORT:source=%s port=0x%08lx\n",
                source ? source : "(unknown)",
                (unsigned long)gServerCheckinReplyPort);
        fflush(stderr);
    }
}

static int
is_sessioninit_candidate(mach_msg_header_t *msg)
{
    unsigned char *m = (unsigned char *)msg;

    if (msg == NULL || gCoreServicesServerPort == MACH_PORT_NULL)
        return 0;

    return get_u32(m + 0x08) == (uint32_t)gCoreServicesServerPort &&
           get_u32(m + 0x14) == SESSIONINIT_REQUEST_ID;
}

static int
is_exact_legacy_sessioninit(mach_msg_header_t *msg,
                            mach_msg_option_t option,
                            mach_msg_size_t send_size,
                            mach_msg_size_t rcv_size,
                            mach_port_name_t rcv_name,
                            mach_msg_timeout_t timeout,
                            mach_port_name_t notify)
{
    unsigned char *m = (unsigned char *)msg;

    if (!is_sessioninit_candidate(msg))
        return 0;

    if ((uint32_t)option != 0x00000003U ||
        send_size != SESSIONINIT_LEGACY_SEND_SIZE ||
        rcv_size != SESSIONINIT_RECV_SIZE ||
        timeout != MACH_MSG_TIMEOUT_NONE ||
        notify != MACH_PORT_NULL)
        return 0;

    if (get_u32(m + 0x00) != SESSIONINIT_BITS ||
        get_u32(m + 0x0c) != (uint32_t)rcv_name)
        return 0;

    return 1;
}

static mach_msg_return_t
handle_sessioninit(mach_msg_header_t *msg,
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
    uint32_t legacy_pid;
    uint32_t legacy_uid;
    uint32_t legacy_layout;
    uint32_t reply_size;
    uint32_t reply_id;
    uint32_t retcode_raw;

    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_SESSIONINIT_CANDIDATE:bits=0x%08lx headerSizeObserved=0x%08lx id=0x%08lx option=0x%08lx send=0x%08lx recv=0x%08lx remotePort=0x%08lx serverCheckinPort=0x%08lx serverCheckinReplyPort=0x%08lx headerReplyPort=0x%08lx receivePort=0x%08lx timeout=0x%08lx notify=0x%08lx\n",
            (unsigned long)get_u32(m + 0x00),
            (unsigned long)get_u32(m + 0x04),
            (unsigned long)get_u32(m + 0x14),
            (unsigned long)(uint32_t)option,
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            (unsigned long)get_u32(m + 0x08),
            (unsigned long)gCoreServicesServerPort,
            (unsigned long)gServerCheckinReplyPort,
            (unsigned long)get_u32(m + 0x0c),
            (unsigned long)rcv_name,
            (unsigned long)timeout,
            (unsigned long)notify);
    fflush(stderr);

    if (!is_exact_legacy_sessioninit(msg, option, send_size,
                                     rcv_size, rcv_name,
                                     timeout, notify)) {
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_SESSIONINIT_RESULT:NONEXACT_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    ++gSessionInitExactCallCount;
    mode = getenv(COMPAT_MODE_ENV);
    legacy_pid = get_u32(m + SESSIONINIT_LEGACY_PID_OFF);
    legacy_uid = get_u32(m + SESSIONINIT_LEGACY_UID_OFF);
    legacy_layout = get_u32(m + SESSIONINIT_LEGACY_LAYOUT_OFF);

    fprintf(stderr, "%s\n", COMPAT_BUILD_MARKER);
    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_SESSIONINIT_EXACT_CALL:index=%u mode=%s pid=%lu uid=%lu layout=%lu\n",
            gSessionInitExactCallCount,
            mode ? mode : "(unset)",
            (unsigned long)legacy_pid,
            (unsigned long)legacy_uid,
            (unsigned long)legacy_layout);
    fflush(stderr);

    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_SESSIONINIT_ROUTE:remotePort=0x%08lx serverCheckinPort=0x%08lx serverCheckinReplyPort=0x%08lx\n",
            (unsigned long)get_u32(m + 0x08),
            (unsigned long)gCoreServicesServerPort,
            (unsigned long)gServerCheckinReplyPort);
    fflush(stderr);

    if (mode != NULL && strcmp(mode, COMPAT_MODE_PASSTHROUGH) == 0) {
        mr = call_original_mach_msg(msg, option, send_size,
                                    rcv_size, rcv_name,
                                    timeout, notify);
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_SESSIONINIT_PASSTHROUGH_RETURN:kr=%ld hex=0x%08lx\n",
                (long)mr, (unsigned long)(uint32_t)mr);
        fflush(stderr);
        return mr;
    }

    if (mode == NULL ||
        strcmp(mode, COMPAT_MODE_LION_SESSIONINIT) != 0)
        return MIG_BAD_ARGUMENTS;

    if (gSessionInitAdaptedCallCount != 0) {
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_SESSIONINIT_RESULT:SECOND_EXACT_CALL_BLOCKED\n");
        fflush(stderr);
        return MIG_BAD_ARGUMENTS;
    }

    ++gSessionInitAdaptedCallCount;

    put_u32(m + SESSIONINIT_LION_UID_OFF, legacy_uid);
    put_u32(m + SESSIONINIT_LION_LAYOUT_OFF, legacy_layout);
    put_u32(m + 0x04, SESSIONINIT_LION_SEND_SIZE);

    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_SESSIONINIT_ADAPTER_REQUEST:id=0x%08lx legacySend=0x%08lx adaptedSend=0x%08lx recv=0x%08lx droppedPid=%lu uid=%lu layout=%lu\n",
            (unsigned long)get_u32(m + 0x14),
            (unsigned long)send_size,
            (unsigned long)SESSIONINIT_LION_SEND_SIZE,
            (unsigned long)rcv_size,
            (unsigned long)legacy_pid,
            (unsigned long)get_u32(m + SESSIONINIT_LION_UID_OFF),
            (unsigned long)get_u32(m + SESSIONINIT_LION_LAYOUT_OFF));
    fflush(stderr);

    mr = call_original_mach_msg(msg, option,
                                (mach_msg_size_t)SESSIONINIT_LION_SEND_SIZE,
                                rcv_size, rcv_name, timeout, notify);

    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_SESSIONINIT_ADAPTER_MACH_MSG:kr=%ld hex=0x%08lx\n",
            (long)mr, (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    reply_size = get_u32(m + 0x04);
    reply_id = get_u32(m + 0x14);
    retcode_raw = get_u32(m + SESSIONINIT_REPLY_RETCODE_OFF);

    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_SESSIONINIT_ADAPTER_REPLY:size=0x%08lx id=0x%08lx retcodeRaw=0x%08lx\n",
            (unsigned long)reply_size,
            (unsigned long)reply_id,
            (unsigned long)retcode_raw);
    fflush(stderr);

    if (reply_id == SESSIONINIT_REPLY_ID &&
        reply_size == SESSIONINIT_SUCCESS_SIZE &&
        retcode_raw == 0U) {
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_SESSIONINIT_RESULT:PASS\n");
        fflush(stderr);
    } else if (reply_id == SESSIONINIT_REPLY_ID &&
               reply_size == SESSIONINIT_ERROR_SIZE) {
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_SESSIONINIT_RESULT:SERVER_ERROR retcodeRaw=0x%08lx\n",
                (unsigned long)retcode_raw);
        fflush(stderr);
    } else {
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_SESSIONINIT_RESULT:REPLY_SHAPE_UNEXPECTED\n");
        fflush(stderr);
    }

    return mr;
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
                "PM_CORESERVICES_COMPAT_SERVERCHECKIN_CANDIDATE:bits=0x%08lx headerSizeObserved=0x%08lx id=0x%08lx option=0x%08lx send=0x%08lx recv=0x%08lx serverPort=0x%08lx headerReplyPort=0x%08lx receivePort=0x%08lx descriptorCount=%lu descriptorPort=0x%08lx disposition=0x%02x type=0x%02x timeout=0x%08lx notify=0x%08lx\n",
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

    if (!is_servercheckin_candidate(msg)) {
        if (is_sessioninit_candidate(msg))
            return handle_sessioninit(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
#if defined(PM_CGS_CONNECTION_TRACE) || defined(PM_CGS_SERVER_VERSION_COMPAT_INTEGRATION)
        if (is_cgs_trace_candidate(msg))
            return trace_cgs_message(msg, option, send_size,
                                     rcv_size, rcv_name,
                                     timeout, notify);
#endif
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
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
        mr = call_original_mach_msg(msg, option, send_size,
                                    rcv_size, rcv_name,
                                    timeout, notify);
        record_servercheckin_session_port(m, mr, "passthrough");
        return mr;
    }

    if (!is_lion_compat_mode(mode))
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
            record_servercheckin_session_port(m, mr, "adapter");
            fprintf(stderr,
                    "PM_CORESERVICES_COMPAT_SERVERCHECKIN_ADAPTER_RESULT:PASS sessionPort=0x%08lx options=0x%08lx\n",
                    (unsigned long)gServerCheckinReplyPort,
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

    if (!is_lion_compat_mode(mode)) {
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
