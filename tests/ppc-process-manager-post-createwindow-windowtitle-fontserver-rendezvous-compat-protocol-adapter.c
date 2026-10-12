#include <mach/ndr.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BUILD_ID "windowtitle-fontserver-rendezvous-compat-protocol-v1"
#define BUILD_MARKER "PM_FONTSERVER_RENDEZVOUS_COMPAT_BUILD_ID:" BUILD_ID

#define LEGACY_REQUEST_ID 0x000032c8U
#define LEGACY_REPLY_ID 0x0000332cU
#define LION_REQUEST_ID 0x000032e7U
#define LION_REPLY_ID 0x0000334bU

#define REQUEST_BITS 0x00001513U
#define LEGACY_SEND_SIZE 0x00000018U
#define LEGACY_RECV_SIZE 0x0000003cU
#define LION_SEND_SIZE 0x00000018U
#define LION_RECV_SIZE 0x00000040U

#define LEGACY_SUCCESS_SIZE 0x00000034U
#define LION_SUCCESS_SIZE 0x00000038U
#define SIMPLE_ERROR_SIZE 0x00000024U
#define COMPLEX_REPLY_BITS 0x80001200U
#define SIMPLE_REPLY_BITS 0x00001200U

#define HEADER_SIZE_OFF 0x04U
#define HEADER_ID_OFF 0x14U
#define DESC_COUNT_OFF 0x18U
#define DESC_ADDR_OFF 0x1cU
#define DESC_SIZE_OFF 0x20U
#define DESC_FLAGS_OFF 0x24U
#define COMPLEX_NDR_OFF 0x28U
#define LEGACY_EXPLICIT_SIZE_OFF 0x30U
#define LION_PROTOCOL_VERSION_OFF 0x30U
#define LION_EXPLICIT_SIZE_OFF 0x34U
#define SIMPLE_NDR_OFF 0x18U
#define SIMPLE_RESULT_OFF 0x20U

#define EXPECTED_PROTOCOL_VERSION 5U
#define CAPTURED_PAYLOAD_SIZE 0x00001000U
#define SNOW_CAPTURED_OOL_ADDRESS 0x00654000U
#define LION_CAPTURED_OOL_ADDRESS 0x000b7000U
#define CAPTURED_DESCRIPTOR_FLAGS 0x01010001U
#define MODELED_ERROR_RAW 0xd0feffffU
#define BUFFER_SIZE 0x00000040U

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

static uint32_t
swap_u32(uint32_t value)
{
    return ((value & 0x000000ffU) << 24) |
           ((value & 0x0000ff00U) << 8) |
           ((value & 0x00ff0000U) >> 8) |
           ((value & 0xff000000U) >> 24);
}

static int
ndr_is_swapped_at(const unsigned char *message, uint32_t off)
{
    const unsigned char *local_ndr = (const unsigned char *)&NDR_record;
    return message[off + 4U] != local_ndr[4];
}

static void
set_swapped_ndr_at(unsigned char *message, uint32_t off)
{
    const unsigned char *local_ndr = (const unsigned char *)&NDR_record;
    memcpy(message + off, local_ndr, sizeof(NDR_record));
    message[off + 4U] =
        (unsigned char)(message[off + 4U] == 0U ? 1U : 0U);
}

static uint32_t
encode_swapped_u32(uint32_t value)
{
    return swap_u32(value);
}

static uint32_t
decode_ndr_u32_at(const unsigned char *message,
                  uint32_t ndr_off,
                  uint32_t value_off)
{
    uint32_t value = get_u32(message + value_off);
    if (ndr_is_swapped_at(message, ndr_off))
        value = swap_u32(value);
    return value;
}

static int32_t
decode_ndr_i32_at(const unsigned char *message,
                  uint32_t ndr_off,
                  uint32_t value_off)
{
    return (int32_t)decode_ndr_u32_at(message, ndr_off, value_off);
}

static unsigned int
count_changes(const unsigned char *a,
              const unsigned char *b,
              uint32_t size)
{
    uint32_t i;
    unsigned int changed = 0U;

    for (i = 0U; i < size; ++i) {
        if (a[i] != b[i])
            ++changed;
    }
    return changed;
}

