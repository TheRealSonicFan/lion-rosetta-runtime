#include <mach/ndr.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BUILD_ID "createwindow-cgs-releasebacking-compat-protocol-v1"
#define BUILD_MARKER "PM_CGS_RELEASEBACKING_COMPAT_BUILD_ID:" BUILD_ID

#define LEGACY_REQUEST_ID 0x0000724bU
#define LEGACY_REPLY_ID 0x000072afU
#define LION_REQUEST_ID 0x0000724cU
#define LION_REPLY_ID 0x000072b0U

#define REQUEST_BITS 0x00001513U
#define SEND_SIZE 0x00000028U
#define RECV_SIZE 0x0000002cU
#define REPLY_SIZE 0x00000024U

#define HEADER_ID_OFF 0x14U
#define NDR_OFF 0x18U
#define RESULT_OFF 0x20U
#define WINDOW_ID_OFF 0x20U
#define RELEASE_FLAG_OFF 0x24U
#define BUFFER_SIZE 0x00000040U

#define SNOW_CAPTURED_WINDOW_ID 0x000000ffU
#define LION_CAPTURED_WINDOW_ID 0x0000020aU
#define CAPTURED_RELEASE_FLAG 0x00000001U
#define CAPTURED_ERROR_RAW 0xd0feffffU

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
ndr_is_swapped(const unsigned char *message)
{
    const unsigned char *local_ndr = (const unsigned char *)&NDR_record;
    return message[NDR_OFF + 4U] != local_ndr[4];
}

static int32_t
decode_ndr_i32(const unsigned char *message, uint32_t off)
{
    uint32_t value = get_u32(message + off);
    if (ndr_is_swapped(message))
        value = swap_u32(value);
    return (int32_t)value;
}

static void
set_local_ndr(unsigned char *message)
{
    memcpy(message + NDR_OFF, &NDR_record, sizeof(NDR_record));
}

static void
set_swapped_ndr(unsigned char *message)
{
    const unsigned char *local_ndr = (const unsigned char *)&NDR_record;
    memcpy(message + NDR_OFF, local_ndr, sizeof(NDR_record));
    message[NDR_OFF + 4U] =
        (unsigned char)(message[NDR_OFF + 4U] == 0U ? 1U : 0U);
}

static unsigned int
count_changes(const unsigned char *a, const unsigned char *b, uint32_t size)
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
count_body_changes(const unsigned char *a,
                   const unsigned char *b,
                   uint32_t size)
{
    uint32_t i;
    unsigned int changed = 0U;

    for (i = 0U; i < size; ++i) {
        if (i >= HEADER_ID_OFF && i < HEADER_ID_OFF + 4U)
            continue;
        if (a[i] != b[i])
            ++changed;
    }
    return changed;
}

static void
build_legacy_request(unsigned char *request, uint32_t window_id)
{
    memset(request, 0, BUFFER_SIZE);

    put_u32(request + 0x00U, REQUEST_BITS);
    put_u32(request + 0x04U, 0x00000000U);
    put_u32(request + 0x08U, 0x11111111U);
    put_u32(request + 0x0cU, 0x22222222U);
    put_u32(request + 0x10U, 0x00000000U);
    put_u32(request + HEADER_ID_OFF, LEGACY_REQUEST_ID);
    set_local_ndr(request);
    put_u32(request + WINDOW_ID_OFF, window_id);
    put_u32(request + RELEASE_FLAG_OFF, CAPTURED_RELEASE_FLAG);
}

static void
build_reply(unsigned char *reply, uint32_t id, uint32_t raw_result)
{
    memset(reply, 0, BUFFER_SIZE);
    put_u32(reply + 0x00U, 0x00001200U);
    put_u32(reply + 0x04U, REPLY_SIZE);
    put_u32(reply + HEADER_ID_OFF, id);
    set_swapped_ndr(reply);
    put_u32(reply + RESULT_OFF, raw_result);
}

static int
transform_request_copy(const unsigned char *legacy,
                       unsigned char *lion,
                       unsigned int *changed,
                       unsigned int *body_changed,
                       unsigned int *source_changed)
{
    unsigned char before[BUFFER_SIZE];

    if (get_u32(legacy + 0x00U) != REQUEST_BITS ||
        get_u32(legacy + HEADER_ID_OFF) != LEGACY_REQUEST_ID ||
        get_u32(legacy + RELEASE_FLAG_OFF) != CAPTURED_RELEASE_FLAG)
        return 0;

    memcpy(before, legacy, BUFFER_SIZE);
    memcpy(lion, legacy, BUFFER_SIZE);
    put_u32(lion + HEADER_ID_OFF, LION_REQUEST_ID);

    *changed = count_changes(legacy, lion, SEND_SIZE);
    *body_changed = count_body_changes(legacy, lion, SEND_SIZE);
    *source_changed = count_changes(legacy, before, SEND_SIZE);
    return 1;
}

