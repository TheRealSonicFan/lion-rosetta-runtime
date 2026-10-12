#include <mach/mach.h>
#include <mach/mig_errors.h>
#include <servers/bootstrap.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define TRACE_BUILD_ID "native-i386-fontserver-rendezvous2-trace-v1"
#define TRACE_BUILD_MARKER "PM_NATIVE_FONTSERVER_RENDEZVOUS2_TRACE_BUILD_ID:" TRACE_BUILD_ID
#define TRACE_SUCCESS_MARKER "PM_NATIVE_FONTSERVER_RENDEZVOUS2_RESULT:CAPTURED_COMPLEX_V5"
#define FONT_SERVICE "com.apple.FontServer"

#define EXPECTED_REQUEST_BITS 0x00001513U
#define EXPECTED_REQUEST_ID 0x000032e7U
#define EXPECTED_SEND_SIZE 0x00000018U
#define EXPECTED_RECV_SIZE 0x00000040U
#define EXPECTED_REPLY_ID 0x0000334bU
#define EXPECTED_COMPLEX_REPLY_SIZE 0x00000038U
#define EXPECTED_SIMPLE_REPLY_SIZE 0x00000024U
#define EXPECTED_DESCRIPTOR_COUNT 1U
#define EXPECTED_PROTOCOL_VERSION 5U

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

static kern_return_t rosetta_native_bootstrap_look_up(mach_port_t,
                                                       const char *,
                                                       mach_port_t *);
static mach_msg_return_t rosetta_native_fontserver_mach_msg(
    mach_msg_header_t *,
    mach_msg_option_t,
    mach_msg_size_t,
    mach_msg_size_t,
    mach_port_name_t,
    mach_msg_timeout_t,
    mach_port_name_t);

static struct interpose_tuple sLookupInterpose;
static struct interpose_tuple sMachInterpose;

static bootstrap_lookup_fn gOriginalLookup = NULL;
static mach_msg_fn gOriginalMachMsg = NULL;
static mach_port_t gFontServerPort = MACH_PORT_NULL;
static unsigned int gTargetCount = 0;

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
    if (gOriginalLookup == NULL)
        gOriginalLookup =
            (bootstrap_lookup_fn)(uintptr_t)sLookupInterpose.replacee;
    return gOriginalLookup;
}

static mach_msg_fn
original_mach_msg(void)
{
    if (gOriginalMachMsg == NULL)
        gOriginalMachMsg =
            (mach_msg_fn)(uintptr_t)sMachInterpose.replacee;
    return gOriginalMachMsg;
}

static void
dump_hex(const char *kind, const unsigned char *bytes, uint32_t length)
{
    uint32_t i;

    fprintf(stderr,
            "PM_NATIVE_FONTSERVER_RENDEZVOUS2_%s_HEX:length=0x%08lx data=",
            kind, (unsigned long)length);
    for (i = 0; i < length; ++i)
        fprintf(stderr, "%02x", (unsigned int)bytes[i]);
    fprintf(stderr, "\n");
    fflush(stderr);
}

static void
finish(int code, const char *result)
{
    if (strcmp(result, "CAPTURED_COMPLEX_V5") == 0) {
        fprintf(stderr, "%s\\n", TRACE_SUCCESS_MARKER);
    } else {
        fprintf(stderr,
                "PM_NATIVE_FONTSERVER_RENDEZVOUS2_RESULT:%s\\n",
                result);
    }
    fflush(stderr);
    _exit(code);
}

static kern_return_t
rosetta_native_bootstrap_look_up(mach_port_t bp,
                                  const char *service_name,
                                  mach_port_t *service_port)
{
    bootstrap_lookup_fn fn = original_lookup();
    kern_return_t kr;

    if (fn == NULL ||
        fn == (bootstrap_lookup_fn)&rosetta_native_bootstrap_look_up)
        return MIG_BAD_ID;

    kr = fn(bp, service_name, service_port);

    if (service_name != NULL &&
        strcmp(service_name, FONT_SERVICE) == 0) {
        mach_port_t port = service_port != NULL ?
            *service_port : MACH_PORT_NULL;

        fprintf(stderr, "%s\n", TRACE_BUILD_MARKER);
        fprintf(stderr,
                "PM_NATIVE_FONTSERVER_RENDEZVOUS2_BOOTSTRAP:kr=%ld hex=0x%08lx port=0x%08lx\n",
                (long)kr,
                (unsigned long)(uint32_t)kr,
                (unsigned long)port);
        fflush(stderr);

        if (kr == KERN_SUCCESS && port != MACH_PORT_NULL)
            gFontServerPort = port;
    }

    return kr;
}

