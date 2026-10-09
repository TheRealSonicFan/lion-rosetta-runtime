#include <mach/ndr.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BUILD_ID "cps-registration-compat-protocol-v1"
#define BUILD_MARKER "PM_CPS_REGISTRATION_COMPAT_BUILD_ID:" BUILD_ID

#define LEGACY_REQUEST_ID 0x00007372U
#define LEGACY_REPLY_ID 0x000073d6U
#define LION_REQUEST_ID 0x000073c1U
#define LION_REPLY_ID 0x00007425U

#define REQUEST_BITS 0x00001513U
#define MSG_OPTIONS 0x00000003U
#define RECV_SIZE 0x0000002cU
#define SUCCESS_REPLY_SIZE 0x00000024U

#define HEADER_ID_OFF 0x14U
#define REQUEST_NDR_OFF 0x18U
#define REQUEST_ARG0_OFF 0x20U
#define REQUEST_ARG1_OFF 0x24U
#define REQUEST_ARG2_OFF 0x28U
#define REQUEST_ARG3_OFF 0x2cU
#define REQUEST_ARG4_OFF 0x30U
#define REQUEST_ARG5_OFF 0x34U
#define REQUEST_PADDING_OFF 0x38U
#define REQUEST_STRING_LENGTH_OFF 0x3cU
#define REQUEST_STRING_OFF 0x40U

#define LEGACY_FIXED_SIZE 0x40U
#define LION_FIXED_SIZE 0x4cU
#define LION_TAIL_SIZE 0x0cU

#define LION_TAIL_BYTE_REL 0x00U
#define LION_TAIL_U32_0_REL 0x04U
#define LION_TAIL_U32_1_REL 0x08U

#define LION_TAIL_BYTE_VALUE 0x00U
#define LION_TAIL_U32_0_VALUE 0x00000000U
#define LION_TAIL_U32_1_VALUE 0x00000010U

#define REPLY_NDR_OFF 0x18U
#define REPLY_RESULT_OFF 0x20U

#define MAX_REQUEST_SIZE 0x00000100U

static const char *kObservedRegistrationName =
    "ppc-process-manager-cgs-session-bootstrap-integration-private-dyld";

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

static uint32_t
align4(uint32_t value)
{
    return (value + 3U) & ~3U;
}

static uint32_t
legacy_send_size_for_name(const char *name)
{
    uint32_t string_length;

    if (name == NULL)
        return 0U;
    string_length = (uint32_t)strlen(name) + 1U;
    return LEGACY_FIXED_SIZE + align4(string_length);
}

static int
ndr_is_swapped(const unsigned char *message, uint32_t ndr_off)
{
    const unsigned char *local_ndr = (const unsigned char *)&NDR_record;
    return message[ndr_off + 4U] != local_ndr[4];
}

static int32_t
decode_ndr_i32(const unsigned char *message,
               uint32_t ndr_off,
               uint32_t value_off)
{
    uint32_t value = get_u32(message + value_off);

    if (ndr_is_swapped(message, ndr_off))
        value = swap_u32(value);
    return (int32_t)value;
}

static void
encode_ndr_i32(unsigned char *message,
               uint32_t ndr_off,
               uint32_t value_off,
               int32_t value)
{
    uint32_t encoded = (uint32_t)value;

    if (ndr_is_swapped(message, ndr_off))
        encoded = swap_u32(encoded);
    put_u32(message + value_off, encoded);
}

