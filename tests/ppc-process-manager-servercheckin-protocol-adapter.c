#include <mach/mach.h>
#include <mach/mig_errors.h>
#include <mach/ndr.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>

extern mach_port_t bootstrap_port;
extern kern_return_t bootstrap_look_up2(mach_port_t,
                                         const char *,
                                         mach_port_t *,
                                         pid_t,
                                         uint64_t);
extern mach_port_t mig_get_reply_port(void);

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

#define CHECKIN_REQUEST_ID 0x00002710U
#define CHECKIN_REPLY_ID 0x00002774U
#define CHECKIN_LEGACY_SEND_SIZE 0x00000028U
#define CHECKIN_LION_SEND_SIZE 0x00000018U
#define CHECKIN_RECV_SIZE 0x0000003cU
#define CHECKIN_SUCCESS_SIZE 0x00000034U
#define CHECKIN_ERROR_SIZE 0x00000024U
#define CHECKIN_REPLY_DESC_COUNT_OFF 0x18U
#define CHECKIN_REPLY_PORT_OFF 0x1cU
#define CHECKIN_REPLY_DISPOSITION_OFF 0x26U
#define CHECKIN_REPLY_TYPE_OFF 0x27U
#define CHECKIN_REPLY_OPTIONS_OFF 0x30U
#define CHECKIN_REPLY_RETCODE_OFF 0x20U

#define MSG_OPTIONS 0x00000003U
#define PRIVILEGED_SERVER_FLAG 0x0000000000000008ULL

static const char *kCoreServicesDName =
    "com.apple.CoreServices.coreservicesd";

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

static int
layout_selfcheck(void)
{
    uint32_t legacy[CHECKIN_LEGACY_SEND_SIZE / 4];
    uint32_t lion[CHECKIN_LION_SEND_SIZE / 4];
    unsigned char *a = (unsigned char *)legacy;
    unsigned char *b = (unsigned char *)lion;

    memset(legacy, 0, sizeof(legacy));
    memset(lion, 0, sizeof(lion));

    put_u32(a + 0x00, 0x80001513U);
    put_u32(a + 0x04, CHECKIN_LEGACY_SEND_SIZE);
    put_u32(a + 0x14, CHECKIN_REQUEST_ID);
    put_u32(a + 0x18, 1U);
    put_u32(a + 0x1c, 0x11111111U);
    a[0x26] = 0x13;
    a[0x27] = 0x00;

    put_u32(b + 0x00, 0x00001513U);
    put_u32(b + 0x04, CHECKIN_LION_SEND_SIZE);
    put_u32(b + 0x14, CHECKIN_REQUEST_ID);

    if (get_u32(a + 0x00) != 0x80001513U ||
        get_u32(a + 0x04) != CHECKIN_LEGACY_SEND_SIZE ||
        get_u32(a + 0x18) != 1U ||
        a[0x26] != 0x13 ||
        a[0x27] != 0x00 ||
        get_u32(b + 0x00) != 0x00001513U ||
        get_u32(b + 0x04) != CHECKIN_LION_SEND_SIZE) {
        marker("PM_SERVERCHECKIN_LAYOUT:FAIL");
        return 0;
    }

    fprintf(stderr,
            "PM_SERVERCHECKIN_LAYOUT:request_id=0x%08lx legacy_send=0x%08lx lion_send=0x%08lx recv=0x%08lx reply_id=0x%08lx\n",
            (unsigned long)CHECKIN_REQUEST_ID,
            (unsigned long)CHECKIN_LEGACY_SEND_SIZE,
            (unsigned long)CHECKIN_LION_SEND_SIZE,
            (unsigned long)CHECKIN_RECV_SIZE,
            (unsigned long)CHECKIN_REPLY_ID);
    marker("PM_SERVERCHECKIN_LAYOUT:PASS");
    return 1;
}

