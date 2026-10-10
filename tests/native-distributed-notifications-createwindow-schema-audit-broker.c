#include <CoreFoundation/CoreFoundation.h>
#include <arpa/inet.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

#define BUILD_ID "distributed-notifications-createwindow-schema-audit-broker-v1"
#define BUILD_MARKER \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_BUILD_ID:" BUILD_ID
#define AUDIT_REPORT_ENV \
    "ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT"

#define FRAME_MAGIC 0x44504e31U
#define FRAME_VERSION 1U
#define FRAME_REQUEST 1U
#define FRAME_MAX_PAYLOAD (256U * 1024U)

typedef struct FrameHeader {
    uint32_t magic;
    uint32_t version;
    uint32_t type;
    uint32_t length;
} FrameHeader;

static int gIpcFd = -1;
static FILE *gAudit = NULL;
static unsigned int gRequestCount = 0;
static unsigned int gFailureCount = 0;

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
parse_fd(const char *text)
{
    char *end = NULL;
    long value;

    if (text == NULL || *text == '\0')
        return -1;

    errno = 0;
    value = strtol(text, &end, 10);
    if (errno != 0 || end == text || *end != '\0' ||
        value < 0 || value > 65535)
        return -1;

    return (int)value;
}

static void
write_hex(FILE *stream, const unsigned char *bytes, uint32_t length)
{
    uint32_t i;

    fputs("binary_hex=", stream);
    for (i = 0; i < length; ++i)
        fprintf(stream, "%02x", (unsigned int)bytes[i]);
    fputc('\n', stream);
}

static int
capture_request(const unsigned char *bytes, uint32_t length)
{
    CFDataRef binary = NULL;
    CFPropertyListRef plist = NULL;
    CFPropertyListFormat format = kCFPropertyListBinaryFormat_v1_0;
    CFErrorRef error = NULL;
    CFDataRef xml = NULL;
    unsigned int index = gRequestCount + 1U;
    int ok = 0;

    binary = CFDataCreate(kCFAllocatorDefault, bytes, (CFIndex)length);
    if (binary == NULL)
        goto done;

    plist = CFPropertyListCreateWithData(
        kCFAllocatorDefault,
        binary,
        kCFPropertyListImmutable,
        &format,
        &error);
    if (error != NULL) {
        CFRelease(error);
        error = NULL;
    }
    if (plist == NULL || CFGetTypeID(plist) != CFDictionaryGetTypeID())
        goto done;

    xml = CFPropertyListCreateData(
        kCFAllocatorDefault,
        plist,
        kCFPropertyListXMLFormat_v1_0,
        0,
        &error);
    if (error != NULL) {
        CFRelease(error);
        error = NULL;
    }
    if (xml == NULL || CFDataGetLength(xml) <= 0)
        goto done;

    fprintf(gAudit,
            "=== REQUEST %u BEGIN ===\n"
            "binary_length=%u\n"
            "xml_length=%ld\n",
            index,
            length,
            (long)CFDataGetLength(xml));
    write_hex(gAudit, bytes, length);
    fwrite(CFDataGetBytePtr(xml),
           1,
           (size_t)CFDataGetLength(xml),
           gAudit);
    if (CFDataGetBytePtr(xml)[CFDataGetLength(xml) - 1] != '\n')
        fputc('\n', gAudit);
    fprintf(gAudit, "=== REQUEST %u END ===\n", index);
    fflush(gAudit);

    ++gRequestCount;
    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_REAL_SCHEMA_AUDIT_CAPTURE:index=%u binaryLength=%u xmlLength=%ld\n",
            gRequestCount,
            length,
            (long)CFDataGetLength(xml));
    fflush(stderr);
    ok = 1;

