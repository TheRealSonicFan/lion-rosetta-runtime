#include <mach/mach.h>
#include <mach/mig_errors.h>
#include <mach/ndr.h>
#include <servers/bootstrap.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

extern mach_port_t bootstrap_port;
extern kern_return_t bootstrap_look_up(mach_port_t,
                                       const char *,
                                       mach_port_t *);
extern mach_port_t mig_get_reply_port(void);

#define BUILD_ID "cgs-server-version-compat-protocol-v1"
#define BUILD_MARKER "PM_CGS_SERVER_VERSION_BUILD_ID:" BUILD_ID

#define BOOTSTRAP_SPECIAL_PORT 4

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

#define CGS_PORT_REQUEST_BITS 0x00001513U
#define CGS_PORT_MSG_OPTIONS 0x00000003U
#define CGS_PORT_SEND_SIZE 0x00000018U
#define CGS_PORT_RECV_SIZE 0x00000030U
#define CGS_PORT_SUCCESS_SIZE 0x00000028U
#define CGS_PORT_ERROR_SIZE 0x00000024U
#define CGS_GET_SESSION_PORT_REQUEST_ID 0x00007151U
#define CGS_GET_SESSION_PORT_REPLY_ID 0x000071b5U
#define CGS_PORT_REPLY_DESC_COUNT_OFF 0x18U
#define CGS_PORT_REPLY_PORT_OFF 0x1cU
#define CGS_PORT_REPLY_RETCODE_OFF 0x20U
#define CGS_PORT_REPLY_DISPOSITION_OFF 0x26U
#define CGS_PORT_REPLY_TYPE_OFF 0x27U
#define CGS_EXPECTED_PORT_DISPOSITION 0x11U
#define CGS_EXPECTED_PORT_TYPE 0x00U

#define VERSION_REQUEST_ID 0x00007148U
#define VERSION_REPLY_ID 0x000071acU
#define VERSION_REQUEST_BITS 0x00001513U
#define VERSION_MSG_OPTIONS 0x00000003U
#define VERSION_SEND_SIZE 0x00000024U
#define VERSION_RECV_SIZE 0x00000048U
#define VERSION_COMPLEX_SIZE 0x00000040U
#define VERSION_ERROR_SIZE 0x00000024U
#define VERSION_REQUEST_NDR_OFF 0x18U
#define VERSION_REQUEST_PID_OFF 0x20U
#define VERSION_REPLY_DESC_COUNT_OFF 0x18U
#define VERSION_REPLY_PORT_OFF 0x1cU
#define VERSION_REPLY_DISPOSITION_OFF 0x26U
#define VERSION_REPLY_TYPE_OFF 0x27U
#define VERSION_REPLY_NDR_OFF 0x28U
#define VERSION_REPLY_MAJOR_OFF 0x30U
#define VERSION_REPLY_MINOR_OFF 0x34U
#define VERSION_REPLY_AUX_OFF 0x38U
#define VERSION_REPLY_FLAGS_OFF 0x3cU
#define VERSION_REPLY_RETCODE_OFF 0x20U

#define SNOW_LOCAL_VERSION_MAJOR 545U
#define SNOW_LOCAL_VERSION_MINOR 0U
#define LION_SERVER_VERSION_MAJOR 600U
#define LION_SERVER_VERSION_MINOR 0U

static const char *kSessionServiceName = "com.apple.windowserver.session";
static const char *kActiveServiceName = "com.apple.windowserver.active";

struct version_reply {
    unsigned char bytes[VERSION_RECV_SIZE];
    uint32_t bits;
    uint32_t size;
    uint32_t id;
    mach_port_t descriptor_port;
    uint32_t disposition;
    uint32_t descriptor_type;
    uint32_t major;
    uint32_t minor;
    uint32_t aux;
    uint32_t flags;
    int ndr_swapped;
};

static void
marker(const char *text)
{
    fprintf(stderr, "%s\n", text);
    fflush(stderr);
}

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

static uint32_t
swap_u32(uint32_t value)
{
    return ((value & 0x000000ffU) << 24) |
           ((value & 0x0000ff00U) << 8) |
           ((value & 0x00ff0000U) >> 8) |
           ((value & 0xff000000U) >> 24);
}

