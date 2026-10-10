#include <arpa/inet.h>
#include <crt_externs.h>
#include <errno.h>
#include <mach/mach.h>
#include <pthread.h>
#include <servers/bootstrap.h>
#include <spawn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

extern kern_return_t bootstrap_look_up2(mach_port_t,
                                        const char *,
                                        mach_port_t *,
                                        pid_t,
                                        uint64_t);

#define BUILD_ID "distributed-notifications-ppc-ingress-interposer-v2"
#define BUILD_MARKER \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_INTERPOSER_BUILD_ID:" BUILD_ID

#define MODE_ENV "ROSETTA_DISTRIBUTED_NOTIFICATIONS_INGRESS_MODE"
#define MODE_PASSTHROUGH "passthrough"
#define MODE_LION "lion-ppc-ingress-v1"
#define BROKER_ENV "ROSETTA_DISTRIBUTED_NOTIFICATIONS_BROKER_PATH"

#define SERVICE_NAME "com.apple.distributed_notifications.2"
#define LOOKUP_FLAGS UINT64_C(8)

#define FRAME_MAGIC 0x44504e31U
#define FRAME_VERSION 1U
#define FRAME_REQUEST 1U
#define FRAME_CALLBACK 2U
#define FRAME_MAX_PAYLOAD (256U * 1024U)

#define LEGACY_MESSAGE_ID 4
#define LEGACY_HEADER_SIZE 0x20U
#define LEGACY_C2S_BITS 0x00001413U
#define LEGACY_S2C_BITS 0x00000013U
#define LEGACY_LENGTH_OFF 0x1cU
#define LEGACY_PAYLOAD_OFF 0x20U
#define LEGACY_CALLBACK_SEND_OPTIONS 0x11U
#define LEGACY_CALLBACK_TIMEOUT 0xfaU

typedef kern_return_t (*bootstrap_lookup2_fn)(mach_port_t,
                                               const char *,
                                               mach_port_t *,
                                               pid_t,
                                               uint64_t);

typedef struct FrameHeader {
    uint32_t magic;
    uint32_t version;
    uint32_t type;
    uint32_t length;
} FrameHeader;

struct interpose_tuple {
    const void *replacement;
    const void *replacee;
};

static kern_return_t
rosetta_distnotify_bootstrap_look_up2(mach_port_t bp,
                                      const char *service_name,
                                      mach_port_t *service_port,
                                      pid_t target_pid,
                                      uint64_t flags);

__attribute__((used))
static struct interpose_tuple sInterposes[1]
__attribute__((section("__DATA,__interpose"))) = {
    {
        (const void *)(uintptr_t)&rosetta_distnotify_bootstrap_look_up2,
        (const void *)(uintptr_t)&bootstrap_look_up2
    }
};

static bootstrap_lookup2_fn gOriginalLookup = NULL;
static mach_port_t gServiceReceivePort = MACH_PORT_NULL;
static mach_port_t gClientCallbackPort = MACH_PORT_NULL;
static int gIpcFd = -1;
static pid_t gBrokerPid = -1;
static pthread_t gMachThread;
static pthread_t gCallbackThread;
static int gBridgeStarted = 0;
static int gCleanupRegistered = 0;
static unsigned int gLookupCount = 0;
static unsigned int gMachRequestCount = 0;
static unsigned int gCallbackSendCount = 0;

static uint32_t
swap_u32(uint32_t value)
{
    return ((value & 0x000000ffU) << 24) |
           ((value & 0x0000ff00U) << 8) |
           ((value & 0x00ff0000U) >> 8) |
           ((value & 0xff000000U) >> 24);
}

static int
write_full(int fd, const void *buffer, size_t length)
{
    const unsigned char *p = (const unsigned char *)buffer;

    while (length > 0) {
        ssize_t n = write(fd, p, length);
        if (n < 0) {
            if (errno == EINTR)
                continue;
            return 0;
        }
        if (n == 0)
            return 0;
        p += n;
        length -= (size_t)n;
    }
    return 1;
}

static int
read_full(int fd, void *buffer, size_t length)
{
    unsigned char *p = (unsigned char *)buffer;

    while (length > 0) {
        ssize_t n = read(fd, p, length);
        if (n < 0) {
            if (errno == EINTR)
                continue;
            return 0;
        }
        if (n == 0)
            return 0;
        p += n;
        length -= (size_t)n;
    }
    return 1;
}