static int
build_representative_legacy_request(unsigned char *buffer,
                                    uint32_t *send_size_out)
{
    uint32_t send_size;
    uint32_t string_length;

    if (buffer == NULL || send_size_out == NULL)
        return 0;

    send_size = legacy_send_size_for_name(kObservedRegistrationName);
    string_length = (uint32_t)strlen(kObservedRegistrationName) + 1U;
    if (send_size != 0x84U || send_size > MAX_REQUEST_SIZE)
        return 0;

    memset(buffer, 0, MAX_REQUEST_SIZE);
    put_u32(buffer + 0x00U, REQUEST_BITS);
    put_u32(buffer + 0x04U, 0xa5a5a5a5U);
    put_u32(buffer + 0x08U, 0x11111111U);
    put_u32(buffer + 0x0cU, 0x22222222U);
    put_u32(buffer + 0x10U, 0U);
    put_u32(buffer + HEADER_ID_OFF, LEGACY_REQUEST_ID);
    memcpy(buffer + REQUEST_NDR_OFF, &NDR_record, sizeof(NDR_record));

    put_u32(buffer + REQUEST_ARG0_OFF, 0x00000000U);
    put_u32(buffer + REQUEST_ARG1_OFF, 0x12345678U);
    put_u32(buffer + REQUEST_ARG2_OFF, 0x23456789U);
    put_u32(buffer + REQUEST_ARG3_OFF, 0x3456789aU);
    put_u32(buffer + REQUEST_ARG4_OFF, 0x00000002U);
    put_u32(buffer + REQUEST_ARG5_OFF, 0x456789abU);
    put_u32(buffer + REQUEST_PADDING_OFF, 0x5a5aa5a5U);
    put_u32(buffer + REQUEST_STRING_LENGTH_OFF, string_length);
    memcpy(buffer + REQUEST_STRING_OFF,
           kObservedRegistrationName,
           string_length);

    *send_size_out = send_size;
    return 1;
}

static int
transform_legacy_request_copy(const unsigned char *legacy,
                              uint32_t legacy_send_size,
                              unsigned char *lion,
                              uint32_t *lion_send_size_out,
                              unsigned int *changed_common_out)
{
    uint32_t string_length;
    uint32_t aligned_string_length;
    uint32_t expected_legacy_size;
    uint32_t lion_send_size;
    uint32_t tail_off;
    unsigned int changed_common = 0U;
    uint32_t off;

    if (legacy == NULL || lion == NULL ||
        lion_send_size_out == NULL || changed_common_out == NULL)
        return 0;

    if (get_u32(legacy + 0x00U) != REQUEST_BITS ||
        get_u32(legacy + HEADER_ID_OFF) != LEGACY_REQUEST_ID)
        return 0;

    string_length = get_u32(legacy + REQUEST_STRING_LENGTH_OFF);
    if (string_length == 0U || string_length > 0x80U)
        return 0;

    aligned_string_length = align4(string_length);
    expected_legacy_size = LEGACY_FIXED_SIZE + aligned_string_length;
    if (legacy_send_size != expected_legacy_size)
        return 0;

    lion_send_size = LION_FIXED_SIZE + aligned_string_length;
    if (lion_send_size != legacy_send_size + LION_TAIL_SIZE ||
        lion_send_size > MAX_REQUEST_SIZE)
        return 0;

    memset(lion, 0, MAX_REQUEST_SIZE);
    memcpy(lion, legacy, legacy_send_size);
    put_u32(lion + HEADER_ID_OFF, LION_REQUEST_ID);

    tail_off = legacy_send_size;
    lion[tail_off + LION_TAIL_BYTE_REL] =
        (unsigned char)LION_TAIL_BYTE_VALUE;
    lion[tail_off + 1U] = 0U;
    lion[tail_off + 2U] = 0U;
    lion[tail_off + 3U] = 0U;
    put_u32(lion + tail_off + LION_TAIL_U32_0_REL,
            LION_TAIL_U32_0_VALUE);
    put_u32(lion + tail_off + LION_TAIL_U32_1_REL,
            LION_TAIL_U32_1_VALUE);

    for (off = 0U; off < legacy_send_size; ++off) {
        if (lion[off] != legacy[off])
            ++changed_common;
    }

    *lion_send_size_out = lion_send_size;
    *changed_common_out = changed_common;
    return 1;
}

