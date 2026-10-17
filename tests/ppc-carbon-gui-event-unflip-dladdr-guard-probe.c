/*
 * Non-patching subject for the proof-only event-unflip dladdr interposer.
 */

#include <ApplicationServices/ApplicationServices.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/utsname.h>

#define PROBE_CONTRACT "carbon-gui-event-unflip-dladdr-guard-preflight-v1"
#define MODE_ENV "ROSETTA_EVENT_UNFLIP_DLADDR_GUARD_MODE"
#define MODE_SNOW "passthrough"
#define MODE_LION "lion-guard-v1"
#define MAIN_TO_TARGET_RETURN 0x00003ff4UL
#define DLADDR_STUB_DELTA_FROM_MAIN 0x00528d40UL

typedef uintptr_t (*target_return_fn)(void);
typedef int (*classify_fn)(uintptr_t);
typedef int (*original_dladdr_fn)(const void *, Dl_info *);
typedef void (*counts_fn)(unsigned int *, unsigned int *);
typedef int (*dladdr_fn)(const void *, Dl_info *);

static CGDirectDisplayID (*volatile force_coregraphics_dependency)(void) =
    CGMainDisplayID;

static uint32_t
read_u32(const void *p)
{
    uint32_t value;
    memcpy(&value, p, sizeof(value));
    return value;
}

static int
nullable_string_equal(const char *a, const char *b)
{
    if (a == NULL || b == NULL)
        return a == b;
    return strcmp(a, b) == 0;
}