static kern_return_t
lion_bootstrap_lookup(mach_port_t *service_port)
{
    uint32_t storage[LOOKUP_SEND_SIZE / 4];
    unsigned char *m = (unsigned char *)storage;
    mach_port_t reply_port;
    mach_msg_return_t mr;
    uint32_t bits, size, msgid, count;
    int32_t retcode;
    pid_t target_pid = 0;

    memset(storage, 0, sizeof(storage));
    reply_port = mig_get_reply_port();
    if (reply_port == MACH_PORT_NULL)
        return KERN_FAILURE;

    put_u32(m + 0x00, 0x00001513U);
    put_u32(m + 0x04, LOOKUP_SEND_SIZE);
    put_u32(m + 0x08, (uint32_t)bootstrap_port);
    put_u32(m + 0x0c, (uint32_t)reply_port);
    put_u32(m + 0x14, LOOKUP_REQUEST_ID);
    memcpy(m + 0x18, &NDR_record, sizeof(NDR_record));
    strncpy((char *)(m + LOOKUP_SERVICE_OFF), kCoreServicesDName, 0x7f);
    ((char *)(m + LOOKUP_SERVICE_OFF))[0x7f] = '\0';
    memcpy(m + LOOKUP_PID_OFF, &target_pid, sizeof(target_pid));
    memset(m + LOOKUP_UUID_OFF, 0, 16);
    put_u64(m + LOOKUP_FLAGS_OFF, PRIVILEGED_SERVER_FLAG);

    marker("PM_SERVERCHECKIN_MILESTONE:L00_BEFORE_ADAPTED_BOOTSTRAP");
    mr = mach_msg((mach_msg_header_t *)m,
                  (mach_msg_option_t)MSG_OPTIONS,
                  LOOKUP_SEND_SIZE,
                  LOOKUP_RECV_SIZE,
                  reply_port,
                  MACH_MSG_TIMEOUT_NONE,
                  MACH_PORT_NULL);
    fprintf(stderr,
            "PM_SERVERCHECKIN_BOOTSTRAP_MACH_MSG:kr=%ld hex=0x%08lx\n",
            (long)mr, (unsigned long)((uint32_t)mr));
    fflush(stderr);
    marker("PM_SERVERCHECKIN_MILESTONE:L01_AFTER_ADAPTED_BOOTSTRAP");

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    bits = get_u32(m + 0x00);
    size = get_u32(m + 0x04);
    msgid = get_u32(m + 0x14);

    fprintf(stderr,
            "PM_SERVERCHECKIN_BOOTSTRAP_REPLY:bits=0x%08lx size=0x%08lx id=0x%08lx\n",
            (unsigned long)bits, (unsigned long)size,
            (unsigned long)msgid);
    fflush(stderr);

    if (msgid != LOOKUP_REPLY_ID)
        return MIG_REPLY_MISMATCH;

    if ((bits & MACH_MSGH_BITS_COMPLEX) != 0) {
        count = get_u32(m + LOOKUP_REPLY_DESC_COUNT_OFF);
        if (size != LOOKUP_SUCCESS_SIZE || count != 1U)
            return MIG_TYPE_ERROR;
        *service_port =
            (mach_port_t)get_u32(m + LOOKUP_REPLY_PORT_OFF);
        if (*service_port == MACH_PORT_NULL)
            return KERN_FAILURE;
        fprintf(stderr,
                "PM_SERVERCHECKIN_BOOTSTRAP_RESULT:LOOKUP_PASS servicePort=0x%08lx\n",
                (unsigned long)*service_port);
        fflush(stderr);
        return KERN_SUCCESS;
    }

    if (size == LOOKUP_ERROR_SIZE) {
        retcode = (int32_t)get_u32(m + LOOKUP_REPLY_RETCODE_OFF);
        fprintf(stderr,
                "PM_SERVERCHECKIN_BOOTSTRAP_ERROR:retcode=%ld hex=0x%08lx\n",
                (long)retcode, (unsigned long)((uint32_t)retcode));
        fflush(stderr);
        return retcode;
    }

    return MIG_TYPE_ERROR;
}