static int
has_send_right(mach_port_t port, const char *label)
{
    mach_port_type_t type = 0;
    kern_return_t kr;

    if (port == MACH_PORT_NULL)
        return 0;

    kr = mach_port_type(mach_task_self(), port, &type);
    fprintf(stderr,
            "PM_CGS_SERVER_VERSION_RIGHT:label=%s port=0x%08lx kr=%ld type=0x%08lx send=%s\n",
            label,
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
                          mach_port_t reply_port,
                          const char *service_name,
                          uint64_t flags)
{
    uint32_t bits;
    pid_t target_pid = 0;

    if (buffer == NULL || service_name == NULL)
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
            service_name, 0x7f);
    ((char *)(buffer + LION_LOOKUP_SERVICE_OFF))[0x7f] = '\0';

    memcpy(buffer + LION_LOOKUP_PID_OFF, &target_pid, sizeof(target_pid));
    memset(buffer + LION_LOOKUP_UUID_OFF, 0, 16);
    put_u64(buffer + LION_LOOKUP_FLAGS_OFF, flags);

    return get_u32(buffer + 0x00) == LION_LOOKUP_REQUEST_BITS &&
           get_u32(buffer + 0x04) == LION_LOOKUP_SEND_SIZE &&
           get_u32(buffer + 0x14) == LION_LOOKUP_REQUEST_ID &&
           get_u64(buffer + LION_LOOKUP_FLAGS_OFF) == flags;
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
lion_lookup_active_windowserver(mach_port_t bp,
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

    if (!build_lion_lookup_request(message, bp, reply_port,
                                   kActiveServiceName,
                                   PRIVILEGED_SERVER_FLAG))
        return MIG_BAD_ARGUMENTS;

    fprintf(stderr,
            "PM_CGS_SERVER_VERSION_ROOT_LOOKUP_REQUEST:bp=0x%08lx reply=0x%08lx name=%s id=0x%08lx send=0x%08lx recv=0x%08lx flags=0x%08lx%08lx\n",
            (unsigned long)bp,
            (unsigned long)reply_port,
            kActiveServiceName,
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
            "PM_CGS_SERVER_VERSION_ROOT_LOOKUP_MACH_RETURN:kr=%ld hex=0x%08lx\n",
            (long)mr,
            (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    reply_bits = get_u32(message + 0x00);
    reply_size = get_u32(message + 0x04);
    reply_id = get_u32(message + 0x14);

    fprintf(stderr,
            "PM_CGS_SERVER_VERSION_ROOT_LOOKUP_REPLY:bits=0x%08lx size=0x%08lx id=0x%08lx\n",
            (unsigned long)reply_bits,
            (unsigned long)reply_size,
            (unsigned long)reply_id);
    fflush(stderr);

    if (reply_id != LION_LOOKUP_REPLY_ID)
        return MIG_REPLY_MISMATCH;

    if ((reply_bits & MACH_MSGH_BITS_COMPLEX) == 0) {
        if (reply_size != LION_LOOKUP_ERROR_SIZE)
            return MIG_TYPE_ERROR;
        retcode = (int32_t)get_u32(message + LION_LOOKUP_REPLY_RETCODE_OFF);
        return (kern_return_t)retcode;
    }

    descriptor_count = get_u32(message + LION_LOOKUP_REPLY_DESC_COUNT_OFF);
    returned_port = (mach_port_t)get_u32(message + LION_LOOKUP_REPLY_PORT_OFF);

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
            "PM_CGS_SERVER_VERSION_ROOT_LOOKUP_COMPLEX_REPLY:descriptor_count=%lu rootPort=0x%08lx serverEuid=%lu\n",
            (unsigned long)descriptor_count,
            (unsigned long)returned_port,
            (unsigned long)server_euid);
    fflush(stderr);

    if (server_euid != 0) {
        (void)mach_port_deallocate(mach_task_self(), returned_port);
        return BOOTSTRAP_NOT_PRIVILEGED;
    }

    *root_port = returned_port;
    marker("PM_CGS_SERVER_VERSION_ROOT_LOOKUP_RESULT:PASS");
    return KERN_SUCCESS;
}

static kern_return_t
get_session_port(mach_port_t root_port,
                 mach_port_t *session_port)
{
    uint32_t storage[CGS_PORT_RECV_SIZE / sizeof(uint32_t)];
    unsigned char *message = (unsigned char *)storage;
    mach_port_t reply_port;
    mach_msg_return_t mr;
    uint32_t reply_bits;
    uint32_t reply_size;
    uint32_t reply_id;
    uint32_t descriptor_count;
    mach_port_t returned_port;
    uint32_t disposition;
    uint32_t descriptor_type;
    int32_t retcode;

    if (root_port == MACH_PORT_NULL || session_port == NULL)
        return MIG_BAD_ARGUMENTS;
    *session_port = MACH_PORT_NULL;
    memset(storage, 0, sizeof(storage));

    reply_port = mig_get_reply_port();
    if (reply_port == MACH_PORT_NULL)
        return MIG_NO_REPLY;

    put_u32(message + 0x00, CGS_PORT_REQUEST_BITS);
    put_u32(message + 0x04, CGS_PORT_SEND_SIZE);
    put_u32(message + 0x08, (uint32_t)root_port);
    put_u32(message + 0x0c, (uint32_t)reply_port);
    put_u32(message + 0x10, 0U);
    put_u32(message + 0x14, CGS_GET_SESSION_PORT_REQUEST_ID);

    fprintf(stderr,
            "PM_CGS_SERVER_VERSION_GETSESSION_REQUEST:remote=0x%08lx reply=0x%08lx id=0x%08lx send=0x%08lx recv=0x%08lx\n",
            (unsigned long)root_port,
            (unsigned long)reply_port,
            (unsigned long)CGS_GET_SESSION_PORT_REQUEST_ID,
            (unsigned long)CGS_PORT_SEND_SIZE,
            (unsigned long)CGS_PORT_RECV_SIZE);
    fflush(stderr);

    mr = mach_msg((mach_msg_header_t *)message,
                  (mach_msg_option_t)CGS_PORT_MSG_OPTIONS,
                  (mach_msg_size_t)CGS_PORT_SEND_SIZE,
                  (mach_msg_size_t)CGS_PORT_RECV_SIZE,
                  reply_port,
                  MACH_MSG_TIMEOUT_NONE,
                  MACH_PORT_NULL);

    fprintf(stderr,
            "PM_CGS_SERVER_VERSION_GETSESSION_MACH_RETURN:kr=%ld hex=0x%08lx\n",
            (long)mr,
            (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    reply_bits = get_u32(message + 0x00);
    reply_size = get_u32(message + 0x04);
    reply_id = get_u32(message + 0x14);

    fprintf(stderr,
            "PM_CGS_SERVER_VERSION_GETSESSION_REPLY:bits=0x%08lx size=0x%08lx id=0x%08lx\n",
            (unsigned long)reply_bits,
            (unsigned long)reply_size,
            (unsigned long)reply_id);
    fflush(stderr);

    if (reply_id != CGS_GET_SESSION_PORT_REPLY_ID)
        return MIG_REPLY_MISMATCH;

    if ((reply_bits & MACH_MSGH_BITS_COMPLEX) == 0) {
        if (reply_size != CGS_PORT_ERROR_SIZE)
            return MIG_TYPE_ERROR;
        retcode = (int32_t)get_u32(message + CGS_PORT_REPLY_RETCODE_OFF);
        return (kern_return_t)retcode;
    }

    descriptor_count = get_u32(message + CGS_PORT_REPLY_DESC_COUNT_OFF);
    returned_port = (mach_port_t)get_u32(message + CGS_PORT_REPLY_PORT_OFF);
    disposition = (uint32_t)message[CGS_PORT_REPLY_DISPOSITION_OFF];
    descriptor_type = (uint32_t)message[CGS_PORT_REPLY_TYPE_OFF];

    fprintf(stderr,
            "PM_CGS_SERVER_VERSION_GETSESSION_COMPLEX_REPLY:descriptor_count=%lu sessionPort=0x%08lx disposition=0x%02lx type=0x%02lx\n",
            (unsigned long)descriptor_count,
            (unsigned long)returned_port,
            (unsigned long)disposition,
            (unsigned long)descriptor_type);
    fflush(stderr);

    if (reply_size != CGS_PORT_SUCCESS_SIZE ||
        descriptor_count != 1U ||
        returned_port == MACH_PORT_NULL ||
        disposition != CGS_EXPECTED_PORT_DISPOSITION ||
        descriptor_type != CGS_EXPECTED_PORT_TYPE) {
        if (returned_port != MACH_PORT_NULL)
            (void)mach_port_deallocate(mach_task_self(), returned_port);
        return MIG_TYPE_ERROR;
    }

    *session_port = returned_port;
    return KERN_SUCCESS;
}

static uint32_t
decode_reply_u32(const unsigned char *message, uint32_t off)
{
    uint32_t value = get_u32(message + off);
    const unsigned char *local_ndr = (const unsigned char *)&NDR_record;

    if (message[VERSION_REPLY_NDR_OFF + 4U] != local_ndr[4])
        value = swap_u32(value);
    return value;
}

static void
encode_reply_u32(unsigned char *message, uint32_t off, uint32_t value)
{
    const unsigned char *local_ndr = (const unsigned char *)&NDR_record;

    if (message[VERSION_REPLY_NDR_OFF + 4U] != local_ndr[4])
        value = swap_u32(value);
    put_u32(message + off, value);
}

static kern_return_t
parse_server_version_reply(unsigned char *message,
                           struct version_reply *reply)
{
    uint32_t descriptor_count;
    int32_t retcode;

    if (message == NULL || reply == NULL)
        return MIG_BAD_ARGUMENTS;

    reply->bits = get_u32(message + 0x00);
    reply->size = get_u32(message + 0x04);
    reply->id = get_u32(message + 0x14);

    if (reply->id != VERSION_REPLY_ID)
        return MIG_REPLY_MISMATCH;

    if ((reply->bits & MACH_MSGH_BITS_COMPLEX) == 0) {
        if (reply->size != VERSION_ERROR_SIZE)
            return MIG_TYPE_ERROR;
        retcode = (int32_t)get_u32(message + VERSION_REPLY_RETCODE_OFF);
        return (kern_return_t)retcode;
    }

    descriptor_count = get_u32(message + VERSION_REPLY_DESC_COUNT_OFF);
    reply->descriptor_port =
        (mach_port_t)get_u32(message + VERSION_REPLY_PORT_OFF);
    reply->disposition =
        (uint32_t)message[VERSION_REPLY_DISPOSITION_OFF];
    reply->descriptor_type =
        (uint32_t)message[VERSION_REPLY_TYPE_OFF];

    if (reply->size != VERSION_COMPLEX_SIZE ||
        descriptor_count != 1U ||
        reply->descriptor_port == MACH_PORT_NULL ||
        reply->disposition != CGS_EXPECTED_PORT_DISPOSITION ||
        reply->descriptor_type != CGS_EXPECTED_PORT_TYPE)
        return MIG_TYPE_ERROR;

    reply->ndr_swapped =
        message[VERSION_REPLY_NDR_OFF + 4U] !=
        ((const unsigned char *)&NDR_record)[4];

    reply->major = decode_reply_u32(message, VERSION_REPLY_MAJOR_OFF);
    reply->minor = decode_reply_u32(message, VERSION_REPLY_MINOR_OFF);
    reply->aux = decode_reply_u32(message, VERSION_REPLY_AUX_OFF);
    reply->flags = decode_reply_u32(message, VERSION_REPLY_FLAGS_OFF);

    return KERN_SUCCESS;
}

static kern_return_t
server_version_rpc(mach_port_t session_port,
                   struct version_reply *reply)
{
    uint32_t storage[VERSION_RECV_SIZE / sizeof(uint32_t)];
    unsigned char *message = (unsigned char *)storage;
    mach_port_t reply_port;
    mach_msg_return_t mr;
    kern_return_t kr;
    pid_t pid;

    if (session_port == MACH_PORT_NULL || reply == NULL)
        return MIG_BAD_ARGUMENTS;

    memset(storage, 0, sizeof(storage));
    memset(reply, 0, sizeof(*reply));

    reply_port = mig_get_reply_port();
    if (reply_port == MACH_PORT_NULL)
        return MIG_NO_REPLY;

    pid = getpid();

    put_u32(message + 0x00, VERSION_REQUEST_BITS);
    put_u32(message + 0x04, VERSION_SEND_SIZE);
    put_u32(message + 0x08, (uint32_t)session_port);
    put_u32(message + 0x0c, (uint32_t)reply_port);
    put_u32(message + 0x10, 0U);
    put_u32(message + 0x14, VERSION_REQUEST_ID);
    memcpy(message + VERSION_REQUEST_NDR_OFF,
           &NDR_record, sizeof(NDR_record));
    memcpy(message + VERSION_REQUEST_PID_OFF, &pid, sizeof(pid));

    fprintf(stderr,
            "PM_CGS_SERVER_VERSION_REQUEST:remote=0x%08lx reply=0x%08lx id=0x%08lx bits=0x%08lx send=0x%08lx recv=0x%08lx options=0x%08lx pid=%ld raw20=0x%08lx\n",
            (unsigned long)session_port,
            (unsigned long)reply_port,
            (unsigned long)VERSION_REQUEST_ID,
            (unsigned long)VERSION_REQUEST_BITS,
            (unsigned long)VERSION_SEND_SIZE,
            (unsigned long)VERSION_RECV_SIZE,
            (unsigned long)VERSION_MSG_OPTIONS,
            (long)pid,
            (unsigned long)get_u32(message + VERSION_REQUEST_PID_OFF));
    fflush(stderr);

    mr = mach_msg((mach_msg_header_t *)message,
                  (mach_msg_option_t)VERSION_MSG_OPTIONS,
                  (mach_msg_size_t)VERSION_SEND_SIZE,
                  (mach_msg_size_t)VERSION_RECV_SIZE,
                  reply_port,
                  MACH_MSG_TIMEOUT_NONE,
                  MACH_PORT_NULL);

    fprintf(stderr,
            "PM_CGS_SERVER_VERSION_MACH_RETURN:kr=%ld hex=0x%08lx\n",
            (long)mr,
            (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    memcpy(reply->bytes, message, VERSION_RECV_SIZE);
    kr = parse_server_version_reply(reply->bytes, reply);

    fprintf(stderr,
            "PM_CGS_SERVER_VERSION_REPLY:bits=0x%08lx size=0x%08lx id=0x%08lx kr=%ld descriptorPort=0x%08lx disposition=0x%02lx type=0x%02lx ndrSwapped=%s major=%lu minor=%lu aux=0x%08lx flags=0x%08lx raw30=0x%08lx raw34=0x%08lx raw38=0x%08lx raw3c=0x%08lx\n",
            (unsigned long)reply->bits,
            (unsigned long)reply->size,
            (unsigned long)reply->id,
            (long)kr,
            (unsigned long)reply->descriptor_port,
            (unsigned long)reply->disposition,
            (unsigned long)reply->descriptor_type,
            reply->ndr_swapped ? "YES" : "NO",
            (unsigned long)reply->major,
            (unsigned long)reply->minor,
            (unsigned long)reply->aux,
            (unsigned long)reply->flags,
            (unsigned long)get_u32(reply->bytes + VERSION_REPLY_MAJOR_OFF),
            (unsigned long)get_u32(reply->bytes + VERSION_REPLY_MINOR_OFF),
            (unsigned long)get_u32(reply->bytes + VERSION_REPLY_AUX_OFF),
            (unsigned long)get_u32(reply->bytes + VERSION_REPLY_FLAGS_OFF));
    fflush(stderr);

    return kr;
}

static int
prove_lion_normalization(struct version_reply *original)
{
    struct version_reply adapted;
    unsigned char before[VERSION_COMPLEX_SIZE];
    unsigned int off;
    unsigned int changed = 0;
    unsigned int outside_changed = 0;
    kern_return_t kr;

    if (original == NULL ||
        original->major != LION_SERVER_VERSION_MAJOR ||
        original->minor != LION_SERVER_VERSION_MINOR)
        return 0;

    memset(&adapted, 0, sizeof(adapted));
    memcpy(adapted.bytes, original->bytes, VERSION_RECV_SIZE);
    memcpy(before, adapted.bytes, VERSION_COMPLEX_SIZE);

    encode_reply_u32(adapted.bytes,
                     VERSION_REPLY_MAJOR_OFF,
                     SNOW_LOCAL_VERSION_MAJOR);
    encode_reply_u32(adapted.bytes,
                     VERSION_REPLY_MINOR_OFF,
                     SNOW_LOCAL_VERSION_MINOR);

    for (off = 0; off < VERSION_COMPLEX_SIZE; ++off) {
        if (before[off] != adapted.bytes[off]) {
            ++changed;
            if (off < VERSION_REPLY_MAJOR_OFF ||
                off >= VERSION_REPLY_MINOR_OFF + 4U)
                ++outside_changed;
        }
    }

    kr = parse_server_version_reply(adapted.bytes, &adapted);

    fprintf(stderr,
            "PM_CGS_SERVER_VERSION_POLICY:originalMajor=%lu originalMinor=%lu localMajor=%lu localMinor=%lu mismatch=%s\n",
            (unsigned long)original->major,
            (unsigned long)original->minor,
            (unsigned long)SNOW_LOCAL_VERSION_MAJOR,
            (unsigned long)SNOW_LOCAL_VERSION_MINOR,
            (original->major != SNOW_LOCAL_VERSION_MAJOR ||
             original->minor != SNOW_LOCAL_VERSION_MINOR) ?
                "YES" : "NO");
    fprintf(stderr,
            "PM_CGS_SERVER_VERSION_ADAPTER:kr=%ld changedBytes=%u outsideVersionBytesChanged=%u raw30Before=0x%08lx raw30After=0x%08lx raw34Before=0x%08lx raw34After=0x%08lx adaptedMajor=%lu adaptedMinor=%lu match=%s\n",
            (long)kr,
            changed,
            outside_changed,
            (unsigned long)get_u32(before + VERSION_REPLY_MAJOR_OFF),
            (unsigned long)get_u32(adapted.bytes + VERSION_REPLY_MAJOR_OFF),
            (unsigned long)get_u32(before + VERSION_REPLY_MINOR_OFF),
            (unsigned long)get_u32(adapted.bytes + VERSION_REPLY_MINOR_OFF),
            (unsigned long)adapted.major,
            (unsigned long)adapted.minor,
            (kr == KERN_SUCCESS &&
             adapted.major == SNOW_LOCAL_VERSION_MAJOR &&
             adapted.minor == SNOW_LOCAL_VERSION_MINOR) ?
                "YES" : "NO");
    fflush(stderr);

    return kr == KERN_SUCCESS &&
           outside_changed == 0U &&
           changed > 0U &&
           adapted.major == SNOW_LOCAL_VERSION_MAJOR &&
           adapted.minor == SNOW_LOCAL_VERSION_MINOR &&
           adapted.descriptor_port == original->descriptor_port &&
           adapted.disposition == original->disposition &&
           adapted.descriptor_type == original->descriptor_type &&
           adapted.aux == original->aux &&
           adapted.flags == original->flags;
}

static int
layout_selfcheck(void)
{
    uint32_t storage[VERSION_RECV_SIZE / sizeof(uint32_t)];
    unsigned char *message = (unsigned char *)storage;
    pid_t pid = (pid_t)0x12345678;

    memset(storage, 0, sizeof(storage));
    put_u32(message + 0x00, VERSION_REQUEST_BITS);
    put_u32(message + 0x04, VERSION_SEND_SIZE);
    put_u32(message + 0x08, 0x11111111U);
    put_u32(message + 0x0c, 0x22222222U);
    put_u32(message + 0x14, VERSION_REQUEST_ID);
    memcpy(message + VERSION_REQUEST_NDR_OFF,
           &NDR_record, sizeof(NDR_record));
    memcpy(message + VERSION_REQUEST_PID_OFF, &pid, sizeof(pid));

    if (get_u32(message + 0x00) != VERSION_REQUEST_BITS ||
        get_u32(message + 0x04) != VERSION_SEND_SIZE ||
        get_u32(message + 0x14) != VERSION_REQUEST_ID ||
        memcmp(message + VERSION_REQUEST_NDR_OFF,
               &NDR_record, sizeof(NDR_record)) != 0 ||
        memcmp(message + VERSION_REQUEST_PID_OFF,
               &pid, sizeof(pid)) != 0) {
        marker("PM_CGS_SERVER_VERSION_LAYOUT:FAIL");
        return 0;
    }

    fprintf(stderr,
            "PM_CGS_SERVER_VERSION_LAYOUT:request=0x%08lx reply=0x%08lx send=0x%08lx recv=0x%08lx complexSize=0x%08lx majorOff=0x%02lx minorOff=0x%02lx localMajor=%lu localMinor=%lu lionMajor=%lu lionMinor=%lu\n",
            (unsigned long)VERSION_REQUEST_ID,
            (unsigned long)VERSION_REPLY_ID,
            (unsigned long)VERSION_SEND_SIZE,
            (unsigned long)VERSION_RECV_SIZE,
            (unsigned long)VERSION_COMPLEX_SIZE,
            (unsigned long)VERSION_REPLY_MAJOR_OFF,
            (unsigned long)VERSION_REPLY_MINOR_OFF,
            (unsigned long)SNOW_LOCAL_VERSION_MAJOR,
            (unsigned long)SNOW_LOCAL_VERSION_MINOR,
            (unsigned long)LION_SERVER_VERSION_MAJOR,
            (unsigned long)LION_SERVER_VERSION_MINOR);
    marker("PM_CGS_SERVER_VERSION_LAYOUT:PASS");
    return 1;
}

static int
get_task_bootstrap(mach_port_t *bp)
{
    mach_port_t port = MACH_PORT_NULL;
    kern_return_t kr;

    kr = task_get_special_port(mach_task_self(),
                               BOOTSTRAP_SPECIAL_PORT,
                               &port);
    fprintf(stderr,
            "PM_CGS_SERVER_VERSION_BOOTSTRAP_SPECIAL_PORT:kr=%ld hex=0x%08lx port=0x%08lx global=0x%08lx\n",
            (long)kr,
            (unsigned long)(uint32_t)kr,
            (unsigned long)port,
            (unsigned long)bootstrap_port);
    fflush(stderr);

    if (kr != KERN_SUCCESS || port == MACH_PORT_NULL)
        return 0;

    *bp = port;
    return 1;
}

static int
run_snow_control(mach_port_t bp)
{
    mach_port_t session_port = MACH_PORT_NULL;
    struct version_reply reply;
    kern_return_t kr;

    marker("PM_CGS_SERVER_VERSION_MILESTONE:S00_BEFORE_SESSION_LOOKUP");
    kr = bootstrap_look_up(bp, kSessionServiceName, &session_port);
    fprintf(stderr,
            "PM_CGS_SERVER_VERSION_SNOW_LOOKUP_RETURN:kr=%ld hex=0x%08lx sessionPort=0x%08lx\n",
            (long)kr,
            (unsigned long)(uint32_t)kr,
            (unsigned long)session_port);
    fflush(stderr);
    marker("PM_CGS_SERVER_VERSION_MILESTONE:S01_AFTER_SESSION_LOOKUP");

    if (kr != KERN_SUCCESS || session_port == MACH_PORT_NULL)
        return 20;
    if (!has_send_right(session_port, "snow-session")) {
        (void)mach_port_deallocate(mach_task_self(), session_port);
        return 21;
    }

    marker("PM_CGS_SERVER_VERSION_MILESTONE:S02_BEFORE_VERSION_RPC");
    kr = server_version_rpc(session_port, &reply);
    marker("PM_CGS_SERVER_VERSION_MILESTONE:S03_AFTER_VERSION_RPC");

    (void)mach_port_deallocate(mach_task_self(), session_port);

    if (kr != KERN_SUCCESS)
        return 22;
    if (!has_send_right(reply.descriptor_port, "snow-version-descriptor")) {
        (void)mach_port_deallocate(mach_task_self(), reply.descriptor_port);
        return 23;
    }

    fprintf(stderr,
            "PM_CGS_SERVER_VERSION_SNOW_POLICY:serverMajor=%lu serverMinor=%lu localMajor=%lu localMinor=%lu match=%s\n",
            (unsigned long)reply.major,
            (unsigned long)reply.minor,
            (unsigned long)SNOW_LOCAL_VERSION_MAJOR,
            (unsigned long)SNOW_LOCAL_VERSION_MINOR,
            (reply.major == SNOW_LOCAL_VERSION_MAJOR &&
             reply.minor == SNOW_LOCAL_VERSION_MINOR) ?
                "YES" : "NO");
    fflush(stderr);

    (void)mach_port_deallocate(mach_task_self(), reply.descriptor_port);

    if (reply.major != SNOW_LOCAL_VERSION_MAJOR ||
        reply.minor != SNOW_LOCAL_VERSION_MINOR)
        return 24;

    marker("PM_CGS_SERVER_VERSION_RESULT:SNOW_CONTROL_PASS");
    return 0;
}

static int
run_lion_policy_proof(mach_port_t bp)
{
    mach_port_t root_port = MACH_PORT_NULL;
    mach_port_t session_port = MACH_PORT_NULL;
    struct version_reply reply;
    kern_return_t kr;
    int policy_ok;

    marker("PM_CGS_SERVER_VERSION_MILESTONE:L00_BEFORE_ROOT_LOOKUP");
    kr = lion_lookup_active_windowserver(bp, &root_port);
    marker("PM_CGS_SERVER_VERSION_MILESTONE:L01_AFTER_ROOT_LOOKUP");
    if (kr != KERN_SUCCESS || root_port == MACH_PORT_NULL)
        return 30;
    if (!has_send_right(root_port, "lion-root")) {
        (void)mach_port_deallocate(mach_task_self(), root_port);
        return 31;
    }

    marker("PM_CGS_SERVER_VERSION_MILESTONE:L02_BEFORE_GETSESSION");
    kr = get_session_port(root_port, &session_port);
    marker("PM_CGS_SERVER_VERSION_MILESTONE:L03_AFTER_GETSESSION");
    (void)mach_port_deallocate(mach_task_self(), root_port);

    if (kr != KERN_SUCCESS || session_port == MACH_PORT_NULL)
        return 32;
    if (!has_send_right(session_port, "lion-session")) {
        (void)mach_port_deallocate(mach_task_self(), session_port);
        return 33;
    }

    marker("PM_CGS_SERVER_VERSION_MILESTONE:L04_BEFORE_VERSION_RPC");
    kr = server_version_rpc(session_port, &reply);
    marker("PM_CGS_SERVER_VERSION_MILESTONE:L05_AFTER_VERSION_RPC");
    (void)mach_port_deallocate(mach_task_self(), session_port);

    if (kr != KERN_SUCCESS)
        return 34;
    if (!has_send_right(reply.descriptor_port, "lion-version-descriptor")) {
        (void)mach_port_deallocate(mach_task_self(), reply.descriptor_port);
        return 35;
    }

    policy_ok = prove_lion_normalization(&reply);
    (void)mach_port_deallocate(mach_task_self(), reply.descriptor_port);

    if (!policy_ok)
        return 36;

    marker("PM_CGS_SERVER_VERSION_RESULT:LION_POLICY_PROOF_PASS");
    return 0;
}

int
main(int argc, char **argv)
{
    mach_port_t bp = MACH_PORT_NULL;
    int rc;

    marker(BUILD_MARKER);
    marker("PM_CGS_SERVER_VERSION_MILESTONE:M00_MAIN_ENTER");

    if (!layout_selfcheck())
        return 40;

    if (!get_task_bootstrap(&bp))
        return 41;

    if (argc != 2) {
        fprintf(stderr,
                "usage: %s snow-control|lion-policy-proof\n",
                argv[0]);
        return 64;
    }

    if (strcmp(argv[1], "snow-control") == 0)
        rc = run_snow_control(bp);
    else if (strcmp(argv[1], "lion-policy-proof") == 0)
        rc = run_lion_policy_proof(bp);
    else {
        fprintf(stderr, "unknown mode: %s\n", argv[1]);
        rc = 64;
    }

    (void)mach_port_deallocate(mach_task_self(), bp);
    fprintf(stderr,
            "PM_CGS_SERVER_VERSION_EXIT:rc=%d\n",
            rc);
    fflush(stderr);
    return rc;
}