static int
send_frame(uint32_t type, const void *payload, uint32_t length)
{
    FrameHeader header;

    if (gIpcFd < 0 || payload == NULL || length == 0 ||
        length > FRAME_MAX_PAYLOAD)
        return 0;

    header.magic = htonl(FRAME_MAGIC);
    header.version = htonl(FRAME_VERSION);
    header.type = htonl(type);
    header.length = htonl(length);

    return write_full(gIpcFd, &header, sizeof(header)) &&
           write_full(gIpcFd, payload, length);
}

static int
broker_env_skip(const char *entry)
{
    static const char *const prefixes[] = {
        "DYLD_INSERT_LIBRARIES=",
        "DYLD_LIBRARY_PATH=",
        "DYLD_FRAMEWORK_PATH=",
        "DYLD_SHARED_CACHE_DONT_VALIDATE=",
        "ROSETTA_DISTRIBUTED_NOTIFICATIONS_INGRESS_MODE=",
        "ROSETTA_DISTRIBUTED_NOTIFICATIONS_BROKER_PATH="
    };
    size_t i;

    if (entry == NULL)
        return 1;

    for (i = 0; i < sizeof(prefixes) / sizeof(prefixes[0]); ++i) {
        size_t n = strlen(prefixes[i]);
        if (strncmp(entry, prefixes[i], n) == 0)
            return 1;
    }
    return 0;
}

static char **
build_broker_env(void)
{
    size_t count = 0;
    size_t kept = 0;
    size_t i;
    char ***environment_slot;
    char **environment;
    char **result;

    environment_slot = _NSGetEnviron();
    if (environment_slot == NULL || *environment_slot == NULL)
        return NULL;
    environment = *environment_slot;

    while (environment[count] != NULL)
        ++count;

    result = (char **)calloc(count + 1U, sizeof(char *));
    if (result == NULL)
        return NULL;

    for (i = 0; i < count; ++i) {
        if (!broker_env_skip(environment[i]))
            result[kept++] = environment[i];
    }
    result[kept] = NULL;
    return result;
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

static kern_return_t
call_original_lookup(mach_port_t bp,
                     const char *service_name,
                     mach_port_t *service_port,
                     pid_t target_pid,
                     uint64_t flags)
{
    bootstrap_lookup2_fn fn = original_lookup();

    if (fn == NULL ||
        fn == (bootstrap_lookup2_fn)&rosetta_distnotify_bootstrap_look_up2) {
        if (service_port != NULL)
            *service_port = MACH_PORT_NULL;
        return KERN_FAILURE;
    }

    return fn(bp, service_name, service_port, target_pid, flags);
}

static void
bridge_cleanup(void)
{
    int status = -1;

    if (gIpcFd >= 0) {
        (void)shutdown(gIpcFd, SHUT_RDWR);
        (void)close(gIpcFd);
        gIpcFd = -1;
    }

    if (gServiceReceivePort != MACH_PORT_NULL) {
        (void)mach_port_destroy(
            mach_task_self(), gServiceReceivePort);
        gServiceReceivePort = MACH_PORT_NULL;
    }

    if (gClientCallbackPort != MACH_PORT_NULL) {
        (void)mach_port_deallocate(
            mach_task_self(), gClientCallbackPort);
        gClientCallbackPort = MACH_PORT_NULL;
    }

    if (gBrokerPid > 0) {
        if (waitpid(gBrokerPid, &status, 0) < 0)
            status = -1;
        fprintf(stderr,
                "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_WAIT:pid=%ld exit=%d\n",
                (long)gBrokerPid,
                (status >= 0 && WIFEXITED(status)) ?
                    WEXITSTATUS(status) : -1);
        fflush(stderr);
        gBrokerPid = -1;
    }

    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_INTERPOSER_EXIT:lookups=%u requests=%u callbacks=%u\n",
            gLookupCount,
            gMachRequestCount,
            gCallbackSendCount);
    fflush(stderr);
}

