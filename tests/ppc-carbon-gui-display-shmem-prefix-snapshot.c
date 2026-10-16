/*
 * Read-only display shared-memory prefix snapshot for the Rosetta titlebar
 * main-display investigation.
 *
 * This program never writes the CoreGraphics mapping global or the mapped
 * shared-memory object. It calls only the exported CGSMainDisplayID entry,
 * then reads the already-populated mapping pointer from a statically audited
 * CoreGraphics image offset.
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

#if !defined(__ppc__) && !defined(__i386__)
#error This diagnostic is intentionally limited to 32-bit PPC and i386.
#endif

typedef uint32_t (*CGSMainDisplayIDFunction)(void);

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
    uintptr_t mapping_offset;
    volatile void **mapping_slot;
    void *mapping_before;
    void *mapping_after;
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
    printf("snapshot_contract=carbon-gui-display-shmem-prefix-snapshot-v1\n");
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
    mapping_offset = (uintptr_t)0x70046cU;
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
    mapping_offset = (uintptr_t)0x949848U;
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
    printf("mapping_global_from_image_header=0x%08lx\n",
           (unsigned long)mapping_offset);
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

    mapping_slot =
        (volatile void **)((uintptr_t)cg_header + mapping_offset);
    printf("mapping_slot=%p\n", (void *)mapping_slot);

    if (!range_is_readable((const void *)mapping_slot, sizeof(void *))) {
        printf("mapping_slot_readable=NO\n");
        printf("RESULT: FAIL\n");
        return 6;
    }
    printf("mapping_slot_readable=YES\n");

    mapping_before = *mapping_slot;
    printf("mapping_before=%p\n", mapping_before);

    symbol = dlsym(RTLD_DEFAULT, "CGSMainDisplayID");
    if (symbol == 0) {
        printf("CGSMainDisplayID_dlsym=FAIL\n");
        printf("RESULT: FAIL\n");
        return 7;
    }
    printf("CGSMainDisplayID_dlsym=PASS\n");

    cgs_main_display_id = (CGSMainDisplayIDFunction)symbol;
    main_id = cgs_main_display_id();
    printf("main_display_id=0x%08x\n", (unsigned int)main_id);
    printf("main_display_id_zero=%s\n", main_id == 0 ? "YES" : "NO");

    mapping_after = *mapping_slot;
    printf("mapping_after=%p\n", mapping_after);
    printf("mapping_after_nonnull=%s\n",
           mapping_after != 0 ? "YES" : "NO");
    if (mapping_after == 0) {
        printf("RESULT: FAIL\n");
        return 8;
    }

    if (!range_is_readable(mapping_after, prefix_length)) {
        printf("mapped_prefix_readable=NO\n");
        printf("RESULT: FAIL\n");
        return 9;
    }
    printf("mapped_prefix_readable=YES\n");

    mapped = (const unsigned char *)mapping_after;
    count = read_le32(mapped);
    printf("record_count_le=%u\n", (unsigned int)count);
    printf("record_count_valid=%s\n",
           (count >= 1 && count <= 64) ? "YES" : "NO");
    if (count < 1 || count > 64) {
        printf("RESULT: FAIL\n");
        return 10;
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