static unsigned int
count_request_body_changes(const unsigned char *a,
                           const unsigned char *b)
{
    uint32_t i;
    unsigned int changed = 0U;

    for (i = 0U; i < LEGACY_SEND_SIZE; ++i) {
        if (i >= HEADER_ID_OFF && i < HEADER_ID_OFF + 4U)
            continue;
        if (a[i] != b[i])
            ++changed;
    }
    return changed;
}

static unsigned int
count_preserved_success_prefix_changes(const unsigned char *native_reply,
                                       const unsigned char *legacy_reply)
{
    uint32_t i;
    unsigned int changed = 0U;

    for (i = 0U; i < LION_PROTOCOL_VERSION_OFF; ++i) {
        if (i >= HEADER_SIZE_OFF && i < HEADER_SIZE_OFF + 4U)
            continue;
        if (i >= HEADER_ID_OFF && i < HEADER_ID_OFF + 4U)
            continue;
        if (native_reply[i] != legacy_reply[i])
            ++changed;
    }
    return changed;
}

static unsigned int
count_simple_body_changes(const unsigned char *a,
                          const unsigned char *b)
{
    uint32_t i;
    unsigned int changed = 0U;

    for (i = 0U; i < SIMPLE_ERROR_SIZE; ++i) {
        if (i >= HEADER_ID_OFF && i < HEADER_ID_OFF + 4U)
            continue;
        if (a[i] != b[i])
            ++changed;
    }
    return changed;
}

static void
build_legacy_request(unsigned char *request)
{
    memset(request, 0, BUFFER_SIZE);
    put_u32(request + 0x00U, REQUEST_BITS);
    put_u32(request + HEADER_SIZE_OFF, 0xa1a2a3a4U);
    put_u32(request + 0x08U, 0x11111111U);
    put_u32(request + 0x0cU, 0x22222222U);
    put_u32(request + 0x10U, 0xb1b2b3b4U);
    put_u32(request + HEADER_ID_OFF, LEGACY_REQUEST_ID);
}

static void
build_complex_reply(unsigned char *reply,
                    uint32_t reply_id,
                    uint32_t reply_size,
                    uint32_t ool_address,
                    int include_protocol_version)
{
    memset(reply, 0, BUFFER_SIZE);
    put_u32(reply + 0x00U, COMPLEX_REPLY_BITS);
    put_u32(reply + HEADER_SIZE_OFF, reply_size);
    put_u32(reply + 0x0cU, 0x22222222U);
    put_u32(reply + HEADER_ID_OFF, reply_id);
    put_u32(reply + DESC_COUNT_OFF, 1U);
    put_u32(reply + DESC_ADDR_OFF, ool_address);
    put_u32(reply + DESC_SIZE_OFF, CAPTURED_PAYLOAD_SIZE);
    put_u32(reply + DESC_FLAGS_OFF, CAPTURED_DESCRIPTOR_FLAGS);
    set_swapped_ndr_at(reply, COMPLEX_NDR_OFF);

    if (include_protocol_version) {
        put_u32(reply + LION_PROTOCOL_VERSION_OFF,
                encode_swapped_u32(EXPECTED_PROTOCOL_VERSION));
        put_u32(reply + LION_EXPLICIT_SIZE_OFF,
                encode_swapped_u32(CAPTURED_PAYLOAD_SIZE));
    } else {
        put_u32(reply + LEGACY_EXPLICIT_SIZE_OFF,
                encode_swapped_u32(CAPTURED_PAYLOAD_SIZE));
    }
}

static void
build_simple_error_reply(unsigned char *reply,
                         uint32_t reply_id,
                         uint32_t raw_result)
{
    memset(reply, 0, BUFFER_SIZE);
    put_u32(reply + 0x00U, SIMPLE_REPLY_BITS);
    put_u32(reply + HEADER_SIZE_OFF, SIMPLE_ERROR_SIZE);
    put_u32(reply + 0x0cU, 0x22222222U);
    put_u32(reply + HEADER_ID_OFF, reply_id);
    set_swapped_ndr_at(reply, SIMPLE_NDR_OFF);
    put_u32(reply + SIMPLE_RESULT_OFF, raw_result);
}

