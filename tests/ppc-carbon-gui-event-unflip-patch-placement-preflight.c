/*
 * Passive PPC runtime placement preflight for the event-unflip repair.
 *
 * This probe does not patch CoreGraphics, does not change page protections,
 * does not allocate executable memory, and does not call private CoreGraphics.
 * It resolves the already-audited Snow PPC callsite from loaded
 * CGSMainDisplayID, verifies the original branch word, measures a separately
 * loaded inert marker function, and inventories unmapped pages within PPC
 * relative-branch range.
 */

#include <ApplicationServices/ApplicationServices.h>
#include <dlfcn.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/utsname.h>
#include <unistd.h>

#if !defined(__ppc__)
#error This preflight is intentionally PowerPC-only.
#endif

#define PREFLIGHT_CONTRACT "carbon-gui-event-unflip-patch-placement-preflight-v1"
#define EXPECTED_MAIN_PROLOGUE 0x7c0802a6U
#define EXPECTED_BOUNDS_CALL_WORD 0x4bff702dU
#define EVENT_DELTA_FROM_MAIN 0x00003fac
#define BOUNDS_CALL_DELTA_FROM_MAIN 0x00003ff0
#define BOUNDS_TARGET_DELTA_FROM_MAIN (-0x00004fe4)
#define BRANCH_MIN_DISP (-0x02000000LL)
#define BRANCH_MAX_DISP ( 0x01fffffcLL)
#define MARKER_SYMBOL "rosetta_event_unflip_placement_marker"

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

static uint32_t
read_native_u32(const void *p)
{
    uint32_t v;
    memcpy(&v, p, sizeof(v));
    return v;
}

static uintptr_t
add_signed(uintptr_t base, int32_t delta)
{
    return (uintptr_t)((intptr_t)base + (intptr_t)delta);
}

static int
query_region(uintptr_t target, struct region_snapshot *out)
{
    vm_address_t address;
    vm_size_t size;
    vm_region_basic_info_data_t info;
    mach_msg_type_number_t count;
    mach_port_t object_name;
    kern_return_t kr;
    uint64_t end;

    address = (vm_address_t)target;
    size = 0;
    count = VM_REGION_BASIC_INFO_COUNT;
    object_name = MACH_PORT_NULL;

    kr = vm_region(mach_task_self(),
                   &address,
                   &size,
                   VM_REGION_BASIC_INFO,
                   (vm_region_info_t)&info,
                   &count,
                   &object_name);
    if (kr != KERN_SUCCESS) {
        return 0;
    }

    end = (uint64_t)address + (uint64_t)size;
    if ((uint64_t)target < (uint64_t)address ||
        (uint64_t)target >= end) {
        if (object_name != MACH_PORT_NULL) {
            mach_port_deallocate(mach_task_self(), object_name);
        }
        return 0;
    }

    out->base = address;
    out->size = size;
    out->protection = info.protection;
    out->max_protection = info.max_protection;
    out->shared = info.shared;
    out->reserved = info.reserved;

    if (object_name != MACH_PORT_NULL) {
        mach_port_deallocate(mach_task_self(), object_name);
    }
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
    return (delta >= BRANCH_MIN_DISP &&
            delta <= BRANCH_MAX_DISP &&
            (delta & 3LL) == 0);
}

static uint32_t
encode_relative_bl(int64_t delta)
{
    return 0x48000001U | ((uint32_t)delta & 0x03fffffcU);
}

static uintptr_t
decode_relative_branch_target(uintptr_t site, uint32_t word, int *ok_out)
{
    uint32_t li;
    int32_t disp;

    *ok_out = 0;
    if ((word >> 26) != 18U || (word & 2U) != 0U || (word & 1U) == 0U) {
        return 0;
    }

    li = word & 0x03fffffcU;
    disp = (int32_t)li;
    if ((li & 0x02000000U) != 0U) {
        disp |= (int32_t)0xfc000000U;
    }
    *ok_out = 1;
    return add_signed(site, disp);
}

static uintptr_t
align_up_uintptr(uintptr_t value, uintptr_t align)
{
    uintptr_t mask;
    mask = align - 1;
    return (value + mask) & ~mask;
}

