/*
 * Read-only display shared-memory prefix snapshot for the Rosetta titlebar
 * main-display investigation.
 *
 * v2 correction: the mode-2 mapping global is NOT the source object consumed
 * by _initCGDisplayMappings/_initDisplayMappings.  The active source object is
 * selected through the release-local selector byte and the two-entry source
 * pointer array used directly by _lookupMainDisplay.
 *
 * v4 correction: standalone CoreGraphics VM addresses are provenance only for
 * translated PPC.  Rosetta shared-cache __TEXT and __DATA can be rebased
 * independently, so the PPC runtime globals are reconstructed from the loaded
 * _lookupMainDisplay PIC instructions.
 *
 * This program never writes any CoreGraphics global or mapped shared memory.
 */

#include <ApplicationServices/ApplicationServices.h>
#include <dlfcn.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <setjmp.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/utsname.h>

#if !defined(__ppc__) && !defined(__i386__)
#error This diagnostic is intentionally limited to 32-bit PPC and i386.
#endif

typedef uint32_t (*CGSMainDisplayIDFunction)(void);

static CGDirectDisplayID (*volatile force_coregraphics_dependency)(void) =
    CGMainDisplayID;

static sigjmp_buf snapshot_jmp;
static volatile sig_atomic_t snapshot_fault_active = 0;

static void
snapshot_fault_handler(int signo)
{
    (void)signo;
    if (snapshot_fault_active) {
        siglongjmp(snapshot_jmp, 1);
    }
}

static int
guarded_copy(void *dst, const void *src, size_t length)
{
    struct sigaction sa;
    struct sigaction old_segv;
    struct sigaction old_bus;
    volatile const unsigned char *s;
    unsigned char *d;
    size_t i;
    int ok;

    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = snapshot_fault_handler;
    sigemptyset(&sa.sa_mask);

    if (sigaction(SIGSEGV, &sa, &old_segv) != 0) {
        return 0;
    }
    if (sigaction(SIGBUS, &sa, &old_bus) != 0) {
        sigaction(SIGSEGV, &old_segv, 0);
        return 0;
    }

    ok = 1;
    snapshot_fault_active = 1;
    if (sigsetjmp(snapshot_jmp, 1) == 0) {
        s = (volatile const unsigned char *)src;
        d = (unsigned char *)dst;
        for (i = 0; i < length; ++i) {
            d[i] = s[i];
        }
    } else {
        ok = 0;
    }
    snapshot_fault_active = 0;

    sigaction(SIGBUS, &old_bus, 0);
    sigaction(SIGSEGV, &old_segv, 0);
    return ok;
}

static uint32_t
read_le32(const unsigned char *p)
{
    return ((uint32_t)p[0]) |
           ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) |
           ((uint32_t)p[3] << 24);
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
range_is_readable(const void *ptr, size_t length)
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
    ok = ((info.protection & VM_PROT_READ) != 0) &&
         target >= address &&
         target_end >= (unsigned long long)target &&
         target_end <= region_end;

    if (object_name != MACH_PORT_NULL) {
        mach_port_deallocate(mach_task_self(), object_name);
    }

    return ok;
}