static int
transform_request_copy(const unsigned char *legacy_request,
                       unsigned char *lion_request,
                       unsigned int *changed_bytes,
                       unsigned int *body_changed_bytes,
                       unsigned int *source_changed_bytes)
{
    unsigned char before[BUFFER_SIZE];

    if (get_u32(legacy_request + 0x00U) != REQUEST_BITS ||
        get_u32(legacy_request + HEADER_ID_OFF) != LEGACY_REQUEST_ID)
        return 0;

    memcpy(before, legacy_request, BUFFER_SIZE);
    memcpy(lion_request, legacy_request, BUFFER_SIZE);
    put_u32(lion_request + HEADER_ID_OFF, LION_REQUEST_ID);

    *changed_bytes =
        count_changes(legacy_request, lion_request, LEGACY_SEND_SIZE);
    *body_changed_bytes =
        count_request_body_changes(legacy_request, lion_request);
    *source_changed_bytes =
        count_changes(legacy_request, before, LEGACY_SEND_SIZE);
    return 1;
}

static int
transform_success_reply_copy(const unsigned char *native_reply,
                             unsigned char *legacy_reply,
                             unsigned int *preserved_prefix_changed_bytes,
                             unsigned int *source_changed_bytes)
{
    unsigned char before[BUFFER_SIZE];
    uint32_t protocol_version;
    uint32_t explicit_size;

    if (get_u32(native_reply + 0x00U) != COMPLEX_REPLY_BITS ||
        get_u32(native_reply + HEADER_SIZE_OFF) != LION_SUCCESS_SIZE ||
        get_u32(native_reply + HEADER_ID_OFF) != LION_REPLY_ID ||
        get_u32(native_reply + DESC_COUNT_OFF) != 1U)
        return 0;

    protocol_version =
        decode_ndr_u32_at(native_reply,
                          COMPLEX_NDR_OFF,
                          LION_PROTOCOL_VERSION_OFF);
    explicit_size =
        decode_ndr_u32_at(native_reply,
                          COMPLEX_NDR_OFF,
                          LION_EXPLICIT_SIZE_OFF);

    if (protocol_version != EXPECTED_PROTOCOL_VERSION ||
        get_u32(native_reply + DESC_ADDR_OFF) == 0U ||
        explicit_size == 0U)
        return 0;

    memcpy(before, native_reply, BUFFER_SIZE);
    memset(legacy_reply, 0, BUFFER_SIZE);

    memcpy(legacy_reply, native_reply, LION_PROTOCOL_VERSION_OFF);
    put_u32(legacy_reply + HEADER_SIZE_OFF, LEGACY_SUCCESS_SIZE);
    put_u32(legacy_reply + HEADER_ID_OFF, LEGACY_REPLY_ID);
    memcpy(legacy_reply + LEGACY_EXPLICIT_SIZE_OFF,
           native_reply + LION_EXPLICIT_SIZE_OFF,
           sizeof(uint32_t));

    *preserved_prefix_changed_bytes =
        count_preserved_success_prefix_changes(native_reply, legacy_reply);
    *source_changed_bytes =
        count_changes(native_reply, before, LION_SUCCESS_SIZE);
    return 1;
}

static int
transform_error_reply_copy(const unsigned char *native_reply,
                           unsigned char *legacy_reply,
                           unsigned int *changed_bytes,
                           unsigned int *body_changed_bytes,
                           unsigned int *source_changed_bytes)
{
    unsigned char before[BUFFER_SIZE];

    if (get_u32(native_reply + 0x00U) != SIMPLE_REPLY_BITS ||
        get_u32(native_reply + HEADER_SIZE_OFF) != SIMPLE_ERROR_SIZE ||
        get_u32(native_reply + HEADER_ID_OFF) != LION_REPLY_ID)
        return 0;

    memcpy(before, native_reply, BUFFER_SIZE);
    memcpy(legacy_reply, native_reply, BUFFER_SIZE);
    put_u32(legacy_reply + HEADER_ID_OFF, LEGACY_REPLY_ID);

    *changed_bytes =
        count_changes(native_reply, legacy_reply, SIMPLE_ERROR_SIZE);
    *body_changed_bytes =
        count_simple_body_changes(native_reply, legacy_reply);
    *source_changed_bytes =
        count_changes(native_reply, before, SIMPLE_ERROR_SIZE);
    return 1;
}

