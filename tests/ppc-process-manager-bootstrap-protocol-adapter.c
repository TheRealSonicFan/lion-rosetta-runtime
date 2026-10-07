#include <mach/mach.h>
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

#define LION_LOOKUP_REQUEST_ID 0x00000194U
#define LION_LOOKUP_REPLY_ID   0x000001f8U
#define LION_LOOKUP_SEND_SIZE  0x000000bcU
#define LION_LOOKUP_RECV_SIZE  0x0000006cU
#define LION_LOOKUP_SUCCESS_SIZE 0x00000028U
#define LION_LOOKUP_ERROR_SIZE   0x00000024U
#define LION_LOOKUP_SERVICE_OFF 0x20U
#define LION_LOOKUP_PID_OFF     0xa0U
#define LION_LOOKUP_UUID_OFF    0xa4U
#define LION_LOOKUP_FLAGS_OFF   0xb4U
#define LION_LOOKUP_REPLY_DESC_COUNT_OFF 0x18U
#define LION_LOOKUP_REPLY_PORT_OFF       0x1cU
#define LION_LOOKUP_REPLY_RETCODE_OFF    0x20U
#define LION_LOOKUP_MSG_OPTIONS 0x03000003U

static const char *kServiceName = "com.apple.CoreServices.coreservicesd";

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
build_lion_lookup_request(unsigned char *buffer,
                          mach_port_t remote_port,
                          mach_port_t reply_port)
{
    uint32_t bits;
    uint32_t zero = 0;
    pid_t target_pid = 0;
    uint64_t flags = 0x0000000000000008ULL;

    memset(buffer, 0, LION_LOOKUP_SEND_SIZE);

    bits = (uint32_t)MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND,
                                    MACH_MSG_TYPE_MAKE_SEND_ONCE);

    put_u32(buffer + 0x00, bits);
    put_u32(buffer + 0x04, LION_LOOKUP_SEND_SIZE);
    put_u32(buffer + 0x08, (uint32_t)remote_port);
    put_u32(buffer + 0x0c, (uint32_t)reply_port);
    put_u32(buffer + 0x10, zero);
    put_u32(buffer + 0x14, LION_LOOKUP_REQUEST_ID);
    memcpy(buffer + 0x18, &NDR_record, sizeof(NDR_record));

    strncpy((char *)(buffer + LION_LOOKUP_SERVICE_OFF),
            kServiceName, 0x7f);
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
    if (memcmp(buffer + LION_LOOKUP_SERVICE_OFF,
               kServiceName, strlen(kServiceName) + 1) != 0)
        return 0;
    if (memcmp(buffer + LION_LOOKUP_UUID_OFF,
               "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
               16) != 0)
        return 0;

    return 1;
}

static int
layout_selfcheck(void)
{
    uint32_t storage[LION_LOOKUP_SEND_SIZE / sizeof(uint32_t)];
    unsigned char *buffer = (unsigned char *)storage;

    memset(storage, 0, sizeof(storage));
    if (!build_lion_lookup_request(buffer, (mach_port_t)0x11111111U,
                                   (mach_port_t)0x22222222U)) {
        marker("PM_BOOTSTRAP_ADAPTER_LAYOUT:FAIL");
        return 0;
    }

    fprintf(stderr,
            "PM_BOOTSTRAP_ADAPTER_LAYOUT:request_id=0x%08lx send_size=0x%08lx recv_size=0x%08lx service_off=0x%02lx pid_off=0x%02lx uuid_off=0x%02lx flags_off=0x%02lx\n",
            (unsigned long)LION_LOOKUP_REQUEST_ID,
            (unsigned long)LION_LOOKUP_SEND_SIZE,
            (unsigned long)LION_LOOKUP_RECV_SIZE,
            (unsigned long)LION_LOOKUP_SERVICE_OFF,
            (unsigned long)LION_LOOKUP_PID_OFF,
            (unsigned long)LION_LOOKUP_UUID_OFF,
            (unsigned long)LION_LOOKUP_FLAGS_OFF);
    marker("PM_BOOTSTRAP_ADAPTER_LAYOUT:PASS");
    return 1;
}