static int
find_unmapped_page_near(uintptr_t site,
                        vm_size_t page_size,
                        uintptr_t *candidate_out,
                        int64_t *delta_out,
                        unsigned int *region_queries_out)
{
    uint64_t low64;
    uint64_t high64;
    uintptr_t cursor;
    uintptr_t high;
    unsigned int queries;

    low64 = site > 0x02000000U ? (uint64_t)site - 0x02000000ULL : 0x1000ULL;
    high64 = (uint64_t)site + 0x01fffffcULL;
    if (high64 > 0xfffff000ULL) {
        high64 = 0xfffff000ULL;
    }

    cursor = align_up_uintptr((uintptr_t)low64, (uintptr_t)page_size);
    high = (uintptr_t)high64;
    queries = 0;

    while ((uint64_t)cursor + (uint64_t)page_size <= (uint64_t)high &&
           queries < 4096U) {
        vm_address_t address;
        vm_size_t size;
        vm_region_basic_info_data_t info;
        mach_msg_type_number_t count;
        mach_port_t object_name;
        kern_return_t kr;
        uintptr_t gap_candidate;
        uint64_t region_end;

        address = (vm_address_t)cursor;
        size = 0;
        count = VM_REGION_BASIC_INFO_COUNT;
        object_name = MACH_PORT_NULL;
        kr = vm_region(mach_task_self(),
                       &address,
                       &size,
                       VM_REGION_BASIC_INFO,
                       (vm_region_info_t)&info,
                       &count,
                       &object_name);
        ++queries;

        if (kr != KERN_SUCCESS) {
            gap_candidate = align_up_uintptr(cursor, (uintptr_t)page_size);
            if ((uint64_t)gap_candidate + (uint64_t)page_size <= (uint64_t)high) {
                int64_t delta;
                delta = (int64_t)(uint64_t)gap_candidate -
                        (int64_t)(uint64_t)site;
                if (branch_disp_fits(delta)) {
                    *candidate_out = gap_candidate;
                    *delta_out = delta;
                    *region_queries_out = queries;
                    return 1;
                }
            }
            break;
        }

        if (object_name != MACH_PORT_NULL) {
            mach_port_deallocate(mach_task_self(), object_name);
        }

        if ((uintptr_t)address > cursor) {
            gap_candidate = align_up_uintptr(cursor, (uintptr_t)page_size);
            if ((uint64_t)gap_candidate + (uint64_t)page_size <=
                (uint64_t)(uintptr_t)address) {
                int64_t delta;
                delta = (int64_t)(uint64_t)gap_candidate -
                        (int64_t)(uint64_t)site;
                if (branch_disp_fits(delta)) {
                    *candidate_out = gap_candidate;
                    *delta_out = delta;
                    *region_queries_out = queries;
                    return 1;
                }
            }
        }

        region_end = (uint64_t)(uintptr_t)address + (uint64_t)size;
        if (region_end <= (uint64_t)cursor) {
            break;
        }
        if (region_end > 0xffffffffULL) {
            break;
        }
        cursor = align_up_uintptr((uintptr_t)region_end,
                                  (uintptr_t)page_size);
    }

    *region_queries_out = queries;
    return 0;
}