static void *
mach_server_thread(void *unused)
{
    unsigned char *buffer;

    (void)unused;

    buffer = (unsigned char *)malloc(FRAME_MAX_PAYLOAD + 0x100U);
    if (buffer == NULL)
        return NULL;

    for (;;) {
        mach_msg_header_t *header = (mach_msg_header_t *)buffer;
        mach_msg_return_t mr;
        uint32_t message_size;
        uint32_t raw_length;
        uint32_t payload_length;
        mach_port_t callback_port;

        memset(buffer, 0, FRAME_MAX_PAYLOAD + 0x100U);

        mr = mach_msg(
            header,
            MACH_RCV_MSG,
            0,
            (mach_msg_size_t)(FRAME_MAX_PAYLOAD + 0x100U),
            gServiceReceivePort,
            MACH_MSG_TIMEOUT_NONE,
            MACH_PORT_NULL);
        if (mr != MACH_MSG_SUCCESS)
            break;

        message_size = (uint32_t)header->msgh_size;
        callback_port = header->msgh_remote_port;

        if (header->msgh_id != LEGACY_MESSAGE_ID ||
            message_size < LEGACY_HEADER_SIZE ||
            message_size > FRAME_MAX_PAYLOAD ||
            callback_port == MACH_PORT_NULL) {
            fprintf(stderr,
                    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REJECT:id=%ld size=%lu callbackPort=0x%08lx\n",
                    (long)header->msgh_id,
                    (unsigned long)message_size,
                    (unsigned long)callback_port);
            fflush(stderr);
            if (callback_port != MACH_PORT_NULL)
                (void)mach_port_deallocate(
                    mach_task_self(), callback_port);
            continue;
        }

        memcpy(&raw_length,
               buffer + LEGACY_LENGTH_OFF,
               sizeof(raw_length));
        payload_length = swap_u32(raw_length);

        if (payload_length == 0 ||
            payload_length > FRAME_MAX_PAYLOAD ||
            payload_length > message_size - LEGACY_PAYLOAD_OFF) {
            fprintf(stderr,
                    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REJECT:length=%lu size=%lu\n",
                    (unsigned long)payload_length,
                    (unsigned long)message_size);
            fflush(stderr);
            (void)mach_port_deallocate(
                mach_task_self(), callback_port);
            continue;
        }

        if (gClientCallbackPort == MACH_PORT_NULL) {
            gClientCallbackPort = callback_port;
        } else if (callback_port == gClientCallbackPort) {
            (void)mach_port_deallocate(
                mach_task_self(), callback_port);
        } else {
            fprintf(stderr,
                    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REJECT:callback_port_changed old=0x%08lx new=0x%08lx\n",
                    (unsigned long)gClientCallbackPort,
                    (unsigned long)callback_port);
            fflush(stderr);
            (void)mach_port_deallocate(
                mach_task_self(), callback_port);
            continue;
        }

        ++gMachRequestCount;
        fprintf(stderr,
                "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:index=%u bits=0x%08lx id=%ld size=%lu payload=%lu callbackPort=0x%08lx\n",
                gMachRequestCount,
                (unsigned long)(uint32_t)header->msgh_bits,
                (long)header->msgh_id,
                (unsigned long)message_size,
                (unsigned long)payload_length,
                (unsigned long)gClientCallbackPort);
        fflush(stderr);

        if (!send_frame(
                FRAME_REQUEST,
                buffer + LEGACY_PAYLOAD_OFF,
                payload_length)) {
            fprintf(stderr,
                    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_IPC_REQUEST:FAIL\n");
            fflush(stderr);
            break;
        }
    }

    free(buffer);
    return NULL;
}

static int
send_legacy_callback(const unsigned char *payload, uint32_t payload_length)
{
    unsigned char *message;
    uint32_t aligned_length;
    uint32_t message_size;
    uint32_t raw_length;
    mach_msg_header_t *header;
    mach_msg_return_t mr;

    if (payload == NULL ||
        payload_length == 0 ||
        payload_length > FRAME_MAX_PAYLOAD ||
        gClientCallbackPort == MACH_PORT_NULL)
        return 0;

    aligned_length = (payload_length + 3U) & ~3U;
    message_size = LEGACY_HEADER_SIZE + aligned_length;
    message = (unsigned char *)calloc(1, message_size);
    if (message == NULL)
        return 0;

    header = (mach_msg_header_t *)message;
    header->msgh_bits = (mach_msg_bits_t)LEGACY_S2C_BITS;
    header->msgh_size = (mach_msg_size_t)message_size;
    header->msgh_remote_port = gClientCallbackPort;
    header->msgh_local_port = MACH_PORT_NULL;
    header->msgh_reserved = 0;
    header->msgh_id = LEGACY_MESSAGE_ID;

    raw_length = swap_u32(payload_length);
    memcpy(message + LEGACY_LENGTH_OFF,
           &raw_length,
           sizeof(raw_length));
    memcpy(message + LEGACY_PAYLOAD_OFF,
           payload,
           payload_length);

    mr = mach_msg(
        header,
        (mach_msg_option_t)LEGACY_CALLBACK_SEND_OPTIONS,
        (mach_msg_size_t)message_size,
        0,
        MACH_PORT_NULL,
        (mach_msg_timeout_t)LEGACY_CALLBACK_TIMEOUT,
        MACH_PORT_NULL);

    if (mr == MACH_MSG_SUCCESS) {
        ++gCallbackSendCount;
        fprintf(stderr,
                "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_CALLBACK:index=%u bits=0x%08lx id=%ld size=%lu payload=%lu result=PASS\n",
                gCallbackSendCount,
                (unsigned long)(uint32_t)header->msgh_bits,
                (long)header->msgh_id,
                (unsigned long)message_size,
                (unsigned long)payload_length);
    } else {
        fprintf(stderr,
                "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_CALLBACK:result=FAIL kr=%ld hex=0x%08lx\n",
                (long)mr,
                (unsigned long)(uint32_t)mr);
    }
    fflush(stderr);

    free(message);
    return mr == MACH_MSG_SUCCESS;
}

static void *
callback_reader_thread(void *unused)
{
    (void)unused;

    for (;;) {
        FrameHeader header;
        uint32_t magic;
        uint32_t version;
        uint32_t type;
        uint32_t length;
        unsigned char *payload;

        if (!read_full(gIpcFd, &header, sizeof(header)))
            break;

        magic = ntohl(header.magic);
        version = ntohl(header.version);
        type = ntohl(header.type);
        length = ntohl(header.length);

        if (magic != FRAME_MAGIC ||
            version != FRAME_VERSION ||
            type != FRAME_CALLBACK ||
            length == 0 ||
            length > FRAME_MAX_PAYLOAD) {
            fprintf(stderr,
                    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_IPC_CALLBACK:REJECT magic=0x%08lx version=%lu type=%lu length=%lu\n",
                    (unsigned long)magic,
                    (unsigned long)version,
                    (unsigned long)type,
                    (unsigned long)length);
            fflush(stderr);
            break;
        }

        payload = (unsigned char *)malloc(length);
        if (payload == NULL)
            break;
        if (!read_full(gIpcFd, payload, length)) {
            free(payload);
            break;
        }

        if (!send_legacy_callback(payload, length)) {
            free(payload);
            break;
        }

        free(payload);
    }

    return NULL;
}

static int
start_bridge(void)
{
    int sv[2];
    const char *broker_path;
    posix_spawn_file_actions_t actions;
    char fd_text[32];
    char *argv[4];
    char **broker_env = NULL;
    int spawn_status;
    kern_return_t kr;

    if (gBridgeStarted)
        return 1;

    broker_path = getenv(BROKER_ENV);
    if (broker_path == NULL || *broker_path == '\0') {
        fprintf(stderr,
                "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BRIDGE_START:missing_broker_path\n");
        fflush(stderr);
        return 0;
    }

    if (socketpair(AF_UNIX, SOCK_STREAM, 0, sv) != 0) {
        perror("socketpair");
        return 0;
    }

#ifdef SO_NOSIGPIPE
    {
        int one = 1;
        (void)setsockopt(
            sv[0], SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one));
        (void)setsockopt(
            sv[1], SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one));
    }