static kern_return_t
send_server_checkin(mach_port_t server_port,
                    int lion_simple,
                    mach_port_t *session_port,
                    uint32_t *options)
{
    uint32_t storage[CHECKIN_RECV_SIZE / 4];
    unsigned char *m = (unsigned char *)storage;
    mach_port_t reply_port;
    mach_msg_size_t send_size;
    mach_msg_return_t mr;
    uint32_t bits, size, msgid, count;
    int32_t retcode;

    memset(storage, 0, sizeof(storage));
    reply_port = mig_get_reply_port();
    if (reply_port == MACH_PORT_NULL)
        return KERN_FAILURE;

    if (lion_simple) {
        put_u32(m + 0x00, 0x00001513U);
        send_size = CHECKIN_LION_SEND_SIZE;
    } else {
        put_u32(m + 0x00, 0x80001513U);
        send_size = CHECKIN_LEGACY_SEND_SIZE;
    }

    put_u32(m + 0x04, send_size);
    put_u32(m + 0x08, (uint32_t)server_port);
    put_u32(m + 0x0c, (uint32_t)reply_port);
    put_u32(m + 0x14, CHECKIN_REQUEST_ID);

    if (!lion_simple) {
        put_u32(m + 0x18, 1U);
        put_u32(m + 0x1c, (uint32_t)mach_task_self());
        put_u32(m + 0x20, 0U);
        m[0x24] = 0;
        m[0x25] = 0;
        m[0x26] = 0x13;
        m[0x27] = 0x00;
    }

    fprintf(stderr,
            "PM_SERVERCHECKIN_REQUEST:mode=%s bits=0x%08lx id=0x%08lx send=0x%08lx recv=0x%08lx serverPort=0x%08lx replyPort=0x%08lx\n",
            lion_simple ? "lion-simple" : "snow-legacy",
            (unsigned long)get_u32(m + 0x00),
            (unsigned long)CHECKIN_REQUEST_ID,
            (unsigned long)send_size,
            (unsigned long)CHECKIN_RECV_SIZE,
            (unsigned long)server_port,
            (unsigned long)reply_port);
    fflush(stderr);

    marker("PM_SERVERCHECKIN_MILESTONE:C00_BEFORE_SERVERCHECKIN");
    mr = mach_msg((mach_msg_header_t *)m,
                  (mach_msg_option_t)MSG_OPTIONS,
                  send_size,
                  CHECKIN_RECV_SIZE,
                  reply_port,
                  MACH_MSG_TIMEOUT_NONE,
                  MACH_PORT_NULL);
    fprintf(stderr,
            "PM_SERVERCHECKIN_MACH_MSG:kr=%ld hex=0x%08lx\n",
            (long)mr, (unsigned long)((uint32_t)mr));
    fflush(stderr);
    marker("PM_SERVERCHECKIN_MILESTONE:C01_AFTER_SERVERCHECKIN");

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    bits = get_u32(m + 0x00);
    size = get_u32(m + 0x04);
    msgid = get_u32(m + 0x14);

    fprintf(stderr,
            "PM_SERVERCHECKIN_REPLY:bits=0x%08lx size=0x%08lx id=0x%08lx\n",
            (unsigned long)bits, (unsigned long)size,
            (unsigned long)msgid);
    fflush(stderr);

    if (msgid != CHECKIN_REPLY_ID)
        return MIG_REPLY_MISMATCH;

    if ((bits & MACH_MSGH_BITS_COMPLEX) != 0) {
        count = get_u32(m + CHECKIN_REPLY_DESC_COUNT_OFF);
        *session_port =
            (mach_port_t)get_u32(m + CHECKIN_REPLY_PORT_OFF);
        *options = get_u32(m + CHECKIN_REPLY_OPTIONS_OFF);
        fprintf(stderr,
                "PM_SERVERCHECKIN_COMPLEX_REPLY:descriptor_count=%lu disposition=0x%02x type=0x%02x sessionPort=0x%08lx options=0x%08lx\n",
                (unsigned long)count,
                (unsigned int)m[CHECKIN_REPLY_DISPOSITION_OFF],
                (unsigned int)m[CHECKIN_REPLY_TYPE_OFF],
                (unsigned long)*session_port,
                (unsigned long)*options);
        fflush(stderr);

        if (size != CHECKIN_SUCCESS_SIZE ||
            count != 1U ||
            m[CHECKIN_REPLY_DISPOSITION_OFF] != 0x11 ||
            m[CHECKIN_REPLY_TYPE_OFF] != 0x00 ||
            *session_port == MACH_PORT_NULL)
            return MIG_TYPE_ERROR;

        return KERN_SUCCESS;
    }

    if (size == CHECKIN_ERROR_SIZE) {
        retcode =
            (int32_t)get_u32(m + CHECKIN_REPLY_RETCODE_OFF);
        fprintf(stderr,
                "PM_SERVERCHECKIN_SIMPLE_REPLY:retcode=%ld hex=0x%08lx\n",
                (long)retcode,
                (unsigned long)((uint32_t)retcode));
        fflush(stderr);
        return retcode;
    }

    return MIG_TYPE_ERROR;
}

static int
run_snow_control(void)
{
    mach_port_t server_port = MACH_PORT_NULL;
    mach_port_t session_port = MACH_PORT_NULL;
    uint32_t options = 0;
    kern_return_t kr;

    marker("PM_SERVERCHECKIN_MILESTONE:S00_BEFORE_BOOTSTRAP");
    kr = bootstrap_look_up2(bootstrap_port,
                            kCoreServicesDName,
                            &server_port,
                            (pid_t)0,
                            PRIVILEGED_SERVER_FLAG);
    fprintf(stderr,
            "PM_SERVERCHECKIN_SNOW_BOOTSTRAP:kr=%ld hex=0x%08lx servicePort=0x%08lx\n",
            (long)kr, (unsigned long)((uint32_t)kr),
            (unsigned long)server_port);
    fflush(stderr);
    marker("PM_SERVERCHECKIN_MILESTONE:S01_AFTER_BOOTSTRAP");

    if (kr != KERN_SUCCESS || server_port == MACH_PORT_NULL) {
        marker("PM_SERVERCHECKIN_RESULT:SNOW_BOOTSTRAP_FAILURE");
        return 20;
    }

    kr = send_server_checkin(server_port, 0,
                             &session_port, &options);
    fprintf(stderr,
            "PM_SERVERCHECKIN_SNOW_RETURN:kr=%ld hex=0x%08lx sessionPort=0x%08lx options=0x%08lx\n",
            (long)kr, (unsigned long)((uint32_t)kr),
            (unsigned long)session_port,
            (unsigned long)options);
    fflush(stderr);

    if (session_port != MACH_PORT_NULL)
        (void)mach_port_deallocate(mach_task_self(), session_port);
    (void)mach_port_deallocate(mach_task_self(), server_port);

    if (kr != KERN_SUCCESS || session_port == MACH_PORT_NULL) {
        marker("PM_SERVERCHECKIN_RESULT:SNOW_SERVERCHECKIN_FAILURE");
        return 21;
    }

    marker("PM_SERVERCHECKIN_RESULT:SNOW_CONTROL_PASS");
    return 0;
}