static int
run_snow_control(void)
{
    mach_port_t service_port = MACH_PORT_NULL;
    kern_return_t kr;

    marker("PM_BOOTSTRAP_ADAPTER_MILESTONE:S00_BEFORE_LEGACY_LOOKUP");
    kr = bootstrap_look_up2(bootstrap_port, kServiceName,
                            &service_port, (pid_t)0,
                            (uint64_t)0x00000008ULL);
    fprintf(stderr,
            "PM_BOOTSTRAP_ADAPTER_SNOW_RETURN:kr=%ld hex=0x%08lx servicePort=0x%08lx\n",
            (long)kr,
            (unsigned long)((uint32_t)kr),
            (unsigned long)service_port);
    fflush(stderr);
    marker("PM_BOOTSTRAP_ADAPTER_MILESTONE:S01_AFTER_LEGACY_LOOKUP");

    if (kr != KERN_SUCCESS) {
        marker("PM_BOOTSTRAP_ADAPTER_RESULT:SNOW_LEGACY_LOOKUP_ERROR");
        return 20;
    }
    if (service_port == MACH_PORT_NULL) {
        marker("PM_BOOTSTRAP_ADAPTER_RESULT:SNOW_LEGACY_ZERO_PORT");
        return 21;
    }

    (void)mach_port_deallocate(mach_task_self(), service_port);
    marker("PM_BOOTSTRAP_ADAPTER_RESULT:SNOW_CONTROL_PASS");
    return 0;
}

static int
run_lion_adapter(void)
{
    uint32_t storage[LION_LOOKUP_SEND_SIZE / sizeof(uint32_t)];
    unsigned char *message = (unsigned char *)storage;
    mach_port_t reply_port;
    mach_port_t service_port;
    mach_msg_return_t mr;
    uint32_t reply_bits;
    uint32_t reply_size;
    uint32_t reply_id;
    uint32_t descriptor_count;
    int32_t retcode;

    reply_port = mig_get_reply_port();
    if (reply_port == MACH_PORT_NULL) {
        marker("PM_BOOTSTRAP_ADAPTER_RESULT:REPLY_PORT_NULL");
        return 22;
    }

    if (!build_lion_lookup_request(message, bootstrap_port, reply_port)) {
        marker("PM_BOOTSTRAP_ADAPTER_RESULT:LAYOUT_BUILD_FAILED");
        return 23;
    }

    fprintf(stderr,
            "PM_BOOTSTRAP_ADAPTER_REQUEST:bootstrapPort=0x%08lx replyPort=0x%08lx id=0x%08lx send=0x%08lx recv=0x%08lx target_pid=0 uuid=ZERO flags=0x0000000000000008\n",
            (unsigned long)bootstrap_port,
            (unsigned long)reply_port,
            (unsigned long)LION_LOOKUP_REQUEST_ID,
            (unsigned long)LION_LOOKUP_SEND_SIZE,
            (unsigned long)LION_LOOKUP_RECV_SIZE);
    fflush(stderr);

    marker("PM_BOOTSTRAP_ADAPTER_MILESTONE:L00_BEFORE_LION_FORMAT_MACH_MSG");
    mr = mach_msg((mach_msg_header_t *)message,
                  (mach_msg_option_t)LION_LOOKUP_MSG_OPTIONS,
                  (mach_msg_size_t)LION_LOOKUP_SEND_SIZE,
                  (mach_msg_size_t)LION_LOOKUP_RECV_SIZE,
                  reply_port,
                  MACH_MSG_TIMEOUT_NONE,
                  MACH_PORT_NULL);
    fprintf(stderr,
            "PM_BOOTSTRAP_ADAPTER_MACH_MSG_RETURN:kr=%ld hex=0x%08lx\n",
            (long)mr, (unsigned long)((uint32_t)mr));
    fflush(stderr);
    marker("PM_BOOTSTRAP_ADAPTER_MILESTONE:L01_AFTER_LION_FORMAT_MACH_MSG");

    if (mr != MACH_MSG_SUCCESS) {
        marker("PM_BOOTSTRAP_ADAPTER_RESULT:MACH_MSG_ERROR");
        return 24;
    }

    reply_bits = get_u32(message + 0x00);
    reply_size = get_u32(message + 0x04);
    reply_id = get_u32(message + 0x14);

    fprintf(stderr,
            "PM_BOOTSTRAP_ADAPTER_REPLY:bits=0x%08lx size=0x%08lx id=0x%08lx\n",
            (unsigned long)reply_bits,
            (unsigned long)reply_size,
            (unsigned long)reply_id);
    fflush(stderr);

    if (reply_id != LION_LOOKUP_REPLY_ID) {
        marker("PM_BOOTSTRAP_ADAPTER_RESULT:REPLY_ID_MISMATCH");
        return 25;
    }

    if ((reply_bits & MACH_MSGH_BITS_COMPLEX) != 0) {
        descriptor_count = get_u32(message +
                                   LION_LOOKUP_REPLY_DESC_COUNT_OFF);
        service_port = (mach_port_t)get_u32(message +
                                            LION_LOOKUP_REPLY_PORT_OFF);
        fprintf(stderr,
                "PM_BOOTSTRAP_ADAPTER_COMPLEX_REPLY:descriptor_count=%lu servicePort=0x%08lx\n",
                (unsigned long)descriptor_count,
                (unsigned long)service_port);
        fflush(stderr);

        if (reply_size != LION_LOOKUP_SUCCESS_SIZE ||
            descriptor_count != 1) {
            marker("PM_BOOTSTRAP_ADAPTER_RESULT:COMPLEX_REPLY_SHAPE_ERROR");
            return 26;
        }
        if (service_port == MACH_PORT_NULL) {
            marker("PM_BOOTSTRAP_ADAPTER_RESULT:ADAPTER_ZERO_PORT");
            return 27;
        }

        (void)mach_port_deallocate(mach_task_self(), service_port);
        marker("PM_BOOTSTRAP_ADAPTER_RESULT:ADAPTER_LOOKUP_PASS");
        return 0;
    }

    if (reply_size == LION_LOOKUP_ERROR_SIZE) {
        retcode = (int32_t)get_u32(message +
                                   LION_LOOKUP_REPLY_RETCODE_OFF);
        fprintf(stderr,
                "PM_BOOTSTRAP_ADAPTER_SIMPLE_REPLY:retcode=%ld hex=0x%08lx\n",
                (long)retcode,
                (unsigned long)((uint32_t)retcode));
        fflush(stderr);
        if (retcode == -304)
            marker("PM_BOOTSTRAP_ADAPTER_RESULT:ADAPTER_MIG_BAD_ARGUMENTS");
        else
            marker("PM_BOOTSTRAP_ADAPTER_RESULT:ADAPTER_SERVER_ERROR");
        return 28;
    }

    marker("PM_BOOTSTRAP_ADAPTER_RESULT:REPLY_SHAPE_ERROR");
    return 29;
}