int
main(void)
{
    struct utsname uts;
    const char *mode;
    target_return_fn get_target;
    classify_fn classify;
    original_dladdr_fn call_original;
    counts_fn get_counts;
    uintptr_t target;
    int exact_match;
    int minus4_reject;
    int plus4_reject;
    uintptr_t main_runtime;
    uintptr_t stub_runtime;
    dladdr_fn selected_stub;
    uint32_t stub_first_word;
    uint32_t stub_restore_lr_word;
    uint32_t stub_mtctr_word;
    uint32_t stub_tail_word;
    int stub_shape_match;
    Dl_info original_info;
    Dl_info stub_info;
    int original_result;
    int stub_result;
    int result_match;
    int info_match;
    unsigned int non_target_before;
    unsigned int target_before;
    unsigned int non_target_after;
    unsigned int target_after;
    unsigned int non_target_delta;
    int mode_ok;
    int success;

    (void)force_coregraphics_dependency;

    printf("== PPC Carbon GUI event-unflip dladdr guard preflight ==\n");
    printf("probe_contract=%s\n", PROBE_CONTRACT);
    printf("coregraphics_text_write_attempts=0\n");
    printf("vm_protect_attempts=0\n");
    printf("vm_allocate_attempts=0\n");
    printf("candidate_instruction_execution_attempts=0\n");
    printf("functional_source_helper_load_attempts=0\n");
    printf("original_gui_launch_count=0\n");

    if (sizeof(void *) != 4) {
        printf("pointer_size=%lu\n", (unsigned long)sizeof(void *));
        printf("RESULT: FAIL\n");
        return 2;
    }
    printf("pointer_size=4\n");

    if (uname(&uts) != 0) {
        printf("uname=FAIL\n");
        printf("RESULT: FAIL\n");
        return 3;
    }
    printf("darwin_release=%s\n", uts.release);

    mode = getenv(MODE_ENV);
    printf("guard_mode=%s\n", mode ? mode : "UNSET");
    mode_ok = 0;
    if (strncmp(uts.release, "10.", 3) == 0 &&
        mode != NULL && strcmp(mode, MODE_SNOW) == 0) {
        printf("preflight_mode=snow-ppc-control\n");
        mode_ok = 1;
    } else if (strncmp(uts.release, "11.", 3) == 0 &&
               mode != NULL && strcmp(mode, MODE_LION) == 0) {
        printf("preflight_mode=lion-ppc-translated\n");
        mode_ok = 1;
    } else {
        printf("preflight_mode=unsupported-or-mode-mismatch\n");
    }
    if (!mode_ok) {
        printf("RESULT: FAIL\n");
        return 4;
    }

    get_target = (target_return_fn)dlsym(
        RTLD_DEFAULT, "rosetta_event_unflip_dladdr_guard_target_return");
    classify = (classify_fn)dlsym(
        RTLD_DEFAULT, "rosetta_event_unflip_dladdr_guard_classify");
    call_original = (original_dladdr_fn)dlsym(
        RTLD_DEFAULT, "rosetta_event_unflip_dladdr_guard_call_original");
    get_counts = (counts_fn)dlsym(
        RTLD_DEFAULT, "rosetta_event_unflip_dladdr_guard_get_counts");

    printf("guard_target_helper_dlsym=%s\n", get_target ? "PASS" : "FAIL");
    printf("guard_classify_helper_dlsym=%s\n", classify ? "PASS" : "FAIL");
    printf("original_replacee_helper_dlsym=%s\n", call_original ? "PASS" : "FAIL");
    printf("guard_counts_helper_dlsym=%s\n", get_counts ? "PASS" : "FAIL");
    if (!get_target || !classify || !call_original || !get_counts) {
        printf("RESULT: FAIL\n");
        return 5;
    }

    target = get_target();
    printf("target_return_runtime=0x%08lx\n", (unsigned long)target);
    printf("target_return_resolved=%s\n", target ? "YES" : "NO");
    if (target == 0) {
        printf("RESULT: FAIL\n");
        return 6;
    }

    exact_match = classify(target);
    minus4_reject = !classify(target - 4);
    plus4_reject = !classify(target + 4);
    printf("guard_exact_match=%s\n", exact_match ? "YES" : "NO");
    printf("guard_minus4_reject=%s\n", minus4_reject ? "YES" : "NO");
    printf("guard_plus4_reject=%s\n", plus4_reject ? "YES" : "NO");

    main_runtime = target - MAIN_TO_TARGET_RETURN;
    stub_runtime = main_runtime + DLADDR_STUB_DELTA_FROM_MAIN;
    selected_stub = (dladdr_fn)(uintptr_t)stub_runtime;
    printf("derived_CGSMainDisplayID_runtime=0x%08lx\n",
           (unsigned long)main_runtime);
    printf("selected_dladdr_stub_runtime=0x%08lx\n",
           (unsigned long)stub_runtime);

    stub_first_word = read_u32((const void *)stub_runtime);
    stub_restore_lr_word = read_u32((const void *)(stub_runtime + 0x10));
    stub_mtctr_word = read_u32((const void *)(stub_runtime + 0x18));
    stub_tail_word = read_u32((const void *)(stub_runtime + 0x1c));
    stub_shape_match =
        stub_first_word == 0x7c0802a6U &&
        stub_restore_lr_word == 0x7c0803a6U &&
        stub_mtctr_word == 0x7d8903a6U &&
        stub_tail_word == 0x4e800420U;
    printf("selected_dladdr_stub_first_word=0x%08x\n", stub_first_word);
    printf("selected_dladdr_stub_restore_lr_word=0x%08x\n",
           stub_restore_lr_word);
    printf("selected_dladdr_stub_mtctr_word=0x%08x\n", stub_mtctr_word);
    printf("selected_dladdr_stub_tail_word=0x%08x\n", stub_tail_word);
    printf("selected_dladdr_stub_runtime_shape_match=%s\n",
           stub_shape_match ? "YES" : "NO");
    if (!stub_shape_match) {
        printf("RESULT: FAIL\n");
        return 7;
    }

    memset(&original_info, 0, sizeof(original_info));
    memset(&stub_info, 0, sizeof(stub_info));
    original_result = call_original((const void *)(uintptr_t)&main,
                                    &original_info);

    non_target_before = 0;
    target_before = 0;
    get_counts(&non_target_before, &target_before);

    stub_result = selected_stub((const void *)(uintptr_t)&main, &stub_info);

    non_target_after = 0;
    target_after = 0;
    get_counts(&non_target_after, &target_after);
    non_target_delta = non_target_after - non_target_before;

    result_match = (original_result == stub_result);
    info_match = result_match &&
        original_info.dli_fbase == stub_info.dli_fbase &&
        original_info.dli_saddr == stub_info.dli_saddr &&
        nullable_string_equal(original_info.dli_fname, stub_info.dli_fname) &&
        nullable_string_equal(original_info.dli_sname, stub_info.dli_sname);

    printf("original_replacee_available=%s\n",
           original_result ? "YES" : "NO");
    printf("original_dladdr_result=%d\n", original_result);
    printf("selected_stub_dladdr_result=%d\n", stub_result);
    printf("selected_stub_passthrough_result_match=%s\n",
           result_match ? "YES" : "NO");
    printf("selected_stub_passthrough_info_match=%s\n",
           info_match ? "YES" : "NO");
    printf("interposer_non_target_forward_count_before=%u\n",
           non_target_before);
    printf("interposer_non_target_forward_count_after=%u\n",
           non_target_after);
    printf("selected_stub_interposer_forward_delta=%u\n", non_target_delta);
    printf("interposer_target_wrapper_count_before=%u\n", target_before);
    printf("interposer_target_wrapper_count=%u\n", target_after);
    printf("selected_dladdr_stub_direct_probe_calls=1\n");
    printf("patched_target_wrapper_executed=%s\n",
           target_after == 0 ? "NO" : "YES");

    success = exact_match && minus4_reject && plus4_reject &&
              stub_shape_match &&
              original_result != 0 && stub_result != 0 &&
              result_match && info_match &&
              non_target_delta == 1 &&
              target_before == 0 && target_after == 0;

    printf("preflight_complete=%s\n", success ? "YES" : "NO");
    if (success) {
        printf("RESULT: PASS\n");
        return 0;
    }
    printf("RESULT: FAIL\n");
    return 1;
}