static int
run_snow_control(void)
{
    unsigned char request[BUFFER_SIZE];
    unsigned char reply[BUFFER_SIZE];
    uint32_t explicit_size;

    fprintf(stderr, "%s\n", BUILD_MARKER);

    build_legacy_request(request);
    build_complex_reply(reply,
                        LEGACY_REPLY_ID,
                        LEGACY_SUCCESS_SIZE,
                        SNOW_CAPTURED_OOL_ADDRESS,
                        0);

    explicit_size =
        decode_ndr_u32_at(reply,
                          COMPLEX_NDR_OFF,
                          LEGACY_EXPLICIT_SIZE_OFF);

    fprintf(stderr,
            "PM_FONTSERVER_RENDEZVOUS_COMPAT_SNOW_LAYOUT:bits=0x%08lx legacyId=0x%08lx send=0x%08lx recv=0x%08lx replyId=0x%08lx replySize=0x%08lx descriptorCount=%lu descriptorAddress=0x%08lx descriptorSize=0x%08lx explicitSize=0x%08lx ndrSwapped=%s\n",
            (unsigned long)get_u32(request + 0x00U),
            (unsigned long)get_u32(request + HEADER_ID_OFF),
            (unsigned long)LEGACY_SEND_SIZE,
            (unsigned long)LEGACY_RECV_SIZE,
            (unsigned long)get_u32(reply + HEADER_ID_OFF),
            (unsigned long)get_u32(reply + HEADER_SIZE_OFF),
            (unsigned long)get_u32(reply + DESC_COUNT_OFF),
            (unsigned long)get_u32(reply + DESC_ADDR_OFF),
            (unsigned long)get_u32(reply + DESC_SIZE_OFF),
            (unsigned long)explicit_size,
            ndr_is_swapped_at(reply, COMPLEX_NDR_OFF) ? "YES" : "NO");

    if (get_u32(request + HEADER_ID_OFF) != LEGACY_REQUEST_ID ||
        get_u32(reply + HEADER_ID_OFF) != LEGACY_REPLY_ID ||
        get_u32(reply + HEADER_SIZE_OFF) != LEGACY_SUCCESS_SIZE ||
        get_u32(reply + DESC_COUNT_OFF) != 1U ||
        get_u32(reply + DESC_ADDR_OFF) != SNOW_CAPTURED_OOL_ADDRESS ||
        get_u32(reply + DESC_SIZE_OFF) != CAPTURED_PAYLOAD_SIZE ||
        explicit_size != CAPTURED_PAYLOAD_SIZE ||
        !ndr_is_swapped_at(reply, COMPLEX_NDR_OFF))
        return 0;

    fprintf(stderr,
            "PM_FONTSERVER_RENDEZVOUS_COMPAT_RESULT:SNOW_CONTROL_PASS\n");
    return 1;
}