int
main(void)
{
    struct utsname uts;
    unsigned long darwin_major;
    void *main_symbol;
    void *marker_symbol;
    uintptr_t main_runtime;
    uintptr_t event_runtime;
    uintptr_t callsite_runtime;
    uintptr_t expected_bounds_runtime;
    uintptr_t decoded_bounds_runtime;
    uint32_t main_word;
    uint32_t call_word;
    int decode_ok;
    int call_word_match;
    int decoded_target_match;
    int marker_aligned;
    int64_t marker_delta;
    int marker_reachable;
    uint32_t marker_bl_word;
    struct region_snapshot call_region;
    struct region_snapshot marker_region;
    char call_prot[4];
    char call_max_prot[4];
    char marker_prot[4];
    long page_size_long;
    vm_size_t page_size;
    uintptr_t gap_candidate;
    int64_t gap_delta;
    unsigned int region_queries;
    int gap_present;
    int mode_ok;
    uint32_t call_word_after;
    int bytes_unchanged;

    (void)force_coregraphics_dependency;

    printf("== PPC Carbon GUI event-unflip patch placement preflight ==\n");
    printf("preflight_contract=%s\n", PREFLIGHT_CONTRACT);
    printf("coregraphics_text_write_attempts=0\n");
    printf("vm_protect_attempts=0\n");
    printf("vm_allocate_attempts=0\n");
    printf("temporary_executable_mapping_attempts=0\n");
    printf("private_coregraphics_call_count=0\n");
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
    darwin_major = strtoul(uts.release, 0, 10);
    printf("darwin_release=%s\n", uts.release);
    mode_ok = 0;
    if (darwin_major == 10) {
        printf("preflight_mode=snow-ppc-control\n");
        mode_ok = 1;
    } else if (darwin_major == 11) {
        printf("preflight_mode=lion-ppc-translated\n");
        mode_ok = 1;
    } else {
        printf("preflight_mode=unsupported\n");
    }
    if (!mode_ok) {
        printf("RESULT: FAIL\n");
        return 4;
    }

    main_symbol = dlsym(RTLD_DEFAULT, "CGSMainDisplayID");
    marker_symbol = dlsym(RTLD_DEFAULT, MARKER_SYMBOL);
    if (main_symbol == 0 || marker_symbol == 0) {
        printf("CGSMainDisplayID_dlsym=%s\n", main_symbol ? "PASS" : "FAIL");
        printf("placement_marker_dlsym=%s\n", marker_symbol ? "PASS" : "FAIL");
        printf("RESULT: FAIL\n");
        return 5;
    }
    printf("CGSMainDisplayID_dlsym=PASS\n");
    printf("placement_marker_dlsym=PASS\n");

    main_runtime = (uintptr_t)main_symbol;
    event_runtime = main_runtime + EVENT_DELTA_FROM_MAIN;
    callsite_runtime = main_runtime + BOUNDS_CALL_DELTA_FROM_MAIN;
    expected_bounds_runtime = add_signed(main_runtime,
                                         BOUNDS_TARGET_DELTA_FROM_MAIN);

    printf("CGSMainDisplayID_runtime=0x%08lx\n", (unsigned long)main_runtime);
    printf("event_unflip_runtime=0x%08lx\n", (unsigned long)event_runtime);
    printf("bounds_callsite_runtime=0x%08lx\n",
           (unsigned long)callsite_runtime);
    printf("expected_bounds_runtime=0x%08lx\n",
           (unsigned long)expected_bounds_runtime);
    printf("placement_marker_runtime=0x%08lx\n",
           (unsigned long)(uintptr_t)marker_symbol);

    if (!query_region(callsite_runtime, &call_region) ||
        !query_region((uintptr_t)marker_symbol, &marker_region)) {
        printf("runtime_regions_resolved=NO\n");
        printf("RESULT: FAIL\n");
        return 6;
    }
    printf("runtime_regions_resolved=YES\n");

    if ((call_region.protection & VM_PROT_READ) == 0) {
        printf("callsite_region_readable=NO\n");
        printf("RESULT: FAIL\n");
        return 7;
    }
    printf("callsite_region_readable=YES\n");

    main_word = read_native_u32((const void *)main_runtime);
    call_word = read_native_u32((const void *)callsite_runtime);
    printf("main_runtime_first_word=0x%08x\n", (unsigned int)main_word);
    printf("main_prologue_match=%s\n",
           main_word == EXPECTED_MAIN_PROLOGUE ? "YES" : "NO");
    printf("bounds_call_runtime_word=0x%08x\n", (unsigned int)call_word);
    printf("bounds_call_expected_word=0x%08x\n",
           (unsigned int)EXPECTED_BOUNDS_CALL_WORD);

    call_word_match = call_word == EXPECTED_BOUNDS_CALL_WORD;
    printf("bounds_call_runtime_word_match=%s\n",
           call_word_match ? "YES" : "NO");

    decoded_bounds_runtime =
        decode_relative_branch_target(callsite_runtime, call_word, &decode_ok);
    printf("bounds_call_decode_ok=%s\n", decode_ok ? "YES" : "NO");
    printf("decoded_bounds_runtime=0x%08lx\n",
           (unsigned long)decoded_bounds_runtime);
    decoded_target_match =
        decode_ok && decoded_bounds_runtime == expected_bounds_runtime;
    printf("decoded_bounds_target_match=%s\n",
           decoded_target_match ? "YES" : "NO");

    prot_string(call_region.protection, call_prot);
    prot_string(call_region.max_protection, call_max_prot);
    prot_string(marker_region.protection, marker_prot);
    printf("callsite_region_base=0x%08lx\n",
           (unsigned long)call_region.base);
    printf("callsite_region_size=0x%08lx\n",
           (unsigned long)call_region.size);
    printf("callsite_region_protection=%s\n", call_prot);
    printf("callsite_region_max_protection=%s\n", call_max_prot);
    printf("callsite_region_current_write=%s\n",
           (call_region.protection & VM_PROT_WRITE) ? "YES" : "NO");
    printf("callsite_region_max_write=%s\n",
           (call_region.max_protection & VM_PROT_WRITE) ? "YES" : "NO");
    printf("callsite_region_shared=%d\n", call_region.shared);
    printf("callsite_region_reserved=%d\n", call_region.reserved);
    printf("marker_region_protection=%s\n", marker_prot);

    marker_delta = (int64_t)(uint64_t)(uintptr_t)marker_symbol -
                   (int64_t)(uint64_t)callsite_runtime;
    marker_aligned = (((uintptr_t)marker_symbol & 3U) == 0U);
    marker_reachable = marker_aligned && branch_disp_fits(marker_delta);
    printf("placement_marker_aligned=%s\n", marker_aligned ? "YES" : "NO");
    printf("placement_marker_branch_delta=%lld\n", (long long)marker_delta);
    printf("direct_marker_branch_reachable=%s\n",
           marker_reachable ? "YES" : "NO");
    if (marker_reachable) {
        marker_bl_word = encode_relative_bl(marker_delta);
        printf("candidate_direct_marker_bl_word=0x%08x\n",
               (unsigned int)marker_bl_word);
    } else {
        printf("candidate_direct_marker_bl_word=UNAVAILABLE\n");
    }

    page_size_long = getpagesize();
    if (page_size_long <= 0) {
        printf("page_size=INVALID\n");
        printf("RESULT: FAIL\n");
        return 8;
    }
    page_size = (vm_size_t)page_size_long;
    printf("page_size=0x%lx\n", (unsigned long)page_size);

    gap_candidate = 0;
    gap_delta = 0;
    region_queries = 0;
    gap_present = find_unmapped_page_near(callsite_runtime,
                                          page_size,
                                          &gap_candidate,
                                          &gap_delta,
                                          &region_queries);
    printf("branch_range_region_query_count=%u\n", region_queries);
    printf("near_unmapped_page_candidate=%s\n",
           gap_present ? "YES" : "NO");
    if (gap_present) {
        printf("near_unmapped_page_address=0x%08lx\n",
               (unsigned long)gap_candidate);
        printf("near_unmapped_page_branch_delta=%lld\n",
               (long long)gap_delta);
        printf("near_unmapped_page_branch_reachable=%s\n",
               branch_disp_fits(gap_delta) ? "YES" : "NO");
    }

    if (marker_reachable) {
        printf("placement_route=DIRECT_MARKER_DYLIB\n");
    } else if (gap_present) {
        printf("placement_route=UNMAPPED_NEAR_PAGE_CANDIDATE\n");
    } else {
        printf("placement_route=NONE_OBSERVED\n");
    }

    printf("runtime_text_writability_tested=NO\n");
    printf("near_page_allocation_tested=NO\n");
    call_word_after = read_native_u32((const void *)callsite_runtime);
    bytes_unchanged = (call_word_after == call_word);
    printf("bounds_call_runtime_word_after=0x%08x\n",
           (unsigned int)call_word_after);
    printf("loaded_callsite_bytes_unchanged=%s\n",
           bytes_unchanged ? "YES" : "NO");

    if (main_word != EXPECTED_MAIN_PROLOGUE ||
        !call_word_match ||
        !decoded_target_match ||
        !bytes_unchanged) {
        printf("preflight_complete=NO\n");
        printf("RESULT: FAIL\n");
        return 9;
    }

    printf("preflight_complete=YES\n");
    printf("RESULT: PASS\n");
    return 0;
}
