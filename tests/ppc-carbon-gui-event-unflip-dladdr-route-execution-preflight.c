/*
 * Fail-closed execution proof for the event-unflip dladdr-stub route.
 *
 * This probe temporarily changes only the audited CoreGraphics callsite to
 * branch to the already-selected _dladdr PIC stub, executes the containing
 * event-unflip function once against a synthetic event, and requires the
 * proof interposer's exact-return-address target wrapper to fail closed.
 * The functional display-source repair is not implemented here.
 */

#include <ApplicationServices/ApplicationServices.h>
#include <dlfcn.h>
#include <mach/mach.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/utsname.h>
#include <unistd.h>

#if !defined(__ppc__)
#error This preflight is intentionally PowerPC-only.
#endif

#define PROBE_CONTRACT "carbon-gui-event-unflip-dladdr-route-execution-v3"
#define MODE_ENV "ROSETTA_EVENT_UNFLIP_DLADDR_GUARD_MODE"
#define MODE_SNOW "passthrough"
#define MODE_LION "lion-guard-v1"

#define EVENT_DELTA_FROM_MAIN 0x00003facUL
#define CALLSITE_DELTA_FROM_MAIN 0x00003ff0UL
#define TARGET_RETURN_DELTA_FROM_MAIN 0x00003ff4UL
#define DLADDR_STUB_DELTA_FROM_MAIN 0x00528d40UL
#define EXPECTED_ROUTE_DELTA 0x00524d50LL
#define EXPECTED_ROUTE_WORD 0x48524d51U
#define EXPECTED_CALL_WORD 0x4bff702dU
#define EXPECTED_PROLOGUE 0x7c0802a6U
#define BRANCH_MIN_DISP (-0x02000000LL)
#define BRANCH_MAX_DISP ( 0x01fffffcLL)

#define EVENT_SIZE 0x100
#define EVENT_X_OFFSET 0x0c
#define EVENT_Y_OFFSET 0x10
#define EVENT_CACHE_OFFSET 0xc6

extern void sys_dcache_flush(void *, size_t);
extern void sys_icache_invalidate(void *, size_t);

typedef uintptr_t (*target_return_fn)(void);
typedef int (*original_dladdr_fn)(const void *, Dl_info *);
typedef int (*dladdr_fn)(const void *, Dl_info *);
typedef void (*counts_fn)(unsigned int *, unsigned int *);
typedef void *(*event_unflip_fn)(void *, void *);

static CGDirectDisplayID (*volatile force_coregraphics_dependency)(void) =
    CGMainDisplayID;

struct region_snapshot {
    vm_address_t base;
    vm_size_t size;
    vm_prot_t protection;
    vm_prot_t max_protection;
    int shared;
    int reserved;
};

struct point32 {
    float x;
    float y;
};

static uint32_t
read_u32(const void *p)
{
    uint32_t v;
    memcpy(&v, p, sizeof(v));
    return v;
}

static void
write_u32(void *p, uint32_t v)
{
    *(volatile uint32_t *)p = v;
    __asm__ volatile("sync" ::: "memory");
}

static int
nullable_string_equal(const char *a, const char *b)
{
    if (a == NULL || b == NULL)
        return a == b;
    return strcmp(a, b) == 0;
}

static int
query_region(uintptr_t target, struct region_snapshot *out)
{
    vm_address_t address = (vm_address_t)target;
    vm_size_t size = 0;
    vm_region_basic_info_data_t info;
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT;
    mach_port_t object_name = MACH_PORT_NULL;
    kern_return_t kr;
    uint64_t end;

    kr = vm_region(mach_task_self(), &address, &size, VM_REGION_BASIC_INFO,
                   (vm_region_info_t)&info, &count, &object_name);
    if (kr != KERN_SUCCESS)
        return 0;

    end = (uint64_t)address + (uint64_t)size;
    if ((uint64_t)target < (uint64_t)address || (uint64_t)target >= end) {
        if (object_name != MACH_PORT_NULL)
            mach_port_deallocate(mach_task_self(), object_name);
        return 0;
    }

    out->base = address;
    out->size = size;
    out->protection = info.protection;
    out->max_protection = info.max_protection;
    out->shared = info.shared;
    out->reserved = info.reserved;

    if (object_name != MACH_PORT_NULL)
        mach_port_deallocate(mach_task_self(), object_name);
    return 1;
}