static mach_msg_return_t
rosetta_native_fontserver_mach_msg(mach_msg_header_t *msg,
                                    mach_msg_option_t option,
                                    mach_msg_size_t send_size,
                                    mach_msg_size_t rcv_size,
                                    mach_port_name_t rcv_name,
                                    mach_msg_timeout_t timeout,
                                    mach_port_name_t notify)
{
    mach_msg_fn fn = original_mach_msg();
    mach_msg_return_t mr;
    uint32_t request_bits;
    uint32_t request_size;
    uint32_t request_id;

    if (fn == NULL ||
        fn == (mach_msg_fn)&rosetta_native_fontserver_mach_msg)
        return MIG_BAD_ID;

    if (msg == NULL ||
        gFontServerPort == MACH_PORT_NULL ||
        msg->msgh_remote_port != gFontServerPort)
        return fn(msg, option, send_size, rcv_size,
                  rcv_name, timeout, notify);

    ++gTargetCount;
    if (gTargetCount != 1U)
        finish(75, "UNEXPECTED_SECOND_FONTSERVER_RPC");

    request_bits = (uint32_t)msg->msgh_bits;
    request_size = (uint32_t)msg->msgh_size;
    request_id = (uint32_t)msg->msgh_id;

    fprintf(stderr, "%s\n", TRACE_BUILD_MARKER);
    fprintf(stderr,
            "PM_NATIVE_FONTSERVER_RENDEZVOUS2_REQUEST:index=1 id=0x%08lx bits=0x%08lx headerSize=0x%08lx send=0x%08lx recv=0x%08lx remote=0x%08lx receivePort=0x%08lx option=0x%08lx\n",
            (unsigned long)request_id,
            (unsigned long)request_bits,
            (unsigned long)request_size,
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            (unsigned long)msg->msgh_remote_port,
            (unsigned long)rcv_name,
            (unsigned long)(uint32_t)option);
    dump_hex("REQUEST", (const unsigned char *)msg,
             (uint32_t)send_size);

    if (request_bits != EXPECTED_REQUEST_BITS ||
        request_id != EXPECTED_REQUEST_ID ||
        request_size != EXPECTED_SEND_SIZE ||
        send_size != EXPECTED_SEND_SIZE ||
        rcv_size != EXPECTED_RECV_SIZE)
        finish(76, "REQUEST_CONTRACT_MISMATCH");

    mr = fn(msg, option, send_size, rcv_size,
            rcv_name, timeout, notify);

    fprintf(stderr,
            "PM_NATIVE_FONTSERVER_RENDEZVOUS2_MACH_RETURN:kr=%ld hex=0x%08lx\n",
            (long)mr, (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        finish(77, "MACH_TRANSPORT_FAILED");

    {
        uint32_t reply_bits = (uint32_t)msg->msgh_bits;
        uint32_t reply_size = (uint32_t)msg->msgh_size;
        uint32_t reply_id = (uint32_t)msg->msgh_id;
        uint32_t complex =
            (reply_bits & MACH_MSGH_BITS_COMPLEX) != 0U;

        fprintf(stderr,
                "PM_NATIVE_FONTSERVER_RENDEZVOUS2_REPLY:bits=0x%08lx size=0x%08lx id=0x%08lx complex=%s\n",
                (unsigned long)reply_bits,
                (unsigned long)reply_size,
                (unsigned long)reply_id,
                complex ? "YES" : "NO");
        dump_hex("REPLY", (const unsigned char *)msg,
                 reply_size <= rcv_size ? reply_size : rcv_size);

        if (reply_id != EXPECTED_REPLY_ID)
            finish(78, "REPLY_ID_MISMATCH");

        if (!complex) {
            int32_t status;

            if (reply_size != EXPECTED_SIMPLE_REPLY_SIZE)
                finish(79, "SIMPLE_REPLY_SIZE_MISMATCH");

            status = (int32_t)get_u32(
                ((const unsigned char *)msg) + 0x20U);
            fprintf(stderr,
                    "PM_NATIVE_FONTSERVER_RENDEZVOUS2_SIMPLE_REPLY:status=%ld hex=0x%08lx\n",
                    (long)status,
                    (unsigned long)(uint32_t)status);
            fflush(stderr);
            finish(80, "NATIVE_RENDEZVOUS2_SIMPLE_ERROR");
        }

        if (reply_size != EXPECTED_COMPLEX_REPLY_SIZE)
            finish(81, "COMPLEX_REPLY_SIZE_MISMATCH");

        {
            const unsigned char *bytes =
                (const unsigned char *)msg;
            uint32_t descriptor_count = get_u32(bytes + 0x18U);
            uint32_t ool_address = get_u32(bytes + 0x1cU);
            uint32_t descriptor_size = get_u32(bytes + 0x20U);
            uint32_t descriptor_flags = get_u32(bytes + 0x24U);
            uint32_t protocol_version = get_u32(bytes + 0x30U);
            uint32_t explicit_size = get_u32(bytes + 0x34U);

            fprintf(stderr,
                    "PM_NATIVE_FONTSERVER_RENDEZVOUS2_FIELDS:descriptorCount=%lu oolAddress=0x%08lx descriptorSize=0x%08lx descriptorFlags=0x%08lx protocolVersion=%lu explicitSize=0x%08lx\n",
                    (unsigned long)descriptor_count,
                    (unsigned long)ool_address,
                    (unsigned long)descriptor_size,
                    (unsigned long)descriptor_flags,
                    (unsigned long)protocol_version,
                    (unsigned long)explicit_size);
            fflush(stderr);

            if (descriptor_count != EXPECTED_DESCRIPTOR_COUNT)
                finish(82, "DESCRIPTOR_COUNT_MISMATCH");
            if (protocol_version != EXPECTED_PROTOCOL_VERSION)
                finish(83, "PROTOCOL_VERSION_MISMATCH");
            if (ool_address == 0U || explicit_size == 0U)
                finish(84, "RENDEZVOUS_PAYLOAD_MISSING");
        }
    }

    finish(0, "CAPTURED_COMPLEX_V5");
    return mr;
}

__attribute__((used))
static struct interpose_tuple sLookupInterpose
__attribute__((section("__DATA,__interpose"))) = {
    (const void *)(uintptr_t)&rosetta_native_bootstrap_look_up,
    (const void *)(uintptr_t)&bootstrap_look_up
};

__attribute__((used))
static struct interpose_tuple sMachInterpose
__attribute__((section("__DATA,__interpose"))) = {
    (const void *)(uintptr_t)&rosetta_native_fontserver_mach_msg,
    (const void *)(uintptr_t)&mach_msg
};