static int
run_lion_policy_proof(void)
{
    unsigned char legacy_request[BUFFER_SIZE];
    unsigned char lion_request[BUFFER_SIZE];
    unsigned char native_success[BUFFER_SIZE];
    unsigned char legacy_success[BUFFER_SIZE];
    unsigned char native_error[BUFFER_SIZE];
    unsigned char legacy_error[BUFFER_SIZE];
    unsigned int request_changed = 0U;
    unsigned int request_body_changed = 0U;
    unsigned int request_source_changed = 0U;
    unsigned int success_prefix_changed = 0U;
    unsigned int success_source_changed = 0U;
    unsigned int error_changed = 0U;
    unsigned int error_body_changed = 0U;
    unsigned int error_source_changed = 0U;
    uint32_t native_protocol_version;
    uint32_t native_explicit_size;
    uint32_t legacy_explicit_size;
    int32_t decoded_error;
    int descriptor_preserved;
    int ndr_preserved;
    int explicit_size_relocated;

    fprintf(stderr, "%s\n", BUILD_MARKER);

    build_legacy_request(legacy_request);

    if (!transform_request_copy(legacy_request,
                                lion_request,
                                &request_changed,
                                &request_body_changed,
                                &request_source_changed))
        return 0;

    fprintf(stderr,
            "PM_FONTSERVER_RENDEZVOUS_COMPAT_REQUEST_POLICY:legacyId=0x%08lx lionId=0x%08lx send=0x%08lx legacyRecv=0x%08lx lionRecv=0x%08lx changedBytes=%u bodyChangedBytes=%u sourceChangedBytes=%u\n",
            (unsigned long)get_u32(legacy_request + HEADER_ID_OFF),
            (unsigned long)get_u32(lion_request + HEADER_ID_OFF),
            (unsigned long)LION_SEND_SIZE,
            (unsigned long)LEGACY_RECV_SIZE,
            (unsigned long)LION_RECV_SIZE,
            request_changed,
            request_body_changed,
            request_source_changed);

    if (request_changed != 1U ||
        request_body_changed != 0U ||
        request_source_changed != 0U ||
        get_u32(lion_request + HEADER_ID_OFF) != LION_REQUEST_ID ||
        LION_SEND_SIZE != LEGACY_SEND_SIZE ||
        LION_RECV_SIZE != 0x40U)
        return 0;

    build_complex_reply(native_success,
                        LION_REPLY_ID,
                        LION_SUCCESS_SIZE,
                        LION_CAPTURED_OOL_ADDRESS,
                        1);

    if (!transform_success_reply_copy(native_success,
                                      legacy_success,
                                      &success_prefix_changed,
                                      &success_source_changed))
        return 0;

    native_protocol_version =
        decode_ndr_u32_at(native_success,
                          COMPLEX_NDR_OFF,
                          LION_PROTOCOL_VERSION_OFF);
    native_explicit_size =
        decode_ndr_u32_at(native_success,
                          COMPLEX_NDR_OFF,
                          LION_EXPLICIT_SIZE_OFF);
    legacy_explicit_size =
        decode_ndr_u32_at(legacy_success,
                          COMPLEX_NDR_OFF,
                          LEGACY_EXPLICIT_SIZE_OFF);

    descriptor_preserved =
        get_u32(native_success + DESC_COUNT_OFF) ==
            get_u32(legacy_success + DESC_COUNT_OFF) &&
        get_u32(native_success + DESC_ADDR_OFF) ==
            get_u32(legacy_success + DESC_ADDR_OFF) &&
        get_u32(native_success + DESC_SIZE_OFF) ==
            get_u32(legacy_success + DESC_SIZE_OFF) &&
        get_u32(native_success + DESC_FLAGS_OFF) ==
            get_u32(legacy_success + DESC_FLAGS_OFF);

    ndr_preserved =
        memcmp(native_success + COMPLEX_NDR_OFF,
               legacy_success + COMPLEX_NDR_OFF,
               sizeof(NDR_record)) == 0;

    explicit_size_relocated =
        memcmp(native_success + LION_EXPLICIT_SIZE_OFF,
               legacy_success + LEGACY_EXPLICIT_SIZE_OFF,
               sizeof(uint32_t)) == 0;

    fprintf(stderr,
            "PM_FONTSERVER_RENDEZVOUS_COMPAT_SUCCESS_REPLY_POLICY:lionId=0x%08lx legacyId=0x%08lx nativeSize=0x%08lx legacySize=0x%08lx protocolVersion=%lu descriptorCount=%lu descriptorAddress=0x%08lx descriptorSize=0x%08lx nativeExplicitSize=0x%08lx legacyExplicitSize=0x%08lx preservedPrefixChangedBytes=%u sourceChangedBytes=%u descriptorPreserved=%s ndrPreserved=%s explicitSizeRelocated=%s removedProtocolBytes=4\n",
            (unsigned long)get_u32(native_success + HEADER_ID_OFF),
            (unsigned long)get_u32(legacy_success + HEADER_ID_OFF),
            (unsigned long)get_u32(native_success + HEADER_SIZE_OFF),
            (unsigned long)get_u32(legacy_success + HEADER_SIZE_OFF),
            (unsigned long)native_protocol_version,
            (unsigned long)get_u32(legacy_success + DESC_COUNT_OFF),
            (unsigned long)get_u32(legacy_success + DESC_ADDR_OFF),
            (unsigned long)get_u32(legacy_success + DESC_SIZE_OFF),
            (unsigned long)native_explicit_size,
            (unsigned long)legacy_explicit_size,
            success_prefix_changed,
            success_source_changed,
            descriptor_preserved ? "YES" : "NO",
            ndr_preserved ? "YES" : "NO",
            explicit_size_relocated ? "YES" : "NO");

    if (get_u32(legacy_success + HEADER_ID_OFF) != LEGACY_REPLY_ID ||
        get_u32(legacy_success + HEADER_SIZE_OFF) != LEGACY_SUCCESS_SIZE ||
        native_protocol_version != EXPECTED_PROTOCOL_VERSION ||
        native_explicit_size != CAPTURED_PAYLOAD_SIZE ||
        legacy_explicit_size != CAPTURED_PAYLOAD_SIZE ||
        success_prefix_changed != 0U ||
        success_source_changed != 0U ||
        !descriptor_preserved ||
        !ndr_preserved ||
        !explicit_size_relocated)
        return 0;

    build_simple_error_reply(native_error,
                             LION_REPLY_ID,
                             MODELED_ERROR_RAW);

    if (!transform_error_reply_copy(native_error,
                                    legacy_error,
                                    &error_changed,
                                    &error_body_changed,
                                    &error_source_changed))
        return 0;

    decoded_error =
        decode_ndr_i32_at(legacy_error,
                          SIMPLE_NDR_OFF,
                          SIMPLE_RESULT_OFF);

    fprintf(stderr,
            "PM_FONTSERVER_RENDEZVOUS_COMPAT_ERROR_REPLY_POLICY:lionId=0x%08lx legacyId=0x%08lx size=0x%08lx changedBytes=%u bodyChangedBytes=%u sourceChangedBytes=%u rawResult=0x%08lx decodedResult=%ld ndrSwapped=%s\n",
            (unsigned long)get_u32(native_error + HEADER_ID_OFF),
            (unsigned long)get_u32(legacy_error + HEADER_ID_OFF),
            (unsigned long)get_u32(legacy_error + HEADER_SIZE_OFF),
            error_changed,
            error_body_changed,
            error_source_changed,
            (unsigned long)get_u32(legacy_error + SIMPLE_RESULT_OFF),
            (long)decoded_error,
            ndr_is_swapped_at(legacy_error, SIMPLE_NDR_OFF) ? "YES" : "NO");

    if (error_changed != 1U ||
        error_body_changed != 0U ||
        error_source_changed != 0U ||
        get_u32(legacy_error + HEADER_ID_OFF) != LEGACY_REPLY_ID ||
        get_u32(legacy_error + SIMPLE_RESULT_OFF) != MODELED_ERROR_RAW ||
        decoded_error != -304 ||
        !ndr_is_swapped_at(legacy_error, SIMPLE_NDR_OFF))
        return 0;

    fprintf(stderr,
            "PM_FONTSERVER_RENDEZVOUS_COMPAT_RESULT:LION_POLICY_PROOF_PASS\n");
    return 1;
}

int
main(int argc, char **argv)
{
    int ok = 0;

    if (argc != 2) {
        fprintf(stderr,
                "usage: %s snow-control|lion-policy-proof\n",
                argv[0]);
        return 64;
    }

    if (strcmp(argv[1], "snow-control") == 0)
        ok = run_snow_control();
    else if (strcmp(argv[1], "lion-policy-proof") == 0)
        ok = run_lion_policy_proof();
    else {
        fprintf(stderr, "unknown mode: %s\n", argv[1]);
        return 64;
    }

    if (!ok) {
        fprintf(stderr,
                "PM_FONTSERVER_RENDEZVOUS_COMPAT_RESULT:FAIL\n");
        return 1;
    }

    return 0;
}