static int
run_lion_adapter(void)
{
    mach_port_t server_port = MACH_PORT_NULL;
    mach_port_t session_port = MACH_PORT_NULL;
    uint32_t options = 0;
    kern_return_t kr;

    kr = lion_bootstrap_lookup(&server_port);
    if (kr != KERN_SUCCESS || server_port == MACH_PORT_NULL) {
        fprintf(stderr,
                "PM_SERVERCHECKIN_LION_BOOTSTRAP_FAILURE:kr=%ld hex=0x%08lx servicePort=0x%08lx\n",
                (long)kr, (unsigned long)((uint32_t)kr),
                (unsigned long)server_port);
        marker("PM_SERVERCHECKIN_RESULT:LION_BOOTSTRAP_FAILURE");
        return 22;
    }

    kr = send_server_checkin(server_port, 1,
                             &session_port, &options);
    fprintf(stderr,
            "PM_SERVERCHECKIN_LION_RETURN:kr=%ld hex=0x%08lx sessionPort=0x%08lx options=0x%08lx\n",
            (long)kr, (unsigned long)((uint32_t)kr),
            (unsigned long)session_port,
            (unsigned long)options);
    fflush(stderr);

    if (session_port != MACH_PORT_NULL)
        (void)mach_port_deallocate(mach_task_self(), session_port);
    (void)mach_port_deallocate(mach_task_self(), server_port);

    if (kr == KERN_SUCCESS && session_port != MACH_PORT_NULL) {
        marker("PM_SERVERCHECKIN_RESULT:LION_SERVERCHECKIN_PASS");
        return 0;
    }

    if (kr == MIG_BAD_ARGUMENTS)
        marker("PM_SERVERCHECKIN_RESULT:LION_MIG_BAD_ARGUMENTS");
    else if (kr == MIG_TYPE_ERROR)
        marker("PM_SERVERCHECKIN_RESULT:LION_MIG_TYPE_ERROR");
    else
        marker("PM_SERVERCHECKIN_RESULT:LION_SERVERCHECKIN_ERROR");
    return 23;
}

int
main(int argc, char **argv)
{
    const char *override_name = getenv("CORESERVICESD_SERVICE_NAME");
    const char *dont_use_server = getenv("SCDontUseServer");

    marker("PM_SERVERCHECKIN_MILESTONE:M00_MAIN_ENTER");
    fprintf(stderr,
            "PM_SERVERCHECKIN_ENV:CORESERVICESD_SERVICE_NAME=%s\n",
            override_name ? "SET" : "UNSET");
    fprintf(stderr,
            "PM_SERVERCHECKIN_ENV:SCDontUseServer=%s\n",
            dont_use_server ? "SET" : "UNSET");
    fprintf(stderr,
            "PM_SERVERCHECKIN_BOOTSTRAP_PORT:0x%08lx\n",
            (unsigned long)bootstrap_port);
    fflush(stderr);

    if (override_name || dont_use_server) {
        marker("PM_SERVERCHECKIN_RESULT:ENVIRONMENT_NOT_CLEAN");
        return 30;
    }
    if (bootstrap_port == MACH_PORT_NULL) {
        marker("PM_SERVERCHECKIN_RESULT:BOOTSTRAP_PORT_NULL");
        return 31;
    }
    if (!layout_selfcheck())
        return 32;
    if (argc != 2) {
        marker("PM_SERVERCHECKIN_RESULT:MODE_REQUIRED");
        return 33;
    }

    if (strcmp(argv[1], "snow-control") == 0)
        return run_snow_control();
    if (strcmp(argv[1], "lion-adapter") == 0)
        return run_lion_adapter();

    marker("PM_SERVERCHECKIN_RESULT:UNKNOWN_MODE");
    return 34;
}
