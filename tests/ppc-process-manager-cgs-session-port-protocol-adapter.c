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
extern kern_return_t bootstrap_look_up(mach_port_t,
                                       const char *,
                                       mach_port_t *);
extern mach_port_t mig_get_reply_port(void);

#define BUILD_ID "cgs-session-port-protocol-v3"
#define BUILD_MARKER "PM_CGS_SESSION_PORT_BUILD_ID:" BUILD_ID

#define BOOTSTRAP_SPECIAL_PORT 4

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
#define CGS_DEATHWATCH_REQUEST_ID 0x0000714cU
#define CGS_DEATHWATCH_REPLY_ID 0x000071b0U
#define CGS_REPLY_DESC_COUNT_OFF 0x18U
#define CGS_REPLY_PORT_OFF 0x1cU
#define CGS_REPLY_RETCODE_OFF 0x20U
#define CGS_REPLY_DESCRIPTOR_WORD_OFF 0x24U
#define CGS_REPLY_DESCRIPTOR_DISPOSITION_OFF 0x26U
#define CGS_REPLY_DESCRIPTOR_TYPE_OFF 0x27U
#define CGS_EXPECTED_PORT_DISPOSITION 0x11U
#define CGS_EXPECTED_PORT_TYPE 0x00U

static const char *kSessionServiceName = "com.apple.windowserver.session";
static const char *kActiveServiceName = "com.apple.windowserver.active";

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

