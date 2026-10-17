/*
 * Proof-only process-local display-record projection for the Rosetta
 * CGSMainDisplayID investigation.
 *
 * Snow PPC: validate that the release-pinned private lock/update/lookup/unlock
 * sequence reproduces the public main-display ID with zero writes.
 *
 * Lion translated PPC: after the normal update path has returned under the
 * display lock, redirect exactly one process-local local-mapping record pointer
 * to a stack-owned record view.  Only the already-proven Snow/Lion semantic
 * window record[0xf4..0x113] <- lion_record[0x110..0x12f] is shifted.  Call
 * _lookupMainDisplay(1), restore the pointer immediately, then unlock.
 *
 * The proof never writes server-owned display shared memory and never leaves
 * the private record pointer installed across update/rebind or unlock.
 */

#include <ApplicationServices/ApplicationServices.h>
#include <dlfcn.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/utsname.h>

#if !defined(__ppc__) && !defined(__i386__)
#error This diagnostic is intentionally limited to 32-bit PPC and i386.
#endif

#define PROOF_CONTRACT "carbon-gui-display-shmem-projection-proof-v1"

typedef uint32_t (*CGSMainDisplayIDFunction)(void);
typedef void (*VoidFunction)(void);
typedef int (*UpdateFunction)(void);
typedef void *(*LookupMainFunction)(int);

static CGDirectDisplayID (*volatile force_coregraphics_dependency)(void) =
    CGMainDisplayID;

static uint32_t
read_le32(const unsigned char *p)
{
    return ((uint32_t)p[0]) |
           ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) |
           ((uint32_t)p[3] << 24);
}

static uint32_t
read_native_u32(const void *p)
{
    uint32_t v;
    memcpy(&v, p, sizeof(v));
    return v;
}

static uint32_t
fnv1a32(const unsigned char *p, size_t n)
{
    uint32_t h;
    size_t i;

    h = 2166136261U;
    for (i = 0; i < n; ++i) {
        h ^= (uint32_t)p[i];
        h *= 16777619U;
    }
    return h;
}

static int
range_has_protection(const void *ptr, size_t length, vm_prot_t need)
{
    vm_address_t target;
    vm_address_t address;
    vm_size_t size;
    vm_region_basic_info_data_t info;
    mach_msg_type_number_t count;
    mach_port_t object_name;
    kern_return_t kr;
    unsigned long long target_end;
    unsigned long long region_end;
    int ok;

    target = (vm_address_t)(uintptr_t)ptr;
    address = target;
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

    target_end = (unsigned long long)target + (unsigned long long)length;
    region_end = (unsigned long long)address + (unsigned long long)size;
    ok = ((info.protection & need) == need) &&
         target >= address &&
         target_end >= (unsigned long long)target &&
         target_end <= region_end;

    if (object_name != MACH_PORT_NULL) {
        mach_port_deallocate(mach_task_self(), object_name);
    }

    return ok;
}

static int
find_segment_for_runtime_addr(const struct mach_header *mh,
                              uintptr_t target,
                              size_t length,
                              char segname_out[17])
{
    const unsigned char *p;
    uint32_t i;

    if (mh == 0 || mh->magic != MH_MAGIC) {
        return 0;
    }

    p = (const unsigned char *)(mh + 1);
    for (i = 0; i < mh->ncmds; ++i) {
        const struct load_command *lc;
        const struct segment_command *seg;
        uint64_t start;
        uint64_t end;
        uint64_t addr;
        uint64_t addr_end;

        lc = (const struct load_command *)p;
        if (lc->cmdsize < sizeof(struct load_command)) {
            return 0;
        }
        if (lc->cmd == LC_SEGMENT) {
            seg = (const struct segment_command *)p;
            start = (uint64_t)seg->vmaddr;
            end = start + (uint64_t)seg->vmsize;
            addr = (uint64_t)target;
            addr_end = addr + (uint64_t)length;
            if (addr >= start && addr_end >= addr && addr_end <= end) {
                if (segname_out != 0) {
                    memcpy(segname_out, seg->segname, 16);
                    segname_out[16] = '\0';
                }
                return 1;
            }
        }
        p += lc->cmdsize;
    }
    return 0;
}