static int
transform_reply_copy(const unsigned char *lion,
                     unsigned char *legacy,
                     unsigned int *changed,
                     unsigned int *body_changed)
{
    if (get_u32(lion + HEADER_ID_OFF) != LION_REPLY_ID ||
        get_u32(lion + 0x04U) != REPLY_SIZE)
        return 0;

    memcpy(legacy, lion, BUFFER_SIZE);
    put_u32(legacy + HEADER_ID_OFF, LEGACY_REPLY_ID);

    *changed = count_changes(lion, legacy, REPLY_SIZE);
    *body_changed = count_body_changes(lion, legacy, REPLY_SIZE);
    return 1;
}

static int
run_snow_control(void)
{
    unsigned char request[BUFFER_SIZE];
    unsigned char success[BUFFER_SIZE];
    int32_t success_result;

    fprintf(stderr, "%s\n", BUILD_MARKER);

    build_legacy_request(request, SNOW_CAPTURED_WINDOW_ID);
    build_reply(success, LEGACY_REPLY_ID, 0x00000000U);
    success_result = decode_ndr_i32(success, RESULT_OFF);

    fprintf(stderr,
            "PM_CGS_RELEASEBACKING_COMPAT_SNOW_LAYOUT:bits=0x%08lx legacyId=0x%08lx send=0x%08lx recv=0x%08lx reply=0x%08lx off20=0x%08lx off24=0x%08lx\n",
            (unsigned long)get_u32(request + 0x00U),
            (unsigned long)get_u32(request + HEADER_ID_OFF),
            (unsigned long)SEND_SIZE,
            (unsigned long)RECV_SIZE,
            (unsigned long)REPLY_SIZE,
            (unsigned long)get_u32(request + WINDOW_ID_OFF),
            (unsigned long)get_u32(request + RELEASE_FLAG_OFF));
    fprintf(stderr,
            "PM_CGS_RELEASEBACKING_COMPAT_SNOW_SUCCESS_REPLY:legacyId=0x%08lx size=0x%08lx decodedResult=%ld ndrSwapped=%s\n",
            (unsigned long)get_u32(success + HEADER_ID_OFF),
            (unsigned long)get_u32(success + 0x04U),
            (long)success_result,
            ndr_is_swapped(success) ? "YES" : "NO");

    if (get_u32(request + HEADER_ID_OFF) != LEGACY_REQUEST_ID ||
        get_u32(request + WINDOW_ID_OFF) != SNOW_CAPTURED_WINDOW_ID ||
        get_u32(request + RELEASE_FLAG_OFF) != CAPTURED_RELEASE_FLAG ||
        get_u32(success + HEADER_ID_OFF) != LEGACY_REPLY_ID ||
        success_result != 0)
        return 0;

    fprintf(stderr, "PM_CGS_RELEASEBACKING_COMPAT_RESULT:SNOW_CONTROL_PASS\n");
    return 1;
}