static void
prot_string(vm_prot_t p, char out[4])
{
    out[0] = (p & VM_PROT_READ) ? 'r' : '-';
    out[1] = (p & VM_PROT_WRITE) ? 'w' : '-';
    out[2] = (p & VM_PROT_EXECUTE) ? 'x' : '-';
    out[3] = '\0';
}

static int
branch_disp_fits(int64_t delta)
{
    return delta >= BRANCH_MIN_DISP && delta <= BRANCH_MAX_DISP &&
           (delta & 3LL) == 0;
}

static uint32_t
encode_relative_bl(int64_t delta)
{
    return 0x48000001U | ((uint32_t)delta & 0x03fffffcU);
}

static void
flush_code_word(void *p)
{
    sys_dcache_flush(p, sizeof(uint32_t));
    sys_icache_invalidate(p, sizeof(uint32_t));
    __asm__ volatile("sync\nisync" ::: "memory");
}

int
main(void)
{
    struct utsname uts;
    const char *mode;
    target_return_fn get_target;
    original_dladdr_fn call_original;
    counts_fn get_counts;
    uintptr_t main_runtime;
    uintptr_t event_runtime;
    uintptr_t callsite_runtime;
    uintptr_t target_return_runtime;
    uintptr_t guard_target_runtime;
    uintptr_t stub_runtime;
    dladdr_fn selected_stub;
    int64_t route_delta;
    uint32_t route_word;
    uint32_t event_first_word;
    uint32_t original_word;
    uint32_t stub_first_word;
    uint32_t stub_restore_lr_word;
    uint32_t stub_mtctr_word;
    uint32_t stub_tail_word;
    struct region_snapshot before_region;
    struct region_snapshot candidate_region;
    struct region_snapshot final_region;
    char before_prot[4];
    char candidate_prot[4];
    char final_prot[4];
    long page_size_long;
    vm_size_t page_size;
    vm_address_t page_base;
    vm_prot_t write_protection;
    kern_return_t kr_enable_candidate = KERN_FAILURE;
    kern_return_t kr_lockdown_candidate = KERN_FAILURE;
    kern_return_t kr_enable_restore = KERN_FAILURE;
    kern_return_t kr_final_restore = KERN_FAILURE;
    unsigned int vm_protect_attempts = 0;
    unsigned int text_write_attempts = 0;
    unsigned int dcache_flush_attempts = 0;
    unsigned int icache_invalidate_attempts = 0;
    unsigned int warm_non_target_before = 0;
    unsigned int warm_target_before = 0;
    unsigned int warm_non_target_after = 0;
    unsigned int warm_target_after = 0;
    unsigned int warm_non_target_delta = 0;
    unsigned int warm_target_delta = 0;
    unsigned int non_target_before = 0;
    unsigned int target_before = 0;
    unsigned int non_target_after = 0;
    unsigned int target_after = 0;
    unsigned int target_delta = 0;
    Dl_info original_info;
    Dl_info stub_info;
    int original_result = 0;
    int stub_result = 0;
    int stub_result_match = 0;
    int stub_info_match = 0;
    int stub_warmup_complete = 0;
    unsigned char event[EVENT_SIZE];
    struct point32 output;
    float event_x = 123.5f;
    float event_y = 45.25f;
    uint16_t cache_before = 0;
    uint16_t cache_after = 0;
    event_unflip_fn event_fn;
    void *event_return = NULL;
    int candidate_installed = 0;
    int candidate_locked_down = 0;
    int event_called = 0;
    int original_restored = 0;
    int final_protection_match = 0;
    int output_x_match = 0;
    int output_y_match = 0;
    int event_return_match = 0;
    int success = 0;

    (void)force_coregraphics_dependency;

    printf("== PPC Carbon GUI event-unflip dladdr patched-route execution preflight ==\n");
    printf("probe_contract=%s\n", PROBE_CONTRACT);
    printf("candidate_route=EXISTING_DLADDR_PICSYMBOLSTUB1\n");
    printf("candidate_branch_word_expected=0x%08x\n", EXPECTED_ROUTE_WORD);
    printf("functional_source_helper_load_attempts=0\n");
    printf("original_gui_launch_count=0\n");
    printf("window_interaction_attempts=0\n");

    if (sizeof(void *) != 4) {
        printf("pointer_size=%lu\n", (unsigned long)sizeof(void *));
        goto done;
    }
    printf("pointer_size=4\n");

    if (uname(&uts) != 0) {
        printf("uname=FAIL\n");
        goto done;
    }
    printf("darwin_release=%s\n", uts.release);
    mode = getenv(MODE_ENV);
    printf("guard_mode=%s\n", mode ? mode : "UNSET");
    if (strncmp(uts.release, "10.", 3) == 0 && mode && strcmp(mode, MODE_SNOW) == 0)
        printf("preflight_mode=snow-ppc-control\n");
    else if (strncmp(uts.release, "11.", 3) == 0 && mode && strcmp(mode, MODE_LION) == 0)
        printf("preflight_mode=lion-ppc-translated\n");
    else {
        printf("preflight_mode=unsupported-or-mode-mismatch\n");
        goto done;
    }

    get_target = (target_return_fn)dlsym(
        RTLD_DEFAULT, "rosetta_event_unflip_dladdr_guard_target_return");
    call_original = (original_dladdr_fn)dlsym(
        RTLD_DEFAULT, "rosetta_event_unflip_dladdr_guard_call_original");
    get_counts = (counts_fn)dlsym(
        RTLD_DEFAULT, "rosetta_event_unflip_dladdr_guard_get_counts");
    get_leaf_contract = (leaf_contract_fn)dlsym(
        RTLD_DEFAULT, "rosetta_event_unflip_dladdr_guard_target_leaf_contract");
    leaf_contract_ok = get_leaf_contract ? get_leaf_contract() : 0;
    printf("guard_target_helper_dlsym=%s\n", get_target ? "PASS" : "FAIL");
    printf("original_replacee_helper_dlsym=%s\n", call_original ? "PASS" : "FAIL");
    printf("guard_counts_helper_dlsym=%s\n", get_counts ? "PASS" : "FAIL");
    printf("guard_target_leaf_contract_dlsym=%s\n",
           get_leaf_contract ? "PASS" : "FAIL");
    printf("guard_target_leaf_contract=%s\n",
           leaf_contract_ok == 1 ? "PASS" : "FAIL");
    if (!get_target || !call_original || !get_counts ||
        !get_leaf_contract || leaf_contract_ok != 1)
        goto done;

    main_runtime = (uintptr_t)dlsym(RTLD_DEFAULT, "CGSMainDisplayID");
    if (main_runtime == 0) {
        printf("CGSMainDisplayID_dlsym=FAIL\n");
        goto done;
    }
    printf("CGSMainDisplayID_dlsym=PASS\n");

    event_runtime = main_runtime + EVENT_DELTA_FROM_MAIN;
    callsite_runtime = main_runtime + CALLSITE_DELTA_FROM_MAIN;
    target_return_runtime = main_runtime + TARGET_RETURN_DELTA_FROM_MAIN;
    stub_runtime = main_runtime + DLADDR_STUB_DELTA_FROM_MAIN;
    guard_target_runtime = get_target();
    selected_stub = (dladdr_fn)(uintptr_t)stub_runtime;
    event_fn = (event_unflip_fn)(uintptr_t)event_runtime;

    printf("CGSMainDisplayID_runtime=0x%08lx\n", (unsigned long)main_runtime);
    printf("event_unflip_runtime=0x%08lx\n", (unsigned long)event_runtime);
    printf("bounds_callsite_runtime=0x%08lx\n", (unsigned long)callsite_runtime);
    printf("target_return_runtime=0x%08lx\n", (unsigned long)target_return_runtime);
    printf("guard_target_return_runtime=0x%08lx\n", (unsigned long)guard_target_runtime);
    printf("target_return_matches_callsite_plus4=%s\n",
           guard_target_runtime == target_return_runtime ? "YES" : "NO");
    printf("selected_dladdr_stub_runtime=0x%08lx\n", (unsigned long)stub_runtime);
    if (guard_target_runtime != target_return_runtime)
        goto done;

    route_delta = (int64_t)(uint64_t)stub_runtime -
                  (int64_t)(uint64_t)callsite_runtime;
    route_word = encode_relative_bl(route_delta);
    printf("candidate_branch_delta=%lld\n", (long long)route_delta);
    printf("candidate_branch_delta_expected=%lld\n", (long long)EXPECTED_ROUTE_DELTA);
    printf("candidate_branch_reachable=%s\n",
           branch_disp_fits(route_delta) ? "YES" : "NO");
    printf("candidate_branch_word=0x%08x\n", route_word);
    if (!branch_disp_fits(route_delta) ||
        route_delta != EXPECTED_ROUTE_DELTA ||
        route_word != EXPECTED_ROUTE_WORD)
        goto done;

    event_first_word = read_u32((const void *)event_runtime);
    original_word = read_u32((const void *)callsite_runtime);
    stub_first_word = read_u32((const void *)stub_runtime);
    stub_restore_lr_word = read_u32((const void *)(stub_runtime + 0x10));
    stub_mtctr_word = read_u32((const void *)(stub_runtime + 0x18));
    stub_tail_word = read_u32((const void *)(stub_runtime + 0x1c));
    printf("event_unflip_first_word=0x%08x\n", event_first_word);
    printf("event_unflip_prologue_match=%s\n",
           event_first_word == EXPECTED_PROLOGUE ? "YES" : "NO");
    printf("bounds_call_original_word=0x%08x\n", original_word);
    printf("bounds_call_original_word_match=%s\n",
           original_word == EXPECTED_CALL_WORD ? "YES" : "NO");
    printf("selected_dladdr_stub_runtime_shape_match=%s\n",
           (stub_first_word == 0x7c0802a6U &&
            stub_restore_lr_word == 0x7c0803a6U &&
            stub_mtctr_word == 0x7d8903a6U &&
            stub_tail_word == 0x4e800420U) ? "YES" : "NO");
    if (event_first_word != EXPECTED_PROLOGUE ||
        original_word != EXPECTED_CALL_WORD ||
        stub_first_word != 0x7c0802a6U ||
        stub_restore_lr_word != 0x7c0803a6U ||
        stub_mtctr_word != 0x7d8903a6U ||
        stub_tail_word != 0x4e800420U)
        goto done;

    /*
     * Bind the selected lazy CoreGraphics _dladdr stub once in this process
     * before the event function carries live f30/f31 values across the
     * patched callsite.  The earlier guard preflight proved this direct call
     * in a different process; that binding state does not carry over here.
     */
    memset(&original_info, 0, sizeof(original_info));
    memset(&stub_info, 0, sizeof(stub_info));
    original_result = call_original((const void *)(uintptr_t)&main,
                                    &original_info);
    get_counts(&warm_non_target_before, &warm_target_before);
    stub_result = selected_stub((const void *)(uintptr_t)&main, &stub_info);
    get_counts(&warm_non_target_after, &warm_target_after);
    warm_non_target_delta = warm_non_target_after - warm_non_target_before;
    warm_target_delta = warm_target_after - warm_target_before;
    stub_result_match = (original_result == stub_result);
    stub_info_match = stub_result_match &&
        original_info.dli_fbase == stub_info.dli_fbase &&
        original_info.dli_saddr == stub_info.dli_saddr &&
        nullable_string_equal(original_info.dli_fname, stub_info.dli_fname) &&
        nullable_string_equal(original_info.dli_sname, stub_info.dli_sname);
    stub_warmup_complete =
        original_result != 0 &&
        stub_result != 0 &&
        stub_result_match &&
        stub_info_match &&
        warm_non_target_delta == 1 &&
        warm_target_delta == 0;

    printf("selected_stub_warmup_original_result=%d\n", original_result);
    printf("selected_stub_warmup_result=%d\n", stub_result);
    printf("selected_stub_warmup_result_match=%s\n",
           stub_result_match ? "YES" : "NO");
    printf("selected_stub_warmup_info_match=%s\n",
           stub_info_match ? "YES" : "NO");
    printf("selected_stub_warmup_non_target_delta=%u\n",
           warm_non_target_delta);
    printf("selected_stub_warmup_target_delta=%u\n", warm_target_delta);
    printf("selected_dladdr_stub_direct_probe_calls=1\n");
    printf("selected_stub_warmup_complete=%s\n",
           stub_warmup_complete ? "YES" : "NO");
    if (!stub_warmup_complete)
        goto done;

    if (!query_region(callsite_runtime, &before_region)) {
        printf("callsite_region_resolved=NO\n");
        goto done;
    }
    printf("callsite_region_resolved=YES\n");
    prot_string(before_region.protection, before_prot);
    printf("callsite_region_protection_before=%s\n", before_prot);
    printf("callsite_region_max_write=%s\n",
           (before_region.max_protection & VM_PROT_WRITE) ? "YES" : "NO");
    if ((before_region.max_protection & VM_PROT_WRITE) == 0)
        goto done;

    page_size_long = sysconf(_SC_PAGESIZE);
    if (page_size_long <= 0)
        goto done;
    page_size = (vm_size_t)page_size_long;
    page_base = (vm_address_t)(callsite_runtime &
                ~((uintptr_t)page_size - (uintptr_t)1));
    write_protection = before_region.protection | VM_PROT_WRITE;
    printf("page_size=0x%lx\n", (unsigned long)page_size);
    printf("callsite_page_base=0x%08lx\n", (unsigned long)page_base);

    memset(event, 0, sizeof(event));
    memset(&output, 0xa5, sizeof(output));
    memcpy(event + EVENT_X_OFFSET, &event_x, sizeof(event_x));
    memcpy(event + EVENT_Y_OFFSET, &event_y, sizeof(event_y));
    memcpy(&cache_before, event + EVENT_CACHE_OFFSET, sizeof(cache_before));
    printf("synthetic_event_cache_before=%u\n", (unsigned int)cache_before);
    if (cache_before != 0)
        goto done;

    get_counts(&non_target_before, &target_before);
    printf("interposer_non_target_forward_count_before=%u\n", non_target_before);
    printf("interposer_target_wrapper_count_before=%u\n", target_before);
    if (target_before != 0)
        goto done;

    ++vm_protect_attempts;
    kr_enable_candidate = vm_protect(mach_task_self(), page_base, page_size,
                                     FALSE, write_protection);
    printf("vm_protect_enable_candidate_kr=%d\n", kr_enable_candidate);
    if (kr_enable_candidate != KERN_SUCCESS)
        goto done;

    ++text_write_attempts;
    write_u32((void *)callsite_runtime, route_word);
    candidate_installed = 1;
    ++dcache_flush_attempts;
    ++icache_invalidate_attempts;
    flush_code_word((void *)callsite_runtime);
    printf("candidate_install_readback=0x%08x\n",
           read_u32((const void *)callsite_runtime));
    printf("candidate_install_readback_match=%s\n",
           read_u32((const void *)callsite_runtime) == route_word ? "YES" : "NO");
    if (read_u32((const void *)callsite_runtime) != route_word)
        goto cleanup;

    ++vm_protect_attempts;
    kr_lockdown_candidate = vm_protect(mach_task_self(), page_base, page_size,
                                       FALSE, before_region.protection);
    printf("vm_protect_candidate_lockdown_kr=%d\n", kr_lockdown_candidate);
    if (kr_lockdown_candidate != KERN_SUCCESS)
        goto cleanup;
    candidate_locked_down = 1;

    if (!query_region(callsite_runtime, &candidate_region)) {
        printf("candidate_region_resolved=NO\n");
        goto cleanup;
    }
    printf("candidate_region_resolved=YES\n");
    prot_string(candidate_region.protection, candidate_prot);
    printf("candidate_execution_protection=%s\n", candidate_prot);
    printf("candidate_execution_protection_match=%s\n",
           candidate_region.protection == before_region.protection ? "YES" : "NO");
    if (candidate_region.protection != before_region.protection)
        goto cleanup;

    printf("candidate_instruction_execution_attempts=1\n");
    event_return = event_fn(&output, event);
    event_called = 1;

cleanup:
    if (candidate_installed) {
        ++vm_protect_attempts;
        kr_enable_restore = vm_protect(mach_task_self(), page_base, page_size,
                                       FALSE, write_protection);
        printf("vm_protect_enable_restore_kr=%d\n", kr_enable_restore);
        if (kr_enable_restore == KERN_SUCCESS) {
            ++text_write_attempts;
            write_u32((void *)callsite_runtime, EXPECTED_CALL_WORD);
            ++dcache_flush_attempts;
            ++icache_invalidate_attempts;
            flush_code_word((void *)callsite_runtime);
            original_restored =
                read_u32((const void *)callsite_runtime) == EXPECTED_CALL_WORD;
            printf("original_restore_readback=0x%08x\n",
                   read_u32((const void *)callsite_runtime));
            printf("original_restore_readback_match=%s\n",
                   original_restored ? "YES" : "NO");

            ++vm_protect_attempts;
            kr_final_restore = vm_protect(mach_task_self(), page_base, page_size,
                                          FALSE, before_region.protection);
            printf("vm_protect_final_restore_kr=%d\n", kr_final_restore);
        }
    }

    if (query_region(callsite_runtime, &final_region)) {
        prot_string(final_region.protection, final_prot);
        printf("callsite_region_protection_after=%s\n", final_prot);
        final_protection_match =
            final_region.protection == before_region.protection;
        printf("final_protection_match=%s\n",
               final_protection_match ? "YES" : "NO");
    } else {
        printf("final_region_resolved=NO\n");
    }
    printf("bounds_call_final_word=0x%08x\n",
           read_u32((const void *)callsite_runtime));
    printf("loaded_callsite_bytes_restored=%s\n",
           read_u32((const void *)callsite_runtime) == EXPECTED_CALL_WORD ? "YES" : "NO");

    if (event_called) {
        get_counts(&non_target_after, &target_after);
        target_delta = target_after - target_before;
        memcpy(&cache_after, event + EVENT_CACHE_OFFSET, sizeof(cache_after));
        output_x_match = memcmp(&output.x, &event_x, sizeof(event_x)) == 0;
        output_y_match = memcmp(&output.y, &event_y, sizeof(event_y)) == 0;
        event_return_match = event_return == (void *)&output;
        printf("event_input_x_bits=0x%08x\n", read_u32(&event_x));
        printf("event_output_x_bits=0x%08x\n", read_u32(&output.x));
        printf("event_input_y_bits=0x%08x\n", read_u32(&event_y));
        printf("event_output_y_bits=0x%08x\n", read_u32(&output.y));
        printf("interposer_non_target_forward_count_after=%u\n", non_target_after);
        printf("interposer_target_wrapper_count=%u\n", target_after);
        printf("patched_route_target_wrapper_delta=%u\n", target_delta);
        printf("event_return_matches_output=%s\n",
               event_return_match ? "YES" : "NO");
        printf("event_output_x_preserved=%s\n",
               output_x_match ? "YES" : "NO");
        printf("event_output_y_preserved=%s\n",
               output_y_match ? "YES" : "NO");
        printf("synthetic_event_cache_after=%u\n", (unsigned int)cache_after);
        printf("event_cache_extent_unchanged_zero=%s\n",
               cache_after == 0 ? "YES" : "NO");
        printf("patched_target_wrapper_executed=%s\n",
               target_delta == 1 ? "YES" : "NO");
        printf("failclosed_event_path_preserved=%s\n",
               (event_return_match && output_x_match && output_y_match &&
                cache_after == 0) ? "YES" : "NO");
    } else {
        printf("patched_target_wrapper_executed=NO\n");
        printf("failclosed_event_path_preserved=NO\n");
    }

    if (stub_warmup_complete &&
        event_called && candidate_locked_down &&
        target_delta == 1 && event_return_match &&
        output_x_match && output_y_match && cache_after == 0 &&
        original_restored && kr_final_restore == KERN_SUCCESS &&
        final_protection_match &&
        read_u32((const void *)callsite_runtime) == EXPECTED_CALL_WORD)
        success = 1;

done:
    printf("vm_protect_attempts=%u\n", vm_protect_attempts);
    printf("coregraphics_text_write_attempts=%u\n", text_write_attempts);
    printf("dcache_flush_attempts=%u\n", dcache_flush_attempts);
    printf("icache_invalidate_attempts=%u\n", icache_invalidate_attempts);
    printf("synthetic_event_unflip_calls=%d\n", event_called ? 1 : 0);
    printf("functional_source_helper_executed=NO\n");
    printf("preflight_complete=%s\n", success ? "YES" : "NO");
    if (success) {
        printf("RESULT: PASS\n");
        return 0;
    }
    printf("RESULT: FAIL\n");
    return 1;
}
