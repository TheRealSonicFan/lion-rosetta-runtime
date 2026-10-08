#include <Security/AuthSession.h>
#include <mach/mach.h>
#include <mach/mig.h>
#include <mach/ndr.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

extern mach_port_t scCreateSystemServiceVersion(const char *,
                                                unsigned long,
                                                unsigned long *);

#define LS_SERVICE_NAME "LaunchApplicationServices"
#define LS_SERVICE_VERSION 0x00010000UL
#define LS_INIT_MSG_ID 0x00004650
#define LS_INIT_REPLY_ID 0x000046b4
#define LS_INIT_SEND_SIZE 0x0000002c
#define LS_INIT_RECV_SIZE 0x00000050
#define LS_PROCESS_SERVICES_VERSION 0x00a1be40U

typedef char mach_header_size_must_be_0x18[
    sizeof(mach_msg_header_t) == 0x18 ? 1 : -1];
typedef char ndr_size_must_be_0x08[
    sizeof(NDR_record_t) == 0x08 ? 1 : -1];

union message_buffer {
    mach_msg_header_t head;
    unsigned char bytes[LS_INIT_RECV_SIZE];
};

static void
marker(const char *text)
{
    fprintf(stderr, "%s\n", text);
    fflush(stderr);
}

static uint32_t
read_u32(const unsigned char *p)
{
    uint32_t v;
    memcpy(&v, p, sizeof(v));
    return v;
}

static void
write_u32(unsigned char *p, uint32_t v)
{
    memcpy(p, &v, sizeof(v));
}

static uint32_t
swap_u32(uint32_t v)
{
    return ((v & 0x000000ffU) << 24) |
           ((v & 0x0000ff00U) << 8) |
           ((v & 0x00ff0000U) >> 8) |
           ((v & 0xff000000U) >> 24);
}

static uint32_t
decode_ndr_u32(const unsigned char *p, unsigned char remote_int_rep)
{
    uint32_t v = read_u32(p);
    if (remote_int_rep != (unsigned char)NDR_record.int_rep)
        v = swap_u32(v);
    return v;
}

