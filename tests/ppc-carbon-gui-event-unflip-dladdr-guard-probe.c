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

typedef uintptr_t (*target_return_fn)(void);
typedef int (*classify_fn)(uintptr_t);
typedef int (*original_dladdr_fn)(const void *, Dl_info *);
typedef void (*counts_fn)(unsigned int *, unsigned int *);

static CGDirectDisplayID (*volatile force_coregraphics_dependency)(void) =
    CGMainDisplayID;

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
    Dl_info original_info;
    Dl_info wrapped_info;
    int original_result;
    int wrapped_result;
    int result_match;
    int info_match;
    unsigned int non_target_count;
    unsigned int target_count;
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

    memset(&original_info, 0, sizeof(original_info));
    memset(&wrapped_info, 0, sizeof(wrapped_info));
    original_result = call_original((const void *)(uintptr_t)&main,
                                    &original_info);
    wrapped_result = dladdr((const void *)(uintptr_t)&main, &wrapped_info);

    result_match = (original_result == wrapped_result);
    info_match = result_match &&
        original_info.dli_fbase == wrapped_info.dli_fbase &&
        original_info.dli_saddr == wrapped_info.dli_saddr &&
        nullable_string_equal(original_info.dli_fname, wrapped_info.dli_fname) &&
        nullable_string_equal(original_info.dli_sname, wrapped_info.dli_sname);

    printf("original_replacee_available=%s\n",
           original_result ? "YES" : "NO");
    printf("original_dladdr_result=%d\n", original_result);
    printf("interposed_dladdr_result=%d\n", wrapped_result);
    printf("passthrough_result_match=%s\n", result_match ? "YES" : "NO");
    printf("passthrough_info_match=%s\n", info_match ? "YES" : "NO");

    non_target_count = 0;
    target_count = 0;
    get_counts(&non_target_count, &target_count);
    printf("interposer_non_target_forward_count=%u\n", non_target_count);
    printf("interposer_target_wrapper_count=%u\n", target_count);
    printf("patched_target_wrapper_executed=%s\n",
           target_count == 0 ? "NO" : "YES");

    success = exact_match && minus4_reject && plus4_reject &&
              original_result != 0 && wrapped_result != 0 &&
              result_match && info_match &&
              non_target_count >= 1 && target_count == 0;

    printf("preflight_complete=%s\n", success ? "YES" : "NO");
    if (success) {
        printf("RESULT: PASS\n");
        return 0;
    }
    printf("RESULT: FAIL\n");
    return 1;
}
