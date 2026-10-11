#include <mach/ndr.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BUILD_ID "createwindow-cgs-newwindow-compat-protocol-v1"
#define BUILD_MARKER "PM_CGS_NEWWINDOW_COMPAT_BUILD_ID:" BUILD_ID

#define LEGACY_REQUEST_ID 0x00007394U
#define LEGACY_REPLY_ID 0x000073f8U
#define LION_REQUEST_ID 0x0000739aU
#define LION_REPLY_ID 0x000073feU

#define REQUEST_BITS 0x00001513U
#define SEND_SIZE 0x00000068U
#define RECV_SIZE 0x00000040U
#define SUCCESS_REPLY_SIZE 0x00000038U
#define ERROR_REPLY_SIZE 0x00000024U

#define HEADER_ID_OFF 0x14U
#define NDR_OFF 0x18U
#define ERROR_RESULT_OFF 0x20U
#define BUFFER_SIZE 0x00000080U

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
build_representative_legacy_request(unsigned char *request)
{
    uint32_t off;

    memset(request, 0, BUFFER_SIZE);

    put_u32(request + 0x00U, REQUEST_BITS);
    put_u32(request + 0x04U, 0x00000000U);
    put_u32(request + 0x08U, 0x11111111U);
    put_u32(request + 0x0cU, 0x22222222U);
    put_u32(request + 0x10U, 0x00000000U);
    put_u32(request + HEADER_ID_OFF, LEGACY_REQUEST_ID);

    put_u32(request + 0x18U, 0x00000000U);
    put_u32(request + 0x1cU, 0x00000000U);
    put_u32(request + 0x20U, 0x00000002U);
    put_u32(request + 0x24U, 0x00000009U);
    put_u32(request + 0x28U, 0x80000000U);
    put_u32(request + 0x2cU, 0x00000002U);
    put_u32(request + 0x30U, 0x00000062U);
    put_u32(request + 0x34U, 0x00000004U);
    put_u32(request + 0x38U, 0x00000078U);
    put_u32(request + 0x3cU, 0x00000079U);
    put_u32(request + 0x40U, 0x00000063U);

    /*
     * The passive trace intentionally stopped after the visible 0x40 word.
     * Fill the remaining copied payload with deterministic sentinels so this
     * proof tests preservation without inventing semantics for those bytes.
     */
    for (off = 0x44U; off < SEND_SIZE; ++off)
        request[off] = (unsigned char)(0x5aU ^ (off & 0xffU));
}

static int
transform_request_copy(const unsigned char *legacy,
                       unsigned char *lion,
                       unsigned int *changed,
                       unsigned int *source_changed)
{
    unsigned char before[BUFFER_SIZE];

    if (get_u32(legacy + 0x00U) != REQUEST_BITS ||
        get_u32(legacy + HEADER_ID_OFF) != LEGACY_REQUEST_ID)
        return 0;

    memcpy(before, legacy, BUFFER_SIZE);
    memcpy(lion, legacy, BUFFER_SIZE);
    put_u32(lion + HEADER_ID_OFF, LION_REQUEST_ID);

    *changed = count_changes(legacy, lion, SEND_SIZE);
    *source_changed = count_changes(legacy, before, SEND_SIZE);
    return 1;
}

static void
build_representative_success_reply(unsigned char *reply, uint32_t id)
{
    memset(reply, 0, BUFFER_SIZE);
    put_u32(reply + 0x00U, 0x00001200U);
    put_u32(reply + 0x04U, SUCCESS_REPLY_SIZE);
    put_u32(reply + HEADER_ID_OFF, id);
    set_swapped_ndr(reply);

    put_u32(reply + 0x20U, 0x00000000U);
    put_u32(reply + 0x24U, 0x02000000U);
    put_u32(reply + 0x28U, 0x80500000U);
    put_u32(reply + 0x2cU, 0x08000000U);
    put_u32(reply + 0x30U, 0xc0770000U);
    put_u32(reply + 0x34U, 0xf3000000U);
}