done:
    if (!ok) {
        ++gFailureCount;
        fprintf(stderr,
                "PM_DISTRIBUTED_NOTIFICATIONS_REAL_SCHEMA_AUDIT_CAPTURE:FAIL index=%u binaryLength=%u\n",
                index,
                length);
        fflush(stderr);
    }

    if (xml != NULL)
        CFRelease(xml);
    if (plist != NULL)
        CFRelease(plist);
    if (binary != NULL)
        CFRelease(binary);
    if (error != NULL)
        CFRelease(error);

    return ok;
}

static int
read_one_frame(int fd)
{
    FrameHeader header;
    uint32_t magic;
    uint32_t version;
    uint32_t type;
    uint32_t length;
    unsigned char *payload;

    if (!read_full(fd, &header, sizeof(header)))
        return 0;

    magic = ntohl(header.magic);
    version = ntohl(header.version);
    type = ntohl(header.type);
    length = ntohl(header.length);

    if (magic != FRAME_MAGIC ||
        version != FRAME_VERSION ||
        type != FRAME_REQUEST ||
        length == 0 ||
        length > FRAME_MAX_PAYLOAD) {
        ++gFailureCount;
        fprintf(stderr,
                "PM_DISTRIBUTED_NOTIFICATIONS_REAL_SCHEMA_AUDIT_FRAME_REJECT:magic=0x%08x version=%u type=%u length=%u\n",
                magic,
                version,
                type,
                length);
        fflush(stderr);
        return -1;
    }

    payload = (unsigned char *)malloc(length);
    if (payload == NULL) {
        ++gFailureCount;
        return -1;
    }

    if (!read_full(fd, payload, length)) {
        free(payload);
        ++gFailureCount;
        return -1;
    }

    (void)capture_request(payload, length);

    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_REQUEST:length=%u status=0 audit=YES\n",
            length);
    fflush(stderr);

    free(payload);
    return 1;
}

int
main(int argc, char **argv)
{
    const char *audit_path;
    int running = 1;

    fprintf(stderr, "%s\n", BUILD_MARKER);
    fflush(stderr);

    if (argc != 3 || strcmp(argv[1], "--ipc-fd") != 0) {
        fprintf(stderr, "usage: %s --ipc-fd FD\n", argv[0]);
        return 64;
    }

    gIpcFd = parse_fd(argv[2]);
    if (gIpcFd < 0) {
        fprintf(stderr,
                "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:BAD_FD\n");
        return 65;
    }

    audit_path = getenv(AUDIT_REPORT_ENV);
    if (audit_path == NULL || *audit_path == '\0') {
        fprintf(stderr,
                "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:MISSING_AUDIT_REPORT\n");
        return 66;
    }

    gAudit = fopen(audit_path, "w");
    if (gAudit == NULL) {
        fprintf(stderr,
                "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:AUDIT_REPORT_OPEN_FAILED errno=%d\n",
                errno);
        return 73;
    }

    fprintf(gAudit,
            "build_id=%s\n"
            "pid=%ld\n",
            BUILD_ID,
            (long)getpid());
    fflush(gAudit);

    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_READY:fd=%d pid=%ld audit=YES\n",
            gIpcFd,
            (long)getpid());
    fflush(stderr);

    while (running) {
        int rc = read_one_frame(gIpcFd);
        if (rc <= 0)
            running = 0;
    }

    fprintf(gAudit,
            "summary_requests=%u\n"
            "summary_failures=%u\n",
            gRequestCount,
            gFailureCount);
    fflush(gAudit);
    fclose(gAudit);
    gAudit = NULL;

    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_REAL_SCHEMA_AUDIT_SUMMARY:requests=%u failures=%u\n",
            gRequestCount,
            gFailureCount);
    fflush(stderr);

    close(gIpcFd);

    if (gRequestCount > 0 && gFailureCount == 0) {
        fprintf(stderr,
                "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:AUDIT_PASS\n");
        fflush(stderr);
        return 0;
    }

    fprintf(stderr,
            "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:AUDIT_FAIL\n");
    fflush(stderr);
    return 1;
}