static int
run_lion_policy_proof(void)
{
    unsigned char legacy_request[BUFFER_SIZE];
    unsigned char legacy_before[BUFFER_SIZE];
    unsigned char lion_request[BUFFER_SIZE];
    unsigned char native_success[BUFFER_SIZE];
    unsigned char legacy_success[BUFFER_SIZE];
    unsigned char native_error[BUFFER_SIZE];
    unsigned char legacy_error[BUFFER_SIZE];
    unsigned int request_changed = 0U;
    unsigned int request_body_changed = 0U;
    unsigned int source_changed = 0U;
    unsigned int success_changed = 0U;
    unsigned int success_body_changed = 0U;
    unsigned int error_changed = 0U;
    unsigned int error_body_changed = 0U;
    int32_t success_result;
    int32_t error_result;

    fprintf(stderr, "%s\n", BUILD_MARKER);

    build_legacy_request(legacy_request, LION_CAPTURED_WINDOW_ID);
    memcpy(legacy_before, legacy_request, BUFFER_SIZE);

    if (!transform_request_copy(legacy_request, lion_request,
                                &request_changed, &request_body_changed,
                                &source_changed))
        return 0;

    source_changed = count_changes(legacy_request, legacy_before, SEND_SIZE);

    fprintf(stderr,
            "PM_CGS_RELEASEBACKING_COMPAT_REQUEST_POLICY:legacyId=0x%08lx lionId=0x%08lx send=0x%08lx recv=0x%08lx off20=0x%08lx off24=0x%08lx changedBytes=%u bodyChangedBytes=%u sourceChangedBytes=%u\n",
            (unsigned long)get_u32(legacy_request + HEADER_ID_OFF),
            (unsigned long)get_u32(lion_request + HEADER_ID_OFF),
            (unsigned long)SEND_SIZE,
            (unsigned long)RECV_SIZE,
            (unsigned long)get_u32(legacy_request + WINDOW_ID_OFF),
            (unsigned long)get_u32(legacy_request + RELEASE_FLAG_OFF),
            request_changed,
            request_body_changed,
            source_changed);

    if (request_changed != 1U ||
        request_body_changed != 0U ||
        source_changed != 0U ||
        get_u32(lion_request + HEADER_ID_OFF) != LION_REQUEST_ID ||
        get_u32(lion_request + WINDOW_ID_OFF) != LION_CAPTURED_WINDOW_ID ||
        get_u32(lion_request + RELEASE_FLAG_OFF) != CAPTURED_RELEASE_FLAG)
        return 0;

    build_reply(native_success, LION_REPLY_ID, 0x00000000U);
    if (!transform_reply_copy(native_success, legacy_success,
                              &success_changed, &success_body_changed))
        return 0;
    success_result = decode_ndr_i32(legacy_success, RESULT_OFF);

    fprintf(stderr,
            "PM_CGS_RELEASEBACKING_COMPAT_SUCCESS_REPLY_POLICY:lionId=0x%08lx legacyId=0x%08lx size=0x%08lx changedBytes=%u bodyChangedBytes=%u decodedResult=%ld ndrSwapped=%s\n",
            (unsigned long)get_u32(native_success + HEADER_ID_OFF),
            (unsigned long)get_u32(legacy_success + HEADER_ID_OFF),
            (unsigned long)get_u32(legacy_success + 0x04U),
            success_changed,
            success_body_changed,
            (long)success_result,
            ndr_is_swapped(legacy_success) ? "YES" : "NO");

    if (success_changed != 1U ||
        success_body_changed != 0U ||
        success_result != 0 ||
        get_u32(legacy_success + HEADER_ID_OFF) != LEGACY_REPLY_ID)
        return 0;

    build_reply(native_error, LION_REPLY_ID, CAPTURED_ERROR_RAW);
    if (!transform_reply_copy(native_error, legacy_error,
                              &error_changed, &error_body_changed))
        return 0;
    error_result = decode_ndr_i32(legacy_error, RESULT_OFF);

    fprintf(stderr,
            "PM_CGS_RELEASEBACKING_COMPAT_ERROR_REPLY_POLICY:lionId=0x%08lx legacyId=0x%08lx size=0x%08lx changedBytes=%u bodyChangedBytes=%u rawResult=0x%08lx decodedResult=%ld ndrSwapped=%s\n",
            (unsigned long)get_u32(native_error + HEADER_ID_OFF),
            (unsigned long)get_u32(legacy_error + HEADER_ID_OFF),
            (unsigned long)get_u32(legacy_error + 0x04U),
            error_changed,
            error_body_changed,
            (unsigned long)get_u32(legacy_error + RESULT_OFF),
            (long)error_result,
            ndr_is_swapped(legacy_error) ? "YES" : "NO");

    if (error_changed != 1U ||
        error_body_changed != 0U ||
        get_u32(legacy_error + RESULT_OFF) != CAPTURED_ERROR_RAW ||
        error_result != -304 ||
        get_u32(legacy_error + HEADER_ID_OFF) != LEGACY_REPLY_ID)
        return 0;

    fprintf(stderr,
            "PM_CGS_RELEASEBACKING_COMPAT_RESULT:LION_POLICY_PROOF_PASS\n");
    return 1;
}

int
main(int argc, char **argv)
{
    int ok = 0;

    if (argc != 2) {
        fprintf(stderr, "usage: %s snow-control|lion-policy-proof\n", argv[0]);
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
        fprintf(stderr, "PM_CGS_RELEASEBACKING_COMPAT_RESULT:FAIL\n");
        return 1;
    }

    return 0;
}