static int
find_coregraphics_image(const struct mach_header **header_out,
                        const char **name_out,
                        uint32_t *match_count_out)
{
    uint32_t count;
    uint32_t i;
    uint32_t matches;
    const struct mach_header *found_header;
    const char *found_name;

    count = _dyld_image_count();
    matches = 0;
    found_header = 0;
    found_name = 0;

    for (i = 0; i < count; ++i) {
        const char *name;
        name = _dyld_get_image_name(i);
        if (name != 0 &&
            strstr(name,
                   "/CoreGraphics.framework/Versions/A/CoreGraphics") != 0) {
            ++matches;
            found_header = _dyld_get_image_header(i);
            found_name = name;
        }
    }

    *header_out = found_header;
    *name_out = found_name;
    *match_count_out = matches;
    return matches == 1 && found_header != 0;
}

#if defined(__ppc__)
static uintptr_t
add_delta(uintptr_t base, int32_t delta)
{
    return (uintptr_t)((intptr_t)base + (intptr_t)delta);
}
#endif

int
main(void)
{
    struct utsname uts;
    unsigned long darwin_major;
    void *symbol;
    CGSMainDisplayIDFunction public_main;
    uint32_t baseline_id;
    uint32_t after_id;

    (void)force_coregraphics_dependency;

    printf("== PPC Carbon GUI display-shmem projection proof ==\n");
    printf("proof_contract=%s\n", PROOF_CONTRACT);
    printf("server_owned_shared_record_write_attempts=0\n");
    printf("display_id_substitution_attempts=0\n");
    printf("display_id_normalization_attempts=0\n");

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

    symbol = dlsym(RTLD_DEFAULT, "CGSMainDisplayID");
    if (symbol == 0) {
        printf("CGSMainDisplayID_dlsym=FAIL\n");
        printf("RESULT: FAIL\n");
        return 4;
    }
    printf("CGSMainDisplayID_dlsym=PASS\n");
    printf("CGSMainDisplayID_runtime=%p\n", symbol);
    public_main = (CGSMainDisplayIDFunction)symbol;

#if defined(__i386__)
    if (darwin_major != 11) {
        printf("proof_mode=unsupported-i386\n");
        printf("RESULT: FAIL\n");
        return 5;
    }

    printf("proof_mode=lion-i386-native\n");
    baseline_id = public_main();
    printf("native_main_display_id=0x%08x\n", (unsigned int)baseline_id);
    printf("native_main_display_id_zero=%s\n",
           baseline_id == 0 ? "YES" : "NO");
    printf("process_local_pointer_write_count=0\n");
    printf("projection_applied=NO\n");
    printf("proof_complete=YES\n");
    if (baseline_id == 0) {
        printf("RESULT: FAIL\n");
        return 6;
    }
    printf("RESULT: PASS\n");
    return 0;
#else
    {
        const struct mach_header *cg_header;
        const char *cg_name;
        uint32_t cg_matches;
        uintptr_t main_runtime;
        uintptr_t lock_runtime;
        uintptr_t unlock_runtime;
        uintptr_t update_runtime;
        uintptr_t lookup_runtime;
        char main_seg[17];
        char lock_seg[17];
        char unlock_seg[17];
        char update_seg[17];
        char lookup_seg[17];
        const unsigned char *lookup_code;
        int64_t lookup_pic_base;
        uint32_t lookup_prologue_word;
        uint32_t selector_addis_word;
        uint32_t selector_low_word;
        uint32_t source_addis_word;
        uint32_t source_low_word;
        uint32_t local_addis_word;
        uint32_t local_low_word;
        uintptr_t selector_runtime;
        uintptr_t source_array_runtime;
        uintptr_t local_array_runtime;
        void * volatile *selector_slot;
        void * volatile *source_slots;
        void * volatile *local_slots;
        VoidFunction lock_display;
        VoidFunction unlock_display;
        UpdateFunction update_display;
        LookupMainFunction lookup_main;
        int locked;
        int rc;

        cg_header = 0;
        cg_name = 0;
        cg_matches = 0;
        locked = 0;
        rc = 0;

        if (darwin_major == 10) {
            printf("proof_mode=snow-ppc-control\n");
        } else if (darwin_major == 11) {
            printf("proof_mode=lion-ppc-translated\n");
        } else {
            printf("proof_mode=unsupported-ppc\n");
            printf("RESULT: FAIL\n");
            return 5;
        }

        if (!find_coregraphics_image(&cg_header, &cg_name, &cg_matches)) {
            printf("coregraphics_image_match_count=%u\n",
                   (unsigned int)cg_matches);
            printf("RESULT: FAIL\n");
            return 6;
        }
        printf("coregraphics_image_match_count=1\n");
        printf("coregraphics_image=%s\n", cg_name);

        main_runtime = (uintptr_t)symbol;
        lock_runtime = add_delta(main_runtime, -31384);
        unlock_runtime = add_delta(main_runtime, -29616);
        update_runtime = add_delta(main_runtime, -18576);
        lookup_runtime = add_delta(main_runtime, -22616);

        if (!find_segment_for_runtime_addr(cg_header, main_runtime, 4, main_seg) ||
            !find_segment_for_runtime_addr(cg_header, lock_runtime, 4, lock_seg) ||
            !find_segment_for_runtime_addr(cg_header, unlock_runtime, 4, unlock_seg) ||
            !find_segment_for_runtime_addr(cg_header, update_runtime, 4, update_seg) ||
            !find_segment_for_runtime_addr(cg_header, lookup_runtime, 4, lookup_seg)) {
            printf("helper_targets_in_segments=NO\n");
            printf("RESULT: FAIL\n");
            return 7;
        }

        printf("helper_targets_in_segments=YES\n");
        printf("lock_runtime=0x%08lx segment=%s\n",
               (unsigned long)lock_runtime, lock_seg);
        printf("unlock_runtime=0x%08lx segment=%s\n",
               (unsigned long)unlock_runtime, unlock_seg);
        printf("update_runtime=0x%08lx segment=%s\n",
               (unsigned long)update_runtime, update_seg);
        printf("lookup_runtime=0x%08lx segment=%s\n",
               (unsigned long)lookup_runtime, lookup_seg);

        if (strcmp(main_seg, "__TEXT") != 0 ||
            strcmp(lock_seg, "__TEXT") != 0 ||
            strcmp(unlock_seg, "__TEXT") != 0 ||
            strcmp(update_seg, "__TEXT") != 0 ||
            strcmp(lookup_seg, "__TEXT") != 0 ||
            read_native_u32((const void *)lock_runtime) != 0x7c0802a6U ||
            read_native_u32((const void *)unlock_runtime) != 0x7c0802a6U ||
            read_native_u32((const void *)update_runtime) != 0x7c0802a6U ||
            read_native_u32((const void *)lookup_runtime) != 0x7c0802a6U) {
            printf("helper_address_validation=FAIL\n");
            printf("RESULT: FAIL\n");
            return 8;
        }

        lookup_code = (const unsigned char *)lookup_runtime;
        lookup_pic_base =
            (int64_t)(uint32_t)(uintptr_t)(lookup_code + 0x08);
        lookup_prologue_word = read_native_u32(lookup_code);
        selector_addis_word = read_native_u32(lookup_code + 0x1c);
        selector_low_word = read_native_u32(lookup_code + 0x20);
        source_addis_word = read_native_u32(lookup_code + 0x30);
        source_low_word = read_native_u32(lookup_code + 0x34);
        local_addis_word = read_native_u32(lookup_code + 0x4c);
        local_low_word = read_native_u32(lookup_code + 0x50);

        if (lookup_prologue_word != 0x7c0802a6U ||
            (selector_addis_word & 0xffff0000U) != 0x3fdf0000U ||
            (selector_low_word & 0xffff0000U) != 0x813e0000U ||
            (source_addis_word & 0xffff0000U) != 0x3c5f0000U ||
            (source_low_word & 0xffff0000U) != 0x39020000U ||
            (local_addis_word & 0xffff0000U) != 0x3c5f0000U ||
            (local_low_word & 0xffff0000U) != 0x38c20000U) {
            printf("lookup_pic_pattern=FAIL\n");
            printf("RESULT: FAIL\n");
            return 9;
        }

        selector_runtime =
            (uintptr_t)(lookup_pic_base +
                        (int64_t)(int16_t)(selector_addis_word & 0xffffU) * 65536LL +
                        (int64_t)(int16_t)(selector_low_word & 0xffffU));
        source_array_runtime =
            (uintptr_t)(lookup_pic_base +
                        (int64_t)(int16_t)(source_addis_word & 0xffffU) * 65536LL +
                        (int64_t)(int16_t)(source_low_word & 0xffffU));
        local_array_runtime =
            (uintptr_t)(lookup_pic_base +
                        (int64_t)(int16_t)(local_addis_word & 0xffffU) * 65536LL +
                        (int64_t)(int16_t)(local_low_word & 0xffffU));

        if (!find_segment_for_runtime_addr(cg_header, selector_runtime,
                                           sizeof(void *), 0) ||
            !find_segment_for_runtime_addr(cg_header, source_array_runtime,
                                           2 * sizeof(void *), 0) ||
            !find_segment_for_runtime_addr(cg_header, local_array_runtime,
                                           2 * sizeof(void *), 0)) {
            printf("runtime_globals_in_segments=NO\n");
            printf("RESULT: FAIL\n");
            return 10;
        }
        printf("runtime_globals_in_segments=YES\n");
        printf("helper_address_validation=PASS\n");

        selector_slot = (void * volatile *)selector_runtime;
        source_slots = (void * volatile *)source_array_runtime;
        local_slots = (void * volatile *)local_array_runtime;
        lock_display = (VoidFunction)lock_runtime;
        unlock_display = (VoidFunction)unlock_runtime;
        update_display = (UpdateFunction)update_runtime;
        lookup_main = (LookupMainFunction)lookup_runtime;

        baseline_id = public_main();
        printf("baseline_public_main_display_id=0x%08x\n",
               (unsigned int)baseline_id);
        printf("baseline_public_main_display_id_zero=%s\n",
               baseline_id == 0 ? "YES" : "NO");

        lock_display();
        locked = 1;
        (void)update_display();

        if (!range_has_protection((const void *)selector_slot,
                                  sizeof(void *), VM_PROT_READ) ||
            !range_has_protection((const void *)source_slots,
                                  2 * sizeof(void *), VM_PROT_READ) ||
            !range_has_protection((const void *)local_slots,
                                  2 * sizeof(void *), VM_PROT_READ)) {
            printf("selected_state_ready=NO\n");
            rc = 11;
            goto ppc_cleanup;
        }

        {
            void *selector_ptr;
            unsigned int selector_index;
            void *source;
            void *local;

            selector_ptr = *selector_slot;
            if (selector_ptr == 0 ||
                !range_has_protection(selector_ptr, 1, VM_PROT_READ)) {
                printf("selected_state_ready=NO\n");
                rc = 12;
                goto ppc_cleanup;
            }
            selector_index = (unsigned int)(*(volatile unsigned char *)selector_ptr);
            printf("selector_index=%u\n", selector_index);
            if (selector_index >= 2) {
                printf("selected_state_ready=NO\n");
                rc = 13;
                goto ppc_cleanup;
            }

            source = source_slots[selector_index];
            local = local_slots[selector_index];
            printf("selected_source=%p\n", source);
            printf("selected_local_mapping=%p\n", local);
            if (source == 0 || local == 0) {
                printf("selected_state_ready=NO\n");
                rc = 14;
                goto ppc_cleanup;
            }

            if (darwin_major == 10) {
                void *entry;
                void *record;
                uint32_t private_id;

                if (!range_has_protection(source, 0x20 + 0x150,
                                          VM_PROT_READ) ||
                    !range_has_protection(local, 0x58,
                                          VM_PROT_READ)) {
                    printf("selected_state_ready=NO\n");
                    rc = 15;
                    goto ppc_cleanup;
                }

                printf("selected_state_ready=YES\n");
                entry = lookup_main(1);
                if (entry == 0 ||
                    !range_has_protection(entry, sizeof(void *), VM_PROT_READ)) {
                    printf("private_lookup_nonnull=NO\n");
                    rc = 16;
                    goto ppc_cleanup;
                }
                record = *(void **)entry;
                if (record == 0 ||
                    !range_has_protection(record, 4, VM_PROT_READ)) {
                    printf("private_lookup_nonnull=NO\n");
                    rc = 17;
                    goto ppc_cleanup;
                }
                private_id = read_le32((const unsigned char *)record);
                printf("private_lookup_nonnull=YES\n");
                printf("private_lookup_display_id=0x%08x\n",
                       (unsigned int)private_id);
                printf("private_lookup_matches_public=%s\n",
                       private_id == baseline_id ? "YES" : "NO");
                printf("process_local_pointer_write_count=0\n");
                printf("projection_applied=NO\n");
                if (baseline_id == 0 || private_id != baseline_id) {
                    rc = 18;
                    goto ppc_cleanup;
                }
            } else {
                unsigned char projection[0x150];
                volatile void **record_slot;
                void *original_record;
                const unsigned char *lion_record;
                uint32_t count;
                uint32_t source_hash_before;
                uint32_t source_hash_after;
                uint32_t projected_id;
                void *lookup_entry;
                unsigned int pointer_writes;

                if (!range_has_protection(source, 0x20 + 0x17c,
                                          VM_PROT_READ) ||
                    !range_has_protection(local, 0x58,
                                          VM_PROT_READ | VM_PROT_WRITE)) {
                    printf("selected_state_ready=NO\n");
                    rc = 19;
                    goto ppc_cleanup;
                }

                count = read_le32((const unsigned char *)source);
                printf("record_count_le=%u\n", (unsigned int)count);
                printf("record_count_exactly_one=%s\n",
                       count == 1 ? "YES" : "NO");
                if (count != 1) {
                    rc = 20;
                    goto ppc_cleanup;
                }

                lion_record = (const unsigned char *)source + 0x20;
                record_slot = (volatile void **)local;
                original_record = (void *)*record_slot;
                printf("original_local_record=%p\n", original_record);
                printf("lion_source_record=%p\n", lion_record);
                printf("local_record_matches_source_record=%s\n",
                       original_record == (const void *)lion_record ? "YES" : "NO");
                if (original_record != (const void *)lion_record) {
                    rc = 21;
                    goto ppc_cleanup;
                }

                printf("legacy_main_candidate_0x10e=0x%02x\n",
                       (unsigned int)lion_record[0x10e]);
                printf("lion_main_candidate_0x12a=0x%02x\n",
                       (unsigned int)lion_record[0x12a]);
                if (lion_record[0x10e] != 0 ||
                    lion_record[0x12a] == 0) {
                    rc = 22;
                    goto ppc_cleanup;
                }

                memcpy(projection, lion_record, sizeof(projection));
                memcpy(projection + 0x0f4, lion_record + 0x110, 0x20);
                printf("projection_shift=record[0x0f4..0x113]<-lion[0x110..0x12f]\n");
                printf("projection_main_candidate_0x10e=0x%02x\n",
                       (unsigned int)projection[0x10e]);
                printf("projection_fast_return_0x110=0x%02x\n",
                       (unsigned int)projection[0x110]);

                if (projection[0x10e] == 0 ||
                    projection[0x110] != 0) {
                    printf("projection_fast_path_guard=FAIL\n");
                    rc = 23;
                    goto ppc_cleanup;
                }
                printf("projection_fast_path_guard=PASS\n");

                projected_id = read_le32(projection);
                if (projected_id == 0) {
                    rc = 24;
                    goto ppc_cleanup;
                }

                source_hash_before = fnv1a32(lion_record, 0x17c);
                pointer_writes = 0;

                *record_slot = (void *)projection;
                ++pointer_writes;

                lookup_entry = lookup_main(1);

                *record_slot = original_record;
                ++pointer_writes;

                source_hash_after = fnv1a32(lion_record, 0x17c);

                printf("projection_applied=YES\n");
                printf("process_local_pointer_write_count=%u\n",
                       pointer_writes);
                printf("projection_lookup_returned_target_entry=%s\n",
                       lookup_entry == local ? "YES" : "NO");
                printf("projected_lookup_display_id=0x%08x\n",
                       (unsigned int)projected_id);
                printf("source_record_unchanged=%s\n",
                       source_hash_before == source_hash_after ? "YES" : "NO");
                printf("local_record_pointer_restored=%s\n",
                       *record_slot == original_record ? "YES" : "NO");

                if (lookup_entry != local ||
                    pointer_writes != 2 ||
                    source_hash_before != source_hash_after ||
                    *record_slot != original_record) {
                    rc = 25;
                    goto ppc_cleanup;
                }

                printf("selected_state_ready=YES\n");
            }
        }

ppc_cleanup:
        if (locked) {
            unlock_display();
            locked = 0;
        }

        after_id = public_main();
        printf("after_public_main_display_id=0x%08x\n",
               (unsigned int)after_id);
        printf("after_public_main_display_id_zero=%s\n",
               after_id == 0 ? "YES" : "NO");

        if (rc != 0) {
            printf("proof_complete=NO\n");
            printf("RESULT: FAIL\n");
            return rc;
        }

        if (darwin_major == 10) {
            if (after_id == 0 || after_id != baseline_id) {
                printf("proof_complete=NO\n");
                printf("RESULT: FAIL\n");
                return 26;
            }
        } else {
            if (baseline_id != 0 || after_id != 0) {
                printf("proof_complete=NO\n");
                printf("RESULT: FAIL\n");
                return 27;
            }
        }

        printf("proof_complete=YES\n");
        printf("RESULT: PASS\n");
        return 0;
    }
#endif
}