static uint32_t
read_native_u32(const void *p)
{
    uint32_t v;
    memcpy(&v, p, sizeof(v));
    return v;
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

static void
dump_hex(const unsigned char *p, size_t n)
{
    size_t i;
    size_t j;

    printf("raw_prefix_begin\n");
    for (i = 0; i < n; i += 16) {
        printf("raw+0x%04lx=", (unsigned long)i);
        for (j = 0; j < 16 && i + j < n; ++j) {
            printf("%02x", (unsigned int)p[i + j]);
        }
        printf("\n");
    }
    printf("raw_prefix_end\n");
}

static void
dump_legacy_view(const unsigned char *record)
{
    unsigned int off;

    printf("legacy_id_primary_0x0f4_le=0x%08x\n",
           (unsigned int)read_le32(record + 0x0f4));
    printf("legacy_id_secondary_0x0f8_le=0x%08x\n",
           (unsigned int)read_le32(record + 0x0f8));
    printf("legacy_word_0x0fc_le=0x%08x\n",
           (unsigned int)read_le32(record + 0x0fc));
    printf("legacy_word_0x100_le=0x%08x\n",
           (unsigned int)read_le32(record + 0x100));
    printf("legacy_word_0x104_le=0x%08x\n",
           (unsigned int)read_le32(record + 0x104));
    printf("legacy_word_0x108_le=0x%08x\n",
           (unsigned int)read_le32(record + 0x108));

    printf("legacy_status_0x10c_0x113=");
    for (off = 0x10c; off <= 0x113; ++off) {
        printf("%02x", (unsigned int)record[off]);
    }
    printf("\n");

    printf("legacy_word_0x138_le=0x%08x\n",
           (unsigned int)read_le32(record + 0x138));
}

static void
dump_lion_view(const unsigned char *record)
{
    unsigned int off;

    printf("lion_id_primary_0x110_le=0x%08x\n",
           (unsigned int)read_le32(record + 0x110));
    printf("lion_id_secondary_0x114_le=0x%08x\n",
           (unsigned int)read_le32(record + 0x114));
    printf("lion_word_0x118_le=0x%08x\n",
           (unsigned int)read_le32(record + 0x118));
    printf("lion_word_0x11c_le=0x%08x\n",
           (unsigned int)read_le32(record + 0x11c));
    printf("lion_word_0x120_le=0x%08x\n",
           (unsigned int)read_le32(record + 0x120));
    printf("lion_word_0x124_le=0x%08x\n",
           (unsigned int)read_le32(record + 0x124));

    printf("lion_status_0x128_0x12f=");
    for (off = 0x128; off <= 0x12f; ++off) {
        printf("%02x", (unsigned int)record[off]);
    }
    printf("\n");

    printf("lion_word_0x154_le=0x%08x\n",
           (unsigned int)read_le32(record + 0x154));
}

int
main(void)
{
    struct utsname uts;
    unsigned long darwin_major;
    const struct mach_header *cg_header;
    const char *cg_name;
    uint32_t cg_matches;
    uintptr_t selector_global_static;
    uintptr_t source_array_static;
    uintptr_t local_array_static;
    uintptr_t mode2_static;
    void * volatile *selector_slot;
    void * volatile *source_slots;
    void * volatile *local_slots;
    void * volatile *mode2_slot;
    void *selector_ptr;
    unsigned int selector_index;
    void *source_after;
    void *local_after;
    void *mode2_after;
#if defined(__ppc__)
    const unsigned char *lookup_main_runtime;
    intptr_t lookup_pic_base;
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
    char selector_segment[17];
    char source_segment[17];
    char local_segment[17];
#endif
    unsigned char snapshot_buffer[0x178];
    unsigned char selector_byte;
    const unsigned char *mapped;
    const unsigned char *record;
    size_t prefix_length;
    uint32_t count;
    void *symbol;
    CGSMainDisplayIDFunction cgs_main_display_id;
    uint32_t main_id;
    const char *mode;

    (void)force_coregraphics_dependency;

    printf("== PPC Carbon GUI display-shmem read-only prefix snapshot ==\n");
    printf("snapshot_contract=carbon-gui-display-shmem-prefix-snapshot-v4\n");
    printf("v1_mode2_pointer_misclassification=CORRECTED\n");
    printf("translated_guest_pointer_validation=LOADED_PPC_PIC_PLUS_GUARDED_DIRECT_READ\n");
    printf("write_attempts=0\n");

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
    darwin_major = strtoul(uts.release, 0, 10);

#if defined(__ppc__)
    selector_global_static = (uintptr_t)0x6ff26cU;
    source_array_static = (uintptr_t)0x700460U;
    local_array_static = (uintptr_t)0x700458U;
    mode2_static = (uintptr_t)0x70046cU;
    if (darwin_major == 10) {
        mode = "snow-ppc-control";
        prefix_length = 0x15cU;
    } else if (darwin_major == 11) {
        mode = "lion-ppc-translated";
        prefix_length = 0x178U;
    } else {
        printf("snapshot_mode=unsupported-ppc\n");
        printf("RESULT: FAIL\n");
        return 4;
    }
#elif defined(__i386__)
    selector_global_static = (uintptr_t)0x948630U;
    source_array_static = (uintptr_t)0x94983cU;
    local_array_static = (uintptr_t)0x94984cU;
    mode2_static = (uintptr_t)0x949848U;
    if (darwin_major == 11) {
        mode = "lion-i386-native";
        prefix_length = 0x178U;
    } else {
        printf("snapshot_mode=unsupported-i386\n");
        printf("RESULT: FAIL\n");
        return 4;
    }
#endif

    printf("snapshot_mode=%s\n", mode);
    printf("selector_global_standalone_vmaddr=0x%08lx\n",
           (unsigned long)selector_global_static);
    printf("source_array_standalone_vmaddr=0x%08lx\n",
           (unsigned long)source_array_static);
    printf("local_array_standalone_vmaddr=0x%08lx\n",
           (unsigned long)local_array_static);
    printf("mode2_mapping_standalone_vmaddr=0x%08lx\n",
           (unsigned long)mode2_static);
    printf("prefix_length=0x%lx\n", (unsigned long)prefix_length);

    if (!find_coregraphics_image(&cg_header, &cg_name, &cg_matches)) {
        printf("coregraphics_image_match_count=%u\n",
               (unsigned int)cg_matches);
        printf("RESULT: FAIL\n");
        return 5;
    }

    printf("coregraphics_image_match_count=1\n");
    printf("coregraphics_image=%s\n", cg_name);
    printf("coregraphics_header=%p\n", (void *)cg_header);

    symbol = dlsym(RTLD_DEFAULT, "CGSMainDisplayID");
    if (symbol == 0) {
        printf("CGSMainDisplayID_dlsym=FAIL\n");
        printf("RESULT: FAIL\n");
        return 6;
    }
    printf("CGSMainDisplayID_dlsym=PASS\n");
    printf("CGSMainDisplayID_runtime=%p\n", symbol);

#if defined(__ppc__)
    /*
     * Standalone Snow PPC VM addresses cannot be converted to Rosetta-cache
     * runtime addresses by adding the loaded image header: the cache may
     * relocate __TEXT and __DATA independently.  Reconstruct the three globals
     * from the loaded _lookupMainDisplay PIC references instead.
     */
    lookup_main_runtime =
        (const unsigned char *)((intptr_t)(uintptr_t)symbol - (intptr_t)0x5858L);
    lookup_pic_base =
        (intptr_t)(uintptr_t)(lookup_main_runtime + 0x08);

    lookup_prologue_word = read_native_u32(lookup_main_runtime);
    selector_addis_word = read_native_u32(lookup_main_runtime + 0x1c);
    selector_low_word = read_native_u32(lookup_main_runtime + 0x20);
    source_addis_word = read_native_u32(lookup_main_runtime + 0x30);
    source_low_word = read_native_u32(lookup_main_runtime + 0x34);
    local_addis_word = read_native_u32(lookup_main_runtime + 0x4c);
    local_low_word = read_native_u32(lookup_main_runtime + 0x50);

    printf("runtime_address_model=LOADED_PPC_LOOKUPMAIN_PIC\n");
    printf("lookup_main_runtime=%p\n", (void *)lookup_main_runtime);
    printf("lookup_main_prologue_word=0x%08x\n",
           (unsigned int)lookup_prologue_word);
    printf("lookup_selector_addis_word=0x%08x\n",
           (unsigned int)selector_addis_word);
    printf("lookup_selector_low_word=0x%08x\n",
           (unsigned int)selector_low_word);
    printf("lookup_source_addis_word=0x%08x\n",
           (unsigned int)source_addis_word);
    printf("lookup_source_low_word=0x%08x\n",
           (unsigned int)source_low_word);
    printf("lookup_local_addis_word=0x%08x\n",
           (unsigned int)local_addis_word);
    printf("lookup_local_low_word=0x%08x\n",
           (unsigned int)local_low_word);

    if (lookup_prologue_word != 0x7c0802a6U ||
        (selector_addis_word & 0xffff0000U) != 0x3fdf0000U ||
        (selector_low_word & 0xffff0000U) != 0x813e0000U ||
        (source_addis_word & 0xffff0000U) != 0x3c5f0000U ||
        (source_low_word & 0xffff0000U) != 0x39020000U ||
        (local_addis_word & 0xffff0000U) != 0x3c5f0000U ||
        (local_low_word & 0xffff0000U) != 0x38c20000U) {
        printf("ppc_pic_pattern=FAIL\n");
        printf("RESULT: FAIL\n");
        return 7;
    }
    printf("ppc_pic_pattern=PASS\n");

    selector_runtime =
        (uintptr_t)(lookup_pic_base +
                    (intptr_t)(int16_t)(selector_addis_word & 0xffffU) * 65536L +
                    (intptr_t)(int16_t)(selector_low_word & 0xffffU));
    source_array_runtime =
        (uintptr_t)(lookup_pic_base +
                    (intptr_t)(int16_t)(source_addis_word & 0xffffU) * 65536L +
                    (intptr_t)(int16_t)(source_low_word & 0xffffU));
    local_array_runtime =
        (uintptr_t)(lookup_pic_base +
                    (intptr_t)(int16_t)(local_addis_word & 0xffffU) * 65536L +
                    (intptr_t)(int16_t)(local_low_word & 0xffffU));

    selector_segment[0] = '\0';
    source_segment[0] = '\0';
    local_segment[0] = '\0';

    if (!find_segment_for_runtime_addr(cg_header, selector_runtime,
                                       sizeof(void *), selector_segment) ||
        !find_segment_for_runtime_addr(cg_header, source_array_runtime,
                                       2 * sizeof(void *), source_segment) ||
        !find_segment_for_runtime_addr(cg_header, local_array_runtime,
                                       2 * sizeof(void *), local_segment)) {
        printf("ppc_runtime_targets_in_segments=NO\n");
        printf("RESULT: FAIL\n");
        return 8;
    }
    printf("ppc_runtime_targets_in_segments=YES\n");
    printf("selector_runtime=0x%08lx\n", (unsigned long)selector_runtime);
    printf("source_array_runtime=0x%08lx\n",
           (unsigned long)source_array_runtime);
    printf("local_array_runtime=0x%08lx\n",
           (unsigned long)local_array_runtime);
    printf("selector_runtime_segment=%s\n", selector_segment);
    printf("source_array_runtime_segment=%s\n", source_segment);
    printf("local_array_runtime_segment=%s\n", local_segment);

    selector_slot = (void * volatile *)selector_runtime;
    source_slots = (void * volatile *)source_array_runtime;
    local_slots = (void * volatile *)local_array_runtime;
    mode2_slot = 0;
#else
    printf("runtime_address_model=IMAGE_HEADER_PLUS_STANDALONE_VMADDR_I386\n");
    selector_slot =
        (void * volatile *)((uintptr_t)cg_header + selector_global_static);
    source_slots =
        (void * volatile *)((uintptr_t)cg_header + source_array_static);
    local_slots =
        (void * volatile *)((uintptr_t)cg_header + local_array_static);
    mode2_slot =
        (void * volatile *)((uintptr_t)cg_header + mode2_static);
#endif

    printf("selector_global_slot=%p\n", (void *)selector_slot);
    printf("source_array=%p\n", (void *)source_slots);
    printf("local_array=%p\n", (void *)local_slots);
    printf("mode2_mapping_slot=%p\n", (void *)mode2_slot);

    if (!range_is_readable((const void *)selector_slot, sizeof(void *)) ||
        !range_is_readable((const void *)source_slots, 2 * sizeof(void *)) ||
        !range_is_readable((const void *)local_slots, 2 * sizeof(void *))
#if defined(__i386__)
        || !range_is_readable((const void *)mode2_slot, sizeof(void *))
#endif
        ) {
        printf("coregraphics_slots_readable=NO\n");
        printf("RESULT: FAIL\n");
        return 9;
    }
    printf("coregraphics_slots_readable=YES\n");

    cgs_main_display_id = (CGSMainDisplayIDFunction)symbol;
    main_id = cgs_main_display_id();
    printf("main_display_id=0x%08x\n", (unsigned int)main_id);
    printf("main_display_id_zero=%s\n", main_id == 0 ? "YES" : "NO");

    selector_ptr = 0;
    if (!guarded_copy(&selector_ptr, (const void *)selector_slot,
                      sizeof(selector_ptr))) {
        printf("selector_slot_read=FAIL\n");
        printf("RESULT: FAIL\n");
        return 10;
    }
    printf("selector_slot_read=PASS\n");
    printf("selector_pointer_after=%p\n", selector_ptr);
    printf("selector_pointer_vm_region_readable=%s\n",
           selector_ptr != 0 && range_is_readable(selector_ptr, 1) ? "YES" : "NO");
    if (selector_ptr == 0 || !guarded_copy(&selector_byte, selector_ptr, 1)) {
        printf("selector_direct_read=FAIL\n");
        printf("RESULT: FAIL\n");
        return 11;
    }
    printf("selector_direct_read=PASS\n");

    selector_index = (unsigned int)selector_byte;
    printf("selector_index=%u\n", selector_index);
    printf("selector_index_valid=%s\n",
           selector_index < 2 ? "YES" : "NO");
    if (selector_index >= 2) {
        printf("RESULT: FAIL\n");
        return 12;
    }

    source_after = 0;
    local_after = 0;
    if (!guarded_copy(&source_after,
                      (const void *)&source_slots[selector_index],
                      sizeof(source_after)) ||
        !guarded_copy(&local_after,
                      (const void *)&local_slots[selector_index],
                      sizeof(local_after))) {
        printf("selected_slot_read=FAIL\n");
        printf("RESULT: FAIL\n");
        return 13;
    }
    printf("selected_slot_read=PASS\n");
#if defined(__i386__)
    mode2_after = *mode2_slot;
#else
    mode2_after = 0;
#endif

    printf("active_source_slot=%p\n",
           (void *)&source_slots[selector_index]);
    printf("active_local_slot=%p\n",
           (void *)&local_slots[selector_index]);
    printf("source_after=%p\n", source_after);
    printf("local_mapping_after=%p\n", local_after);
#if defined(__i386__)
    printf("mode2_mapping_after=%p\n", mode2_after);
    printf("mode2_is_active_source=%s\n",
           mode2_after == source_after ? "YES" : "NO");
#else
    printf("mode2_mapping_after=NOT_RESOLVED_IN_V4_PPC\n");
    printf("mode2_is_active_source=NOT_TESTED_IN_V4_PPC\n");
#endif
    printf("source_after_nonnull=%s\n",
           source_after != 0 ? "YES" : "NO");

    if (source_after == 0) {
        printf("RESULT: FAIL\n");
        return 14;
    }

    printf("source_pointer_vm_region_readable=%s\n",
           range_is_readable(source_after, prefix_length) ? "YES" : "NO");
    if (!guarded_copy(snapshot_buffer, source_after, prefix_length)) {
        printf("source_direct_read=FAIL\n");
        printf("RESULT: FAIL\n");
        return 15;
    }
    printf("source_direct_read=PASS\n");

    mapped = snapshot_buffer;
    count = read_le32(mapped);
    printf("record_count_le=%u\n", (unsigned int)count);
    printf("record_count_valid=%s\n",
           (count >= 1 && count <= 64) ? "YES" : "NO");
    if (count < 1 || count > 64) {
        printf("RESULT: FAIL\n");
        return 16;
    }

    printf("record_base_offset=0x20\n");
    printf("raw_prefix_fnv1a32=0x%08x\n",
           (unsigned int)fnv1a32(mapped, prefix_length));
    dump_hex(mapped, prefix_length);

    record = mapped + 0x20;
    dump_legacy_view(record);
    if (darwin_major == 11) {
        dump_lion_view(record);
    } else {
        printf("lion_view=NOT_READ_ON_SNOW\n");
    }

    printf("snapshot_complete=YES\n");
    printf("write_attempts=0\n");
    printf("RESULT: PASS\n");
    return 0;
}