static int
build_swapped_reply(unsigned char *reply,
                    uint32_t reply_id,
                    int32_t result)
{
    const unsigned char swapped_ndr[8] =
        { 0x00U, 0x00U, 0x00U, 0x00U,
          0x01U, 0x00U, 0x00U, 0x00U };

    if (reply == NULL)
        return 0;

    memset(reply, 0, RECV_SIZE);
    put_u32(reply + 0x00U, 0x00001200U);
    put_u32(reply + 0x04U, SUCCESS_REPLY_SIZE);
    put_u32(reply + HEADER_ID_OFF, reply_id);
    memcpy(reply + REPLY_NDR_OFF, swapped_ndr, sizeof(swapped_ndr));
    encode_ndr_i32(reply, REPLY_NDR_OFF, REPLY_RESULT_OFF, result);
    return 1;
}

static int
transform_lion_reply_copy(const unsigned char *lion,
                          unsigned char *legacy,
                          unsigned int *changed_out)
{
    unsigned int changed = 0U;
    uint32_t off;

    if (lion == NULL || legacy == NULL || changed_out == NULL)
        return 0;

    if (get_u32(lion + 0x00U) != 0x00001200U ||
        get_u32(lion + 0x04U) != SUCCESS_REPLY_SIZE ||
        get_u32(lion + HEADER_ID_OFF) != LION_REPLY_ID)
        return 0;

    memcpy(legacy, lion, RECV_SIZE);
    put_u32(legacy + HEADER_ID_OFF, LEGACY_REPLY_ID);

    for (off = 0U; off < SUCCESS_REPLY_SIZE; ++off) {
        if (legacy[off] != lion[off])
            ++changed;
    }

    *changed_out = changed;
    return 1;
}

static int
run_snow_control(void)
{
    unsigned char legacy[MAX_REQUEST_SIZE];
    unsigned char captured_error[RECV_SIZE];
    uint32_t legacy_send_size;
    int32_t decoded_error;

    fprintf(stderr, "%s\n", BUILD_MARKER);

    if (!build_representative_legacy_request(legacy, &legacy_send_size))
        return 0;

    if (legacy_send_size != 0x84U ||
        get_u32(legacy + HEADER_ID_OFF) != LEGACY_REQUEST_ID ||
        get_u32(legacy + REQUEST_STRING_LENGTH_OFF) != 0x43U)
        return 0;

    if (!build_swapped_reply(captured_error, LEGACY_REPLY_ID, -304))
        return 0;
    decoded_error =
        decode_ndr_i32(captured_error, REPLY_NDR_OFF, REPLY_RESULT_OFF);

    fprintf(stderr,
            "PM_CPS_REGISTRATION_COMPAT_SNOW_LAYOUT:bits=0x%08lx id=0x%08lx send=0x%08lx recv=0x%08lx stringLength=0x%08lx\n",
            (unsigned long)get_u32(legacy + 0x00U),
            (unsigned long)get_u32(legacy + HEADER_ID_OFF),
            (unsigned long)legacy_send_size,
            (unsigned long)RECV_SIZE,
            (unsigned long)get_u32(legacy + REQUEST_STRING_LENGTH_OFF));
    fprintf(stderr,
            "PM_CPS_REGISTRATION_COMPAT_CAPTURED_ERROR_MODEL:raw=0x%08lx decoded=%ld ndrSwapped=%s\n",
            (unsigned long)get_u32(captured_error + REPLY_RESULT_OFF),
            (long)decoded_error,
            ndr_is_swapped(captured_error, REPLY_NDR_OFF) ? "YES" : "NO");

    if (decoded_error != -304)
        return 0;

    fprintf(stderr, "PM_CPS_REGISTRATION_COMPAT_RESULT:SNOW_CONTROL_PASS\n");
    return 1;
}