int
main(void)
{
    mach_port_t service_port = MACH_PORT_NULL;
    SecuritySessionId session_id = noSecuritySession;
    SessionAttributeBits attributes = 0;
    OSStatus session_status;
    mach_port_t reply_port;
    union message_buffer msg;
    kern_return_t kr;
    uint32_t bits;
    uint32_t size;
    int32_t reply_id;
    uint32_t descriptor_count;
    uint32_t process_port;
    uint32_t ool_address;
    uint32_t ool_size;
    unsigned char port_disposition;
    unsigned char port_type;
    unsigned char ool_type;
    unsigned char remote_int_rep;
    uint32_t out_version;
    uint32_t out_error;
    uint32_t out_count;
    uint32_t simple_error;

    marker("PM_LS_INIT_MILESTONE:M00_MAIN_ENTER");

    marker("PM_LS_INIT_MILESTONE:M01_BEFORE_scCreateSystemServiceVersion");
    service_port = scCreateSystemServiceVersion(LS_SERVICE_NAME,
                                                LS_SERVICE_VERSION,
                                                NULL);
    fprintf(stderr,
            "PM_LS_INIT_PORT:LaunchApplicationServices=0x%08lx\n",
            (unsigned long)service_port);
    fflush(stderr);
    marker("PM_LS_INIT_MILESTONE:M02_AFTER_scCreateSystemServiceVersion");

    if (service_port == MACH_PORT_NULL) {
        marker("PM_LS_INIT_RESULT:SYSTEMSERVICE_ZERO_PORT");
        return 20;
    }

    marker("PM_LS_INIT_MILESTONE:M03_BEFORE_SessionGetInfo");
    session_status = SessionGetInfo(callerSecuritySession,
                                    &session_id,
                                    &attributes);
    fprintf(stderr,
            "PM_LS_INIT_SESSION:status=%ld id=0x%08lx attrs=0x%08lx\n",
            (long)session_status,
            (unsigned long)session_id,
            (unsigned long)attributes);
    fflush(stderr);
    marker("PM_LS_INIT_MILESTONE:M04_AFTER_SessionGetInfo");

    if (session_status != noErr) {
        marker("PM_LS_INIT_RESULT:SESSION_ERROR");
        (void)mach_port_deallocate(mach_task_self(), service_port);
        return 21;
    }
    if (session_id == noSecuritySession) {
        marker("PM_LS_INIT_RESULT:SESSION_ZERO");
        (void)mach_port_deallocate(mach_task_self(), service_port);
        return 22;
    }

    memset(&msg, 0, sizeof(msg));
    reply_port = mig_get_reply_port();

    msg.head.msgh_bits = 0x00001513U;
    msg.head.msgh_size = LS_INIT_SEND_SIZE;
    msg.head.msgh_remote_port = service_port;
    msg.head.msgh_local_port = reply_port;
    msg.head.msgh_reserved = 0;
    msg.head.msgh_id = LS_INIT_MSG_ID;

    memcpy(msg.bytes + 0x18, &NDR_record, sizeof(NDR_record));
    write_u32(msg.bytes + 0x20, (uint32_t)session_id);
    write_u32(msg.bytes + 0x24, (uint32_t)session_id);
    write_u32(msg.bytes + 0x28, LS_PROCESS_SERVICES_VERSION);

    fprintf(stderr,
            "PM_LS_INIT_REQUEST:bits=0x%08lx id=0x%08lx send=0x%08x recv=0x%08x servicePort=0x%08lx replyPort=0x%08lx session1=0x%08lx session2=0x%08lx version=0x%08lx ndrIntRep=0x%02x\n",
            (unsigned long)msg.head.msgh_bits,
            (unsigned long)msg.head.msgh_id,
            LS_INIT_SEND_SIZE,
            LS_INIT_RECV_SIZE,
            (unsigned long)service_port,
            (unsigned long)reply_port,
            (unsigned long)session_id,
            (unsigned long)session_id,
            (unsigned long)LS_PROCESS_SERVICES_VERSION,
            (unsigned int)(unsigned char)NDR_record.int_rep);
    fflush(stderr);

    marker("PM_LS_INIT_MILESTONE:M05_BEFORE_mach_msg");
    kr = mach_msg(&msg.head,
                  MACH_SEND_MSG | MACH_RCV_MSG,
                  LS_INIT_SEND_SIZE,
                  LS_INIT_RECV_SIZE,
                  reply_port,
                  MACH_MSG_TIMEOUT_NONE,
                  MACH_PORT_NULL);
    marker("PM_LS_INIT_MILESTONE:M06_AFTER_mach_msg");

    bits = (uint32_t)msg.head.msgh_bits;
    size = (uint32_t)msg.head.msgh_size;
    reply_id = (int32_t)msg.head.msgh_id;

    fprintf(stderr,
            "PM_LS_INIT_MACH_MSG:kr=%d hex=0x%08lx\n",
            (int)kr,
            (unsigned long)(uint32_t)kr);
    fprintf(stderr,
            "PM_LS_INIT_REPLY_HEADER:bits=0x%08lx size=0x%08lx id=0x%08lx complex=%s\n",
            (unsigned long)bits,
            (unsigned long)size,
            (unsigned long)(uint32_t)reply_id,
            (bits & MACH_MSGH_BITS_COMPLEX) ? "YES" : "NO");
    fflush(stderr);

    if (kr != KERN_SUCCESS) {
        marker("PM_LS_INIT_RESULT:TRANSPORT_ERROR");
        (void)mach_port_deallocate(mach_task_self(), service_port);
        return 23;
    }

    if ((bits & MACH_MSGH_BITS_COMPLEX) == 0) {
        remote_int_rep = msg.bytes[0x1c];
        simple_error = (size >= 0x24) ?
            decode_ndr_u32(msg.bytes + 0x20, remote_int_rep) : 0xffffffffU;
        fprintf(stderr,
                "PM_LS_INIT_SIMPLE_REPLY:ndrIntRep=0x%02x error=%ld hex=0x%08lx\n",
                (unsigned int)remote_int_rep,
                (long)(int32_t)simple_error,
                (unsigned long)simple_error);
        fflush(stderr);
        marker("PM_LS_INIT_RESULT:SIMPLE_ERROR_REPLY");
        (void)mach_port_deallocate(mach_task_self(), service_port);
        return 24;
    }

    if ((uint32_t)reply_id != LS_INIT_REPLY_ID || size != 0x48U) {
        marker("PM_LS_INIT_RESULT:REPLY_SHAPE_ERROR");
        (void)mach_port_deallocate(mach_task_self(), service_port);
        return 25;
    }

    descriptor_count = read_u32(msg.bytes + 0x18);
    process_port = read_u32(msg.bytes + 0x1c);
    port_disposition = msg.bytes[0x26];
    port_type = msg.bytes[0x27];
    ool_address = read_u32(msg.bytes + 0x28);
    ool_size = read_u32(msg.bytes + 0x2c);
    ool_type = msg.bytes[0x33];
    remote_int_rep = msg.bytes[0x38];

    out_version = decode_ndr_u32(msg.bytes + 0x3c, remote_int_rep);
    out_error = decode_ndr_u32(msg.bytes + 0x40, remote_int_rep);
    out_count = decode_ndr_u32(msg.bytes + 0x44, remote_int_rep);

    fprintf(stderr,
            "PM_LS_INIT_REPLY_DESCRIPTORS:count=%lu processPort=0x%08lx portDisposition=0x%02x portType=0x%02x oolAddress=0x%08lx oolSize=0x%08lx oolType=0x%02x\n",
            (unsigned long)descriptor_count,
            (unsigned long)process_port,
            (unsigned int)port_disposition,
            (unsigned int)port_type,
            (unsigned long)ool_address,
            (unsigned long)ool_size,
            (unsigned int)ool_type);
    fprintf(stderr,
            "PM_LS_INIT_REPLY_VALUES:ndrIntRep=0x%02x localIntRep=0x%02x outVersion=0x%08lx outError=%ld outErrorHex=0x%08lx outCount=0x%08lx\n",
            (unsigned int)remote_int_rep,
            (unsigned int)(unsigned char)NDR_record.int_rep,
            (unsigned long)out_version,
            (long)(int32_t)out_error,
            (unsigned long)out_error,
            (unsigned long)out_count);
    fflush(stderr);

    if (process_port != MACH_PORT_NULL)
        (void)mach_port_deallocate(mach_task_self(), (mach_port_t)process_port);
    if (ool_address != 0 && ool_size != 0)
        (void)vm_deallocate(mach_task_self(),
                            (vm_address_t)ool_address,
                            (vm_size_t)ool_size);
    (void)mach_port_deallocate(mach_task_self(), service_port);

    if (descriptor_count != 2U ||
        port_disposition != 0x11U ||
        port_type != 0x00U ||
        ool_type != 0x01U ||
        process_port == MACH_PORT_NULL) {
        marker("PM_LS_INIT_RESULT:DESCRIPTOR_SHAPE_ERROR");
        return 26;
    }

    if (out_error != 0U) {
        marker("PM_LS_INIT_RESULT:SERVER_ERROR");
        return 27;
    }

    marker("PM_LS_INIT_RESULT:PROCESS_SERVICES_WIRE_PASS");
    marker("PM_LS_INIT_MILESTONE:M07_SUCCESS");
    return 0;
}