static void
build_representative_error_reply(unsigned char *reply, uint32_t id)
{
    memset(reply, 0, BUFFER_SIZE);
    put_u32(reply + 0x00U, 0x00001200U);
    put_u32(reply + 0x04U, ERROR_REPLY_SIZE);
    put_u32(reply + HEADER_ID_OFF, id);
    set_swapped_ndr(reply);
    put_u32(reply + ERROR_RESULT_OFF, 0xd0feffffU);
}

static int
transform_reply_copy(const unsigned char *lion,
                     unsigned char *legacy,
                     uint32_t size,
                     unsigned int *changed,
                     unsigned int *body_changed)
{
    if (size != SUCCESS_REPLY_SIZE && size != ERROR_REPLY_SIZE)
        return 0;
    if (get_u32(lion + HEADER_ID_OFF) != LION_REPLY_ID)
        return 0;
    if (get_u32(lion + 0x04U) != size)
        return 0;

    memcpy(legacy, lion, BUFFER_SIZE);
    put_u32(legacy + HEADER_ID_OFF, LEGACY_REPLY_ID);

    *changed = count_changes(lion, legacy, size);
    *body_changed = count_body_changes(lion, legacy, size);
    return 1;
}

static int
run_snow_control(void)
{
    unsigned char request[BUFFER_SIZE];
    unsigned char captured_error[BUFFER_SIZE];
    int32_t decoded;

    fprintf(stderr, "%s\n", BUILD_MARKER);
    build_representative_legacy_request(request);
    build_representative_error_reply(captured_error, LEGACY_REPLY_ID);
    decoded = decode_ndr_i32(captured_error, ERROR_RESULT_OFF);

    fprintf(stderr,
            "PM_CGS_NEWWINDOW_COMPAT_SNOW_LAYOUT:bits=0x%08lx legacyId=0x%08lx send=0x%08lx recv=0x%08lx successReply=0x%08lx errorReply=0x%08lx\n",
            (unsigned long)get_u32(request + 0x00U),
            (unsigned long)get_u32(request + HEADER_ID_OFF),
            (unsigned long)SEND_SIZE,
            (unsigned long)RECV_SIZE,
            (unsigned long)SUCCESS_REPLY_SIZE,
            (unsigned long)ERROR_REPLY_SIZE);
    fprintf(stderr,
            "PM_CGS_NEWWINDOW_COMPAT_VISIBLE_REQUEST_WORDS:off18=0x%08lx off1c=0x%08lx off20=0x%08lx off24=0x%08lx off28=0x%08lx off2c=0x%08lx off30=0x%08lx off34=0x%08lx off38=0x%08lx off3c=0x%08lx off40=0x%08lx\n",
            (unsigned long)get_u32(request + 0x18U),
            (unsigned long)get_u32(request + 0x1cU),
            (unsigned long)get_u32(request + 0x20U),
            (unsigned long)get_u32(request + 0x24U),
            (unsigned long)get_u32(request + 0x28U),
            (unsigned long)get_u32(request + 0x2cU),
            (unsigned long)get_u32(request + 0x30U),
            (unsigned long)get_u32(request + 0x34U),
            (unsigned long)get_u32(request + 0x38U),
            (unsigned long)get_u32(request + 0x3cU),
            (unsigned long)get_u32(request + 0x40U));
    fprintf(stderr,
            "PM_CGS_NEWWINDOW_COMPAT_CAPTURED_ERROR_MODEL:raw=0x%08lx decoded=%ld ndrSwapped=%s\n",
            (unsigned long)get_u32(captured_error + ERROR_RESULT_OFF),
            (long)decoded,
            ndr_is_swapped(captured_error) ? "YES" : "NO");

    if (decoded != -304 ||
        get_u32(request + HEADER_ID_OFF) != LEGACY_REQUEST_ID)
        return 0;

    fprintf(stderr, "PM_CGS_NEWWINDOW_COMPAT_RESULT:SNOW_CONTROL_PASS\n");
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
    unsigned int source_changed = 0U;
    unsigned int success_changed = 0U;
    unsigned int success_body_changed = 0U;
    unsigned int error_changed = 0U;
    unsigned int error_body_changed = 0U;
    int32_t error_result;

    fprintf(stderr, "%s\n", BUILD_MARKER);

    build_representative_legacy_request(legacy_request);
    memcpy(legacy_before, legacy_request, BUFFER_SIZE);

    if (!transform_request_copy(legacy_request, lion_request,
                                &request_changed, &source_changed))
        return 0;

    source_changed = count_changes(legacy_request, legacy_before, SEND_SIZE);

    fprintf(stderr,
            "PM_CGS_NEWWINDOW_COMPAT_REQUEST_POLICY:legacyId=0x%08lx lionId=0x%08lx send=0x%08lx recv=0x%08lx changedBytes=%u sourceChangedBytes=%u\n",
            (unsigned long)get_u32(legacy_request + HEADER_ID_OFF),
            (unsigned long)get_u32(lion_request + HEADER_ID_OFF),
            (unsigned long)SEND_SIZE,
            (unsigned long)RECV_SIZE,
            request_changed,
            source_changed);

    if (request_changed != 1U || source_changed != 0U ||
        get_u32(lion_request + HEADER_ID_OFF) != LION_REQUEST_ID)
        return 0;

    build_representative_success_reply(native_success, LION_REPLY_ID);
    if (!transform_reply_copy(native_success, legacy_success,
                              SUCCESS_REPLY_SIZE,
                              &success_changed, &success_body_changed))
        return 0;

    fprintf(stderr,
            "PM_CGS_NEWWINDOW_COMPAT_SUCCESS_REPLY_POLICY:lionId=0x%08lx legacyId=0x%08lx size=0x%08lx changedBytes=%u bodyChangedBytes=%u ndrSwapped=%s\n",
            (unsigned long)get_u32(native_success + HEADER_ID_OFF),
            (unsigned long)get_u32(legacy_success + HEADER_ID_OFF),
            (unsigned long)get_u32(legacy_success + 0x04U),
            success_changed,
            success_body_changed,
            ndr_is_swapped(legacy_success) ? "YES" : "NO");

    if (success_changed != 1U || success_body_changed != 0U ||
        get_u32(legacy_success + HEADER_ID_OFF) != LEGACY_REPLY_ID)
        return 0;

    build_representative_error_reply(native_error, LION_REPLY_ID);
    if (!transform_reply_copy(native_error, legacy_error,
                              ERROR_REPLY_SIZE,
                              &error_changed, &error_body_changed))
        return 0;

    error_result = decode_ndr_i32(legacy_error, ERROR_RESULT_OFF);

    fprintf(stderr,
            "PM_CGS_NEWWINDOW_COMPAT_ERROR_REPLY_POLICY:lionId=0x%08lx legacyId=0x%08lx size=0x%08lx changedBytes=%u bodyChangedBytes=%u decodedResult=%ld ndrSwapped=%s\n",
            (unsigned long)get_u32(native_error + HEADER_ID_OFF),
            (unsigned long)get_u32(legacy_error + HEADER_ID_OFF),
            (unsigned long)get_u32(legacy_error + 0x04U),
            error_changed,
            error_body_changed,
            (long)error_result,
            ndr_is_swapped(legacy_error) ? "YES" : "NO");

    if (error_changed != 1U || error_body_changed != 0U ||
        error_result != -304)
        return 0;

    fprintf(stderr,
            "PM_CGS_NEWWINDOW_COMPAT_RESULT:LION_POLICY_PROOF_PASS\n");
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
        fprintf(stderr, "PM_CGS_NEWWINDOW_COMPAT_RESULT:FAIL\n");
        return 1;
    }

    return 0;
}