static int
run_lion_policy_proof(void)
{
    unsigned char legacy[MAX_REQUEST_SIZE];
    unsigned char legacy_before[MAX_REQUEST_SIZE];
    unsigned char lion[MAX_REQUEST_SIZE];
    unsigned char lion_reply[RECV_SIZE];
    unsigned char legacy_reply[RECV_SIZE];
    uint32_t legacy_send_size;
    uint32_t lion_send_size;
    uint32_t tail_off;
    unsigned int changed_common;
    unsigned int reply_changed;
    unsigned int source_changed = 0U;
    uint32_t off;
    int32_t parsed_result;

    fprintf(stderr, "%s\n", BUILD_MARKER);

    if (!build_representative_legacy_request(legacy, &legacy_send_size))
        return 0;
    memcpy(legacy_before, legacy, sizeof(legacy));

    if (!transform_legacy_request_copy(legacy, legacy_send_size,
                                       lion, &lion_send_size,
                                       &changed_common))
        return 0;

    for (off = 0U; off < MAX_REQUEST_SIZE; ++off) {
        if (legacy[off] != legacy_before[off])
            ++source_changed;
    }

    tail_off = legacy_send_size;

    fprintf(stderr,
            "PM_CPS_REGISTRATION_COMPAT_REQUEST_POLICY:legacyId=0x%08lx lionId=0x%08lx legacySend=0x%08lx lionSend=0x%08lx recv=0x%08lx changedCommonBytes=%u sourceChangedBytes=%u tailByte=0x%02x tailU32_0=0x%08lx tailU32_1=0x%08lx\n",
            (unsigned long)get_u32(legacy + HEADER_ID_OFF),
            (unsigned long)get_u32(lion + HEADER_ID_OFF),
            (unsigned long)legacy_send_size,
            (unsigned long)lion_send_size,
            (unsigned long)RECV_SIZE,
            changed_common,
            source_changed,
            (unsigned int)lion[tail_off + LION_TAIL_BYTE_REL],
            (unsigned long)get_u32(lion + tail_off + LION_TAIL_U32_0_REL),
            (unsigned long)get_u32(lion + tail_off + LION_TAIL_U32_1_REL));

    if (legacy_send_size != 0x84U ||
        lion_send_size != 0x90U ||
        get_u32(lion + HEADER_ID_OFF) != LION_REQUEST_ID ||
        changed_common == 0U ||
        source_changed != 0U ||
        lion[tail_off + LION_TAIL_BYTE_REL] != 0U ||
        lion[tail_off + 1U] != 0U ||
        lion[tail_off + 2U] != 0U ||
        lion[tail_off + 3U] != 0U ||
        get_u32(lion + tail_off + LION_TAIL_U32_0_REL) != 0U ||
        get_u32(lion + tail_off + LION_TAIL_U32_1_REL) != 0x10U)
        return 0;

    if (!build_swapped_reply(lion_reply, LION_REPLY_ID, 0))
        return 0;
    if (!transform_lion_reply_copy(lion_reply, legacy_reply,
                                   &reply_changed))
        return 0;

    parsed_result =
        decode_ndr_i32(legacy_reply, REPLY_NDR_OFF, REPLY_RESULT_OFF);

    fprintf(stderr,
            "PM_CPS_REGISTRATION_COMPAT_REPLY_POLICY:lionId=0x%08lx legacyId=0x%08lx size=0x%08lx changedBytes=%u result=%ld ndrSwapped=%s\n",
            (unsigned long)get_u32(lion_reply + HEADER_ID_OFF),
            (unsigned long)get_u32(legacy_reply + HEADER_ID_OFF),
            (unsigned long)get_u32(legacy_reply + 0x04U),
            reply_changed,
            (long)parsed_result,
            ndr_is_swapped(legacy_reply, REPLY_NDR_OFF) ? "YES" : "NO");

    if (get_u32(legacy_reply + HEADER_ID_OFF) != LEGACY_REPLY_ID ||
        get_u32(legacy_reply + 0x04U) != SUCCESS_REPLY_SIZE ||
        parsed_result != 0 ||
        reply_changed == 0U)
        return 0;

    fprintf(stderr,
            "PM_CPS_REGISTRATION_COMPAT_RESULT:LION_POLICY_PROOF_PASS\n");
    return 1;
}

int
main(int argc, char **argv)
{
    int ok = 0;

    if (argc != 2) {
        fprintf(stderr, "usage: %s snow-control|lion-policy-proof\n",
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
        fprintf(stderr, "PM_CPS_REGISTRATION_COMPAT_RESULT:FAIL\n");
        return 1;
    }

    return 0;
}
