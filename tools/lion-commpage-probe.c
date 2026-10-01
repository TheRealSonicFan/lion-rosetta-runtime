#include <mach/mach.h>
#include <mach/mach_vm.h>
#include <mach/vm_region.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define COMM32_BASE             ((mach_vm_address_t)0xfffec000ULL)
#define COMM32_END              ((mach_vm_address_t)0xfffff000ULL)
#define COMM32_NATIVE_VERSION   ((mach_vm_address_t)0xffff001eULL)
#define COMM32_NATIVE_CAPS      ((mach_vm_address_t)0xffff0020ULL)
#define COMM32_NATIVE_CPUFAMILY ((mach_vm_address_t)0xffff0040ULL)
#define ROSETTA_SIGDATA         ((mach_vm_address_t)0xffff3000ULL)
#define ROSETTA_VERSION         ((mach_vm_address_t)0xffff801eULL)
#define ROSETTA_CAPS            ((mach_vm_address_t)0xffff8020ULL)
#define ROSETTA_CACHELINE       ((mach_vm_address_t)0xffff8026ULL)
#define ROSETTA_TWO52           ((mach_vm_address_t)0xffff8040ULL)
#define ROSETTA_TEN6            ((mach_vm_address_t)0xffff8048ULL)
#define ROSETTA_BA_LOW          ((mach_vm_address_t)0xfffefea0ULL)
#define ROSETTA_BA_HIGH         ((mach_vm_address_t)0xffff8080ULL)

static uint16_t
le16(const unsigned char *p)
{
    return (uint16_t)p[0] | ((uint16_t)p[1] << 8);
}

static uint32_t
le32(const unsigned char *p)
{
    return (uint32_t)p[0] |
           ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) |
           ((uint32_t)p[3] << 24);
}

static uint16_t
be16(const unsigned char *p)
{
    return ((uint16_t)p[0] << 8) | (uint16_t)p[1];
}

static uint32_t
be32(const unsigned char *p)
{
    return ((uint32_t)p[0] << 24) |
           ((uint32_t)p[1] << 16) |
           ((uint32_t)p[2] << 8) |
           (uint32_t)p[3];
}

static uint64_t
be64(const unsigned char *p)
{
    uint64_t hi = (uint64_t)be32(p);
    uint64_t lo = (uint64_t)be32(p + 4);
    return (hi << 32) | lo;
}

static int
read_bytes(mach_vm_address_t address, void *buffer, mach_vm_size_t size)
{
    volatile const unsigned char *src;
    unsigned char *dst;
    mach_vm_size_t i;

    /*
     * Read the commpage exactly as ordinary user code does: through the
     * process's own mapped virtual address.  mach_vm_read_overwrite() is
     * not a reliable probe for this shared commpage mapping on Lion/i386;
     * it can return KERN_INVALID_ADDRESS even when mach_vm_region() reports
     * the range as readable and normal user loads succeed.
     */
    src = (volatile const unsigned char *)(uintptr_t)address;
    dst = (unsigned char *)buffer;

    for (i = 0; i < size; i++)
        dst[i] = src[i];

    return 1;
}

static int
report_region(mach_vm_address_t target)
{
    mach_vm_address_t address = target;
    mach_vm_size_t size = 0;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t object_name = MACH_PORT_NULL;
    kern_return_t kr;
    int contains;

    kr = mach_vm_region(mach_task_self(), &address, &size,
                        VM_REGION_BASIC_INFO_64,
                        (vm_region_info_t)&info, &count, &object_name);
    if (object_name != MACH_PORT_NULL)
        mach_port_deallocate(mach_task_self(), object_name);

    if (kr != KERN_SUCCESS) {
        printf("FAIL: vm region query for 0x%08llx: %s (%d)\n",
               (unsigned long long)target, mach_error_string(kr), kr);
        return 0;
    }

    contains = (address <= target && target < address + size);
    printf("region for 0x%08llx: 0x%08llx-0x%08llx prot=0x%x max=0x%x%s\n",
           (unsigned long long)target,
           (unsigned long long)address,
           (unsigned long long)(address + size),
           info.protection, info.max_protection,
           contains ? "" : " (does not contain target)");

    if (!contains)
        return 0;
    if ((info.protection & VM_PROT_READ) == 0) {
        printf("FAIL: commpage region is not readable\n");
        return 0;
    }
    return 1;
}