#endif

    kr = mach_port_allocate(
        mach_task_self(),
        MACH_PORT_RIGHT_RECEIVE,
        &gServiceReceivePort);
    if (kr != KERN_SUCCESS) {
        close(sv[0]);
        close(sv[1]);
        gServiceReceivePort = MACH_PORT_NULL;
        return 0;
    }

    snprintf(fd_text, sizeof(fd_text), "%d", sv[1]);
    argv[0] = (char *)broker_path;
    argv[1] = (char *)"--ipc-fd";
    argv[2] = fd_text;
    argv[3] = NULL;

    broker_env = build_broker_env();
    if (broker_env == NULL) {
        close(sv[0]);
        close(sv[1]);
        mach_port_destroy(mach_task_self(), gServiceReceivePort);
        gServiceReceivePort = MACH_PORT_NULL;
        return 0;
    }

    if (posix_spawn_file_actions_init(&actions) != 0) {
        free(broker_env);
        close(sv[0]);
        close(sv[1]);
        mach_port_destroy(mach_task_self(), gServiceReceivePort);
        gServiceReceivePort = MACH_PORT_NULL;
        return 0;
    }
    (void)posix_spawn_file_actions_addclose(&actions, sv[0]);

    spawn_status = posix_spawn(
        &gBrokerPid,
        broker_path,
        &actions,
        NULL,
        argv,
        broker_env);
    posix_spawn_file_actions_destroy(&actions);
    free(broker_env);

    if (spawn_status != 0) {
        fprintf(stderr,
                "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BRIDGE_START:posix_spawn_failed status=%d\n",
                spawn_status);
        fflush(stderr);
        close(sv[0]);
        close(sv[1]);
        mach_port_destroy(mach_task_self(), gServiceReceivePort);
        gServiceReceivePort = MACH_PORT_NULL;
        gBrokerPid = -1;
        return 0;
    }

    close(sv[1]);
    gIpcFd = sv[0];

    if (pthread_create(&gMachThread, NULL, mach_server_thread, NULL) != 0 ||
        pthread_create(&gCallbackThread, NULL, callback_reader_thread, NULL) != 0) {
        fprintf(stderr,
                "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BRIDGE_START:thread_failed\n");
        fflush(stderr);
        bridge_cleanup();
        return 0;
    }

    (void)pthread_detach(gMachThread);
    (void)pthread_detach(gCallbackThread);

    if (!gCleanupRegistered) {
        atexit(bridge_cleanup);
        gCleanupRegistered = 1;
    }

    gBridgeStarted = 1;
    fprintf(stderr,
            "%s\n"
            "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BRIDGE_READY:serviceReceivePort=0x%08lx brokerPid=%ld ipcFd=%d\n",
            BUILD_MARKER,
            (unsigned long)gServiceReceivePort,
            (long)gBrokerPid,
            gIpcFd);
    fflush(stderr);
    return 1;
}