int
main(int argc, char **argv)
{
    const char *override_name = getenv("CORESERVICESD_SERVICE_NAME");
    const char *dont_use_server = getenv("SCDontUseServer");

    marker("PM_BOOTSTRAP_ADAPTER_MILESTONE:M00_MAIN_ENTER");
    fprintf(stderr, "PM_BOOTSTRAP_ADAPTER_BOOTSTRAP_PORT:0x%08lx\n",
            (unsigned long)bootstrap_port);
    fprintf(stderr,
            "PM_BOOTSTRAP_ADAPTER_ENV:CORESERVICESD_SERVICE_NAME=%s\n",
            override_name ? "SET" : "UNSET");
    fprintf(stderr,
            "PM_BOOTSTRAP_ADAPTER_ENV:SCDontUseServer=%s\n",
            dont_use_server ? "SET" : "UNSET");
    fflush(stderr);

    if (override_name || dont_use_server) {
        marker("PM_BOOTSTRAP_ADAPTER_RESULT:ENVIRONMENT_NOT_CLEAN");
        return 30;
    }
    if (bootstrap_port == MACH_PORT_NULL) {
        marker("PM_BOOTSTRAP_ADAPTER_RESULT:BOOTSTRAP_PORT_NULL");
        return 31;
    }
    if (!layout_selfcheck())
        return 32;

    if (argc != 2) {
        marker("PM_BOOTSTRAP_ADAPTER_RESULT:MODE_REQUIRED");
        return 33;
    }

    if (strcmp(argv[1], "snow-control") == 0)
        return run_snow_control();
    if (strcmp(argv[1], "lion-adapter") == 0)
        return run_lion_adapter();

    marker("PM_BOOTSTRAP_ADAPTER_RESULT:UNKNOWN_MODE");
    return 34;
}