static int
has_send_right(mach_port_t port)
{
    mach_port_type_t type = 0;
    kern_return_t kr;

    if (port == MACH_PORT_NULL)
        return 0;

    kr = mach_port_type(mach_task_self(), port, &type);
    fprintf(stderr,
            "PM_CGS_SESSION_PORT_RIGHT:port=0x%08lx kr=%ld type=0x%08lx send=%s\n",
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
            "PM_CGS_SESSION_PORT_ROOT_LOOKUP_REQUEST:bp=0x%08lx reply=0x%08lx name=%s id=0x%08lx send=0x%08lx recv=0x%08lx pid=0 uuid=ZERO flags=0x%08lx%08lx\n",
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
            "PM_CGS_SESSION_PORT_ROOT_LOOKUP_MACH_RETURN:kr=%ld hex=0x%08lx\n",
            (long)mr,
            (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    reply_bits = get_u32(message + 0x00);
    reply_size = get_u32(message + 0x04);
    reply_id = get_u32(message + 0x14);

    fprintf(stderr,
            "PM_CGS_SESSION_PORT_ROOT_LOOKUP_REPLY:bits=0x%08lx size=0x%08lx id=0x%08lx\n",
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
        fprintf(stderr,
                "PM_CGS_SESSION_PORT_ROOT_LOOKUP_SIMPLE_REPLY:retcode=%ld hex=0x%08lx\n",
                (long)retcode,
                (unsigned long)(uint32_t)retcode);
        fflush(stderr);
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
            "PM_CGS_SESSION_PORT_ROOT_LOOKUP_COMPLEX_REPLY:descriptor_count=%lu rootPort=0x%08lx serverEuid=%lu\n",
            (unsigned long)descriptor_count,
            (unsigned long)returned_port,
            (unsigned long)server_euid);
    fflush(stderr);

    if (server_euid != 0) {
        (void)mach_port_deallocate(mach_task_self(), returned_port);
        return BOOTSTRAP_NOT_PRIVILEGED;
    }

    *root_port = returned_port;
    marker("PM_CGS_SESSION_PORT_ROOT_LOOKUP_RESULT:PASS");
    return KERN_SUCCESS;
}

static kern_return_t
cgs_port_rpc(mach_port_t remote_port,
             uint32_t request_id,
             uint32_t reply_id_expected,
             const char *label,
             mach_port_t *returned_port)
{
    uint32_t storage[CGS_RECV_SIZE / sizeof(uint32_t)];
    unsigned char *message = (unsigned char *)storage;
    mach_port_t reply_port;
    mach_msg_return_t mr;
    uint32_t reply_bits;
    uint32_t reply_size;
    uint32_t reply_id;
    uint32_t descriptor_count;
    uint32_t descriptor_word;
    uint32_t disposition;
    uint32_t descriptor_type;
    mach_port_t out_port;
    int32_t retcode;

    if (remote_port == MACH_PORT_NULL || returned_port == NULL)
        return MIG_BAD_ARGUMENTS;

    *returned_port = MACH_PORT_NULL;
    memset(storage, 0, sizeof(storage));

    reply_port = mig_get_reply_port();
    if (reply_port == MACH_PORT_NULL)
        return MIG_NO_REPLY;

    put_u32(message + 0x00, CGS_REQUEST_BITS);
    put_u32(message + 0x04, CGS_SEND_SIZE);
    put_u32(message + 0x08, (uint32_t)remote_port);
    put_u32(message + 0x0c, (uint32_t)reply_port);
    put_u32(message + 0x10, 0U);
    put_u32(message + 0x14, request_id);

    fprintf(stderr,
            "PM_CGS_SESSION_PORT_%s_REQUEST:remote=0x%08lx reply=0x%08lx id=0x%08lx bits=0x%08lx send=0x%08lx recv=0x%08lx options=0x%08lx\n",
            label,
            (unsigned long)remote_port,
            (unsigned long)reply_port,
            (unsigned long)request_id,
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
            "PM_CGS_SESSION_PORT_%s_MACH_RETURN:kr=%ld hex=0x%08lx\n",
            label,
            (long)mr,
            (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    reply_bits = get_u32(message + 0x00);
    reply_size = get_u32(message + 0x04);
    reply_id = get_u32(message + 0x14);

    fprintf(stderr,
            "PM_CGS_SESSION_PORT_%s_REPLY:bits=0x%08lx size=0x%08lx id=0x%08lx\n",
            label,
            (unsigned long)reply_bits,
            (unsigned long)reply_size,
            (unsigned long)reply_id);
    fflush(stderr);

    if (reply_id != reply_id_expected)
        return MIG_REPLY_MISMATCH;

    if ((reply_bits & MACH_MSGH_BITS_COMPLEX) == 0) {
        if (reply_size != CGS_ERROR_SIZE)
            return MIG_TYPE_ERROR;
        retcode = (int32_t)get_u32(message + CGS_REPLY_RETCODE_OFF);
        fprintf(stderr,
                "PM_CGS_SESSION_PORT_%s_SIMPLE_REPLY:retcode=%ld hex=0x%08lx\n",
                label,
                (long)retcode,
                (unsigned long)(uint32_t)retcode);
        fflush(stderr);
        return (kern_return_t)retcode;
    }

    descriptor_count = get_u32(message + CGS_REPLY_DESC_COUNT_OFF);
    out_port = (mach_port_t)get_u32(message + CGS_REPLY_PORT_OFF);
    descriptor_word = get_u32(message + CGS_REPLY_DESCRIPTOR_WORD_OFF);
    disposition = (uint32_t)message[CGS_REPLY_DESCRIPTOR_DISPOSITION_OFF];
    descriptor_type = (uint32_t)message[CGS_REPLY_DESCRIPTOR_TYPE_OFF];

    fprintf(stderr,
            "PM_CGS_SESSION_PORT_%s_COMPLEX_REPLY:descriptor_count=%lu port=0x%08lx descriptorWord=0x%08lx disposition=0x%02lx type=0x%02lx\n",
            label,
            (unsigned long)descriptor_count,
            (unsigned long)out_port,
            (unsigned long)descriptor_word,
            (unsigned long)disposition,
            (unsigned long)descriptor_type);
    fflush(stderr);

    if (reply_size != CGS_SUCCESS_SIZE ||
        descriptor_count != 1U ||
        out_port == MACH_PORT_NULL ||
        disposition != CGS_EXPECTED_PORT_DISPOSITION ||
        descriptor_type != CGS_EXPECTED_PORT_TYPE) {
        if (out_port != MACH_PORT_NULL)
            (void)mach_port_deallocate(mach_task_self(), out_port);
        return MIG_TYPE_ERROR;
    }

    *returned_port = out_port;
    return KERN_SUCCESS;
}

static int
layout_selfcheck(void)
{
    uint32_t lookup_storage[LION_LOOKUP_SEND_SIZE / sizeof(uint32_t)];
    unsigned char *lookup = (unsigned char *)lookup_storage;
    uint32_t cgs_storage[CGS_RECV_SIZE / sizeof(uint32_t)];
    unsigned char *cgs = (unsigned char *)cgs_storage;

    memset(lookup_storage, 0, sizeof(lookup_storage));
    if (!build_lion_lookup_request(lookup,
                                   (mach_port_t)0x11111111U,
                                   (mach_port_t)0x22222222U,
                                   kActiveServiceName,
                                   PRIVILEGED_SERVER_FLAG)) {
        fprintf(stderr,
                "PM_CGS_SESSION_PORT_LAYOUT_LOOKUP_FAILURE:bits=0x%08lx size=0x%08lx id=0x%08lx flags=0x%08lx%08lx\n",
                (unsigned long)get_u32(lookup + 0x00),
                (unsigned long)get_u32(lookup + 0x04),
                (unsigned long)get_u32(lookup + 0x14),
                (unsigned long)(uint32_t)
                    (get_u64(lookup + LION_LOOKUP_FLAGS_OFF) >> 32),
                (unsigned long)(uint32_t)
                    get_u64(lookup + LION_LOOKUP_FLAGS_OFF));
        marker("PM_CGS_SESSION_PORT_LAYOUT:FAIL_LOOKUP");
        return 0;
    }

    memset(cgs_storage, 0, sizeof(cgs_storage));
    put_u32(cgs + 0x00, CGS_REQUEST_BITS);
    put_u32(cgs + 0x04, CGS_SEND_SIZE);
    put_u32(cgs + 0x08, 0x11111111U);
    put_u32(cgs + 0x0c, 0x22222222U);
    put_u32(cgs + 0x14, CGS_GET_SESSION_PORT_REQUEST_ID);

    if (get_u32(cgs + 0x00) != CGS_REQUEST_BITS ||
        get_u32(cgs + 0x04) != CGS_SEND_SIZE ||
        get_u32(cgs + 0x14) != CGS_GET_SESSION_PORT_REQUEST_ID) {
        marker("PM_CGS_SESSION_PORT_LAYOUT:FAIL_CGS");
        return 0;
    }

    fprintf(stderr,
            "PM_CGS_SESSION_PORT_LAYOUT:lookup_id=0x%08lx lookup_send=0x%08lx lookup_recv=0x%08lx lookup_flags=0x%08lx%08lx getSessionPort_id=0x%08lx getSessionPort_reply=0x%08lx deathWatch_id=0x%08lx deathWatch_reply=0x%08lx cgs_send=0x%08lx cgs_recv=0x%08lx disposition=0x%02lx\n",
            (unsigned long)LION_LOOKUP_REQUEST_ID,
            (unsigned long)LION_LOOKUP_SEND_SIZE,
            (unsigned long)LION_LOOKUP_RECV_SIZE,
            (unsigned long)(uint32_t)(PRIVILEGED_SERVER_FLAG >> 32),
            (unsigned long)(uint32_t)PRIVILEGED_SERVER_FLAG,
            (unsigned long)CGS_GET_SESSION_PORT_REQUEST_ID,
            (unsigned long)CGS_GET_SESSION_PORT_REPLY_ID,
            (unsigned long)CGS_DEATHWATCH_REQUEST_ID,
            (unsigned long)CGS_DEATHWATCH_REPLY_ID,
            (unsigned long)CGS_SEND_SIZE,
            (unsigned long)CGS_RECV_SIZE,
            (unsigned long)CGS_EXPECTED_PORT_DISPOSITION);
    marker("PM_CGS_SESSION_PORT_LAYOUT:PASS");
    return 1;
}

static int
run_snow_control(mach_port_t bp)
{
    mach_port_t session_port = MACH_PORT_NULL;
    mach_port_t deathwatch_port = MACH_PORT_NULL;
    kern_return_t kr;

    marker("PM_CGS_SESSION_PORT_MILESTONE:S00_BEFORE_LEGACY_SESSION_LOOKUP");
    kr = bootstrap_look_up(bp, kSessionServiceName, &session_port);
    fprintf(stderr,
            "PM_CGS_SESSION_PORT_SNOW_LOOKUP_RETURN:kr=%ld hex=0x%08lx sessionPort=0x%08lx\n",
            (long)kr,
            (unsigned long)(uint32_t)kr,
            (unsigned long)session_port);
    fflush(stderr);
    marker("PM_CGS_SESSION_PORT_MILESTONE:S01_AFTER_LEGACY_SESSION_LOOKUP");

    if (kr != KERN_SUCCESS || session_port == MACH_PORT_NULL)
        return 20;
    if (!has_send_right(session_port)) {
        (void)mach_port_deallocate(mach_task_self(), session_port);
        return 21;
    }

    marker("PM_CGS_SESSION_PORT_MILESTONE:S02_BEFORE_DEATHWATCH");
    kr = cgs_port_rpc(session_port,
                      CGS_DEATHWATCH_REQUEST_ID,
                      CGS_DEATHWATCH_REPLY_ID,
                      "DEATHWATCH",
                      &deathwatch_port);
    marker("PM_CGS_SESSION_PORT_MILESTONE:S03_AFTER_DEATHWATCH");

    (void)mach_port_deallocate(mach_task_self(), session_port);

    if (kr != KERN_SUCCESS || deathwatch_port == MACH_PORT_NULL)
        return 22;
    if (!has_send_right(deathwatch_port)) {
        (void)mach_port_deallocate(mach_task_self(), deathwatch_port);
        return 23;
    }

    (void)mach_port_deallocate(mach_task_self(), deathwatch_port);
    marker("PM_CGS_SESSION_PORT_RESULT:SNOW_CONTROL_PASS");
    return 0;
}

static int
run_lion_native_session(mach_port_t bp)
{
    mach_port_t root_port = MACH_PORT_NULL;
    mach_port_t session_port = MACH_PORT_NULL;
    mach_port_t deathwatch_port = MACH_PORT_NULL;
    kern_return_t kr;

    marker("PM_CGS_SESSION_PORT_MILESTONE:L00_BEFORE_ROOT_LOOKUP");
    kr = lion_lookup_active_windowserver(bp, &root_port);
    marker("PM_CGS_SESSION_PORT_MILESTONE:L01_AFTER_ROOT_LOOKUP");
    if (kr != KERN_SUCCESS || root_port == MACH_PORT_NULL)
        return 30;
    if (!has_send_right(root_port)) {
        (void)mach_port_deallocate(mach_task_self(), root_port);
        return 31;
    }

    marker("PM_CGS_SESSION_PORT_MILESTONE:L02_BEFORE_GETSESSIONPORT");
    kr = cgs_port_rpc(root_port,
                      CGS_GET_SESSION_PORT_REQUEST_ID,
                      CGS_GET_SESSION_PORT_REPLY_ID,
                      "GETSESSIONPORT",
                      &session_port);
    marker("PM_CGS_SESSION_PORT_MILESTONE:L03_AFTER_GETSESSIONPORT");
    (void)mach_port_deallocate(mach_task_self(), root_port);

    if (kr != KERN_SUCCESS || session_port == MACH_PORT_NULL)
        return 32;
    if (!has_send_right(session_port)) {
        (void)mach_port_deallocate(mach_task_self(), session_port);
        return 33;
    }

    marker("PM_CGS_SESSION_PORT_MILESTONE:L04_BEFORE_DEATHWATCH");
    kr = cgs_port_rpc(session_port,
                      CGS_DEATHWATCH_REQUEST_ID,
                      CGS_DEATHWATCH_REPLY_ID,
                      "DEATHWATCH",
                      &deathwatch_port);
    marker("PM_CGS_SESSION_PORT_MILESTONE:L05_AFTER_DEATHWATCH");
    (void)mach_port_deallocate(mach_task_self(), session_port);

    if (kr != KERN_SUCCESS || deathwatch_port == MACH_PORT_NULL)
        return 34;
    if (!has_send_right(deathwatch_port)) {
        (void)mach_port_deallocate(mach_task_self(), deathwatch_port);
        return 35;
    }

    (void)mach_port_deallocate(mach_task_self(), deathwatch_port);
    marker("PM_CGS_SESSION_PORT_RESULT:LION_NATIVE_SESSION_PROTOCOL_PASS");
    return 0;
}

int
main(int argc, char **argv)
{
    mach_port_t bp = MACH_PORT_NULL;
    kern_return_t kr;

    marker(BUILD_MARKER);
    marker("PM_CGS_SESSION_PORT_MILESTONE:M00_MAIN_ENTER");

    if (argc != 2) {
        marker("PM_CGS_SESSION_PORT_RESULT:MODE_REQUIRED");
        return 40;
    }

    if (!layout_selfcheck())
        return 41;

    kr = task_get_special_port(mach_task_self(),
                               BOOTSTRAP_SPECIAL_PORT,
                               &bp);
    fprintf(stderr,
            "PM_CGS_SESSION_PORT_BOOTSTRAP_SPECIAL_PORT:kr=%ld hex=0x%08lx port=0x%08lx global=0x%08lx\n",
            (long)kr,
            (unsigned long)(uint32_t)kr,
            (unsigned long)bp,
            (unsigned long)bootstrap_port);
    fflush(stderr);

    if (kr != KERN_SUCCESS || bp == MACH_PORT_NULL) {
        marker("PM_CGS_SESSION_PORT_RESULT:BOOTSTRAP_PORT_FAILURE");
        return 42;
    }

    if (strcmp(argv[1], "snow-control") == 0)
        return run_snow_control(bp);
    if (strcmp(argv[1], "lion-native-session") == 0)
        return run_lion_native_session(bp);

    marker("PM_CGS_SESSION_PORT_RESULT:UNKNOWN_MODE");
    return 43;
}