static kern_return_t
rosetta_distnotify_bootstrap_look_up2(mach_port_t bp,
                                      const char *service_name,
                                      mach_port_t *service_port,
                                      pid_t target_pid,
                                      uint64_t flags)
{
    const char *mode;
    int exact;
    kern_return_t kr;

    exact = service_name != NULL &&
            strcmp(service_name, SERVICE_NAME) == 0 &&
            target_pid == (pid_t)0 &&
            flags == LOOKUP_FLAGS;

    if (!exact)
        return call_original_lookup(
            bp, service_name, service_port, target_pid, flags);

    ++gLookupCount;
    mode = getenv(MODE_ENV);

    fprintf(stderr,
            "%s\n"
            "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_LOOKUP:index=%u mode=%s name=%s pid=%ld flags=0x%08lx%08lx\n",
            BUILD_MARKER,
            gLookupCount,
            mode ? mode : "(unset)",
            service_name,
            (long)target_pid,
            (unsigned long)(uint32_t)(flags >> 32),
            (unsigned long)(uint32_t)flags);
    fflush(stderr);

    if (mode != NULL && strcmp(mode, MODE_PASSTHROUGH) == 0) {
        kr = call_original_lookup(
            bp, service_name, service_port, target_pid, flags);
        fprintf(stderr,
                "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_LOOKUP_RESULT:PASSTHROUGH kr=%ld hex=0x%08lx servicePort=0x%08lx\n",
                (long)kr,
                (unsigned long)(uint32_t)kr,
                (unsigned long)(service_port != NULL ?
                    *service_port : MACH_PORT_NULL));
        fflush(stderr);
        return kr;
    }

    if (mode == NULL || strcmp(mode, MODE_LION) != 0) {
        if (service_port != NULL)
            *service_port = MACH_PORT_NULL;
        fprintf(stderr,
                "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_LOOKUP_RESULT:MODE_REJECTED\n");
        fflush(stderr);
        return KERN_INVALID_ARGUMENT;
    }

    if (service_port == NULL || !start_bridge()) {
        if (service_port != NULL)
            *service_port = MACH_PORT_NULL;
        fprintf(stderr,
                "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_LOOKUP_RESULT:BRIDGE_START_FAILED\n");
        fflush(stderr);
        return KERN_FAILURE;
    }

    kr = mach_port_insert_right(
        mach_task_self(),
        gServiceReceivePort,
        gServiceReceivePort,
        MACH_MSG_TYPE_MAKE_SEND);
    if (kr != KERN_SUCCESS) {
        *service_port = MACH_PORT_NULL;
        fprintf(stderr,
                "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_LOOKUP_RESULT:MAKE_SEND_FAILED kr=%ld\n",
                (long)kr);
        fflush(stderr);
        return kr;
    }

    *service_port = gServiceReceivePort;
    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_LOOKUP_RESULT:LOCAL_SERVICE_PASS servicePort=0x%08lx\n",
            (unsigned long)*service_port);
    fflush(stderr);
    return KERN_SUCCESS;
}