int
main(void)
{
    unsigned char b[8];
    uint16_t native_version, translated_version, cacheline;
    uint32_t native_caps, native_cpufamily, translated_caps;
    uint32_t sig_word, ba_low_word, ba_high_word;
    uint64_t two52_bits, ten6_bits;
    int ok = 1;

    printf("Lion Rosetta translated-commpage probe\n");
    printf("expected mapping: 0x%08llx-0x%08llx\n",
           (unsigned long long)COMM32_BASE,
           (unsigned long long)COMM32_END);

    ok &= report_region(COMM32_BASE);
    ok &= report_region(ROSETTA_CAPS);

    if (read_bytes(COMM32_NATIVE_VERSION, b, 2)) {
        native_version = le16(b);
        printf("native commpage version: %u\n", (unsigned)native_version);
        if (native_version != 12) {
            printf("FAIL: expected Lion native commpage version 12\n");
            ok = 0;
        }
    } else ok = 0;

    if (read_bytes(COMM32_NATIVE_CAPS, b, 4)) {
        native_caps = le32(b);
        printf("native CPU capabilities: 0x%08x\n", native_caps);
    } else ok = 0;

    if (read_bytes(COMM32_NATIVE_CPUFAMILY, b, 4)) {
        native_cpufamily = le32(b);
        printf("native CPU family: 0x%08x\n", native_cpufamily);
    } else ok = 0;

    if (read_bytes(ROSETTA_VERSION, b, 2)) {
        translated_version = be16(b);
        printf("Rosetta commpage version (PPC byte order): %u\n", (unsigned)translated_version);
        if (translated_version != 11) {
            printf("FAIL: expected Rosetta compatibility version 11\n");
            ok = 0;
        }
    } else ok = 0;

    if (read_bytes(ROSETTA_CAPS, b, 4)) {
        translated_caps = be32(b);
        printf("Rosetta CPU capabilities (PPC byte order): 0x%08x\n", translated_caps);
        if ((translated_caps & 0x44U) != 0x44U) {
            printf("FAIL: translated capabilities lack Snow Leopard baseline 0x44\n");
            ok = 0;
        }
    } else ok = 0;

    if (read_bytes(ROSETTA_CACHELINE, b, 2)) {
        cacheline = be16(b);
        printf("Rosetta cache-line size (PPC byte order): %u\n", (unsigned)cacheline);
        if (cacheline != 32) {
            printf("FAIL: expected Rosetta cache-line size 32\n");
            ok = 0;
        }
    } else ok = 0;

    if (read_bytes(ROSETTA_TWO52, b, 8)) {
        two52_bits = be64(b);
        printf("Rosetta 2**52 bits: 0x%016llx\n", (unsigned long long)two52_bits);
        if (two52_bits != 0x4330000000000000ULL) {
            printf("FAIL: unexpected Rosetta 2**52 constant\n");
            ok = 0;
        }
    } else ok = 0;

    if (read_bytes(ROSETTA_TEN6, b, 8)) {
        ten6_bits = be64(b);
        printf("Rosetta 10**6 bits: 0x%016llx\n", (unsigned long long)ten6_bits);
        if (ten6_bits != 0x412e848000000000ULL) {
            printf("FAIL: unexpected Rosetta 10**6 constant\n");
            ok = 0;
        }
    } else ok = 0;

    if (read_bytes(ROSETTA_SIGDATA, b, 4)) {
        sig_word = le32(b);
        printf("sigdata first source word: 0x%08x (PPC view 0x%08x)\n", sig_word, be32(b));
        if (sig_word != 0x06004018U) {
            printf("FAIL: sigdata does not match Snow Leopard table\n");
            ok = 0;
        }
    } else ok = 0;

    if (read_bytes(ROSETTA_BA_LOW, b, 4)) {
        ba_low_word = le32(b);
        printf("branch-assist low source word: 0x%08x (PPC view 0x%08x)\n", ba_low_word, be32(b));
        if (ba_low_word != 0xae3aff4bU) {
            printf("FAIL: low branch-assist word mismatch\n");
            ok = 0;
        }
    } else ok = 0;

    if (read_bytes(ROSETTA_BA_HIGH, b, 4)) {
        ba_high_word = le32(b);
        printf("branch-assist high source word: 0x%08x (PPC view 0x%08x)\n", ba_high_word, be32(b));
        if (ba_high_word != 0x0230ff4bU) {
            printf("FAIL: high branch-assist word mismatch\n");
            ok = 0;
        }
    } else ok = 0;

    if (!ok) {
        printf("RESULT: FAIL\n");
        return 1;
    }

    printf("RESULT: PASS - Lion native ABI and Rosetta translated commpage are present\n");
    return 0;
}
