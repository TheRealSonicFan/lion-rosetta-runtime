#include <Carbon/Carbon.h>
#include <dlfcn.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define LS_IMAGE_SUFFIX "/LaunchServices.framework/Versions/A/LaunchServices"
#define CG_IMAGE_SUFFIX "/CoreGraphics.framework/Versions/A/CoreGraphics"

#define LS_SETUP_TEXT_OFFSET 0x00018070UL
#define LS_GET_DISPATCH_TEXT_OFFSET 0x00018654UL
#define LS_GET_SERVER_PORT_TEXT_OFFSET 0x000186a8UL
#define LS_EXPECTED_PROLOGUE_WORD 0x7c0802a6UL

#define CG_CPS_WITH_OPTIONS_VMADDR 0x001fcfdcUL
#define CG_CPS_SET_FRONT_VMADDR 0x001fd0ccUL
#define CG_CONNECTION_SLOT_VMADDR 0x007007c8UL
#define CG_EXPECTED_PROLOGUE_WORD 0x7c0802a6UL
#define CG_CPS_NO_CONNECTION_STATUS 0x000003ebUL

typedef const void *(*get_dispatch_table_fn_t)(void);
typedef mach_port_t (*get_server_port_fn_t)(void);
typedef int32_t (*cps_set_front_process_fn_t)(const ProcessSerialNumber *);

static void
marker(const char *s)
{
    fprintf(stderr, "%s\n", s);
    fflush(stderr);
}

static int
ends_with(const char *s, const char *suffix)
{
    size_t ns;
    size_t nx;

    if (s == NULL || suffix == NULL)
        return 0;
    ns = strlen(s);
    nx = strlen(suffix);
    if (ns < nx)
        return 0;
    return strcmp(s + ns - nx, suffix) == 0;
}

static const struct mach_header *
find_image(const char *suffix, const char **name_out, uint32_t *index_out)
{
    uint32_t i;
    uint32_t n = _dyld_image_count();

    for (i = 0; i < n; ++i) {
        const char *name = _dyld_get_image_name(i);
        if (ends_with(name, suffix)) {
            if (name_out != NULL)
                *name_out = name;
            if (index_out != NULL)
                *index_out = i;
            return _dyld_get_image_header(i);
        }
    }
    return NULL;
}

static int
find_text_segment(const struct mach_header *mh,
                  uint32_t *vmaddr_out,
                  uint32_t *vmsize_out)
{
    const uint8_t *p;
    uint32_t i;

    if (mh == NULL || mh->magic != MH_MAGIC || mh->cputype != CPU_TYPE_POWERPC)
        return 0;

    p = (const uint8_t *)(mh + 1);
    for (i = 0; i < mh->ncmds; ++i) {
        const struct load_command *lc = (const struct load_command *)p;
        if (lc->cmdsize < sizeof(struct load_command))
            return 0;
        if (lc->cmd == LC_SEGMENT) {
            const struct segment_command *seg =
                (const struct segment_command *)p;
            if (strncmp(seg->segname, SEG_TEXT, sizeof(seg->segname)) == 0) {
                if (vmaddr_out != NULL)
                    *vmaddr_out = seg->vmaddr;
                if (vmsize_out != NULL)
                    *vmsize_out = seg->vmsize;
                return 1;
            }
        }
        p += lc->cmdsize;
    }
    return 0;
}

static int
find_segment_for_vmaddr(const struct mach_header *mh,
                        uint32_t target,
                        char segname_out[17])
{
    const uint8_t *p;
    uint32_t i;

    if (mh == NULL || mh->magic != MH_MAGIC || mh->cputype != CPU_TYPE_POWERPC)
        return 0;

    p = (const uint8_t *)(mh + 1);
    for (i = 0; i < mh->ncmds; ++i) {
        const struct load_command *lc = (const struct load_command *)p;
        if (lc->cmdsize < sizeof(struct load_command))
            return 0;
        if (lc->cmd == LC_SEGMENT) {
            const struct segment_command *seg =
                (const struct segment_command *)p;
            uint64_t start = (uint64_t)seg->vmaddr;
            uint64_t end = start + (uint64_t)seg->vmsize;
            uint64_t addr = (uint64_t)target;
            if (addr >= start && addr + 4 <= end) {
                if (segname_out != NULL) {
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

static void *
resolve_local_text_offset(const struct mach_header *mh,
                          uint32_t text_vmaddr,
                          uint32_t text_vmsize,
                          uint32_t text_offset)
{
    uintptr_t loaded_header;

    if (mh == NULL)
        return NULL;

    loaded_header = (uintptr_t)mh;
    if (loaded_header != (uintptr_t)text_vmaddr)
        return NULL;
    if ((uintptr_t)text_offset >= (uintptr_t)text_vmsize)
        return NULL;

    return (void *)(loaded_header + (uintptr_t)text_offset);
}

static uint32_t
read_u32(const void *p)
{
    uint32_t v;
    memcpy(&v, p, sizeof(v));
    return v;
}

static uintptr_t
apply_slide(uint32_t original_vmaddr, intptr_t slide)
{
    return (uintptr_t)((intptr_t)(uintptr_t)original_vmaddr + slide);
}

static void
log_connection_state(const char *phase, const void *slot)
{
    uint32_t value = read_u32(slot);
    fprintf(stderr,
            "PM_CPS_CONNECTION_STATE:phase=%s slot=0x%08lx pointer=0x%08lx nonzero=%s\n",
            phase,
            (unsigned long)(uintptr_t)slot,
            (unsigned long)value,
            value != 0 ? "YES" : "NO");
    fflush(stderr);
}

int
main(void)
{
    const struct mach_header *ls_mh;
    const struct mach_header *cg_mh;
    const char *ls_image_name = NULL;
    const char *cg_image_name = NULL;
    const char *noasn;
    uint32_t cg_index = 0;
    intptr_t cg_slide = 0;
    uint32_t text_vmaddr = 0;
    uint32_t text_vmsize = 0;
    void *setup_addr;
    void *dispatch_addr;
    void *server_addr;
    void *cps_with_options_addr;
    void *cps_set_front_addr;
    void *connection_slot_addr;
    uintptr_t expected_cps_with_options;
    uintptr_t expected_cps_set_front;
    char cps_segment[17];
    char slot_segment[17];
    get_dispatch_table_fn_t get_dispatch;
    get_server_port_fn_t get_server_port;
    cps_set_front_process_fn_t cps_set_front;
    const void *dispatch_table;
    mach_port_t server_port;
    ProcessSerialNumber psn = { 0, 0 };
    pid_t self;
    pid_t roundtrip_pid = (pid_t)-1;
    OSStatus status;
    int32_t cps_status;

    marker("PM_POSTIDENTITY_MILESTONE:M00_MAIN_ENTER");

    noasn = getenv("LSDONOTABORTIFNOASN");
    fprintf(stderr,
            "PM_POSTIDENTITY_ENV:LSDONOTABORTIFNOASN=%s\n",
            noasn != NULL ? noasn : "(unset)");
    fflush(stderr);
    if (noasn != NULL) {
        marker("PM_POSTIDENTITY_RESULT:NOASN_OVERRIDE_PRESENT");
        return 20;
    }

    ls_mh = find_image(LS_IMAGE_SUFFIX, &ls_image_name, NULL);
    if (ls_mh == NULL) {
        marker("PM_POSTIDENTITY_RESULT:LAUNCHSERVICES_IMAGE_NOT_FOUND");
        return 21;
    }

    if (!find_text_segment(ls_mh, &text_vmaddr, &text_vmsize)) {
        marker("PM_POSTIDENTITY_RESULT:TEXT_SEGMENT_NOT_FOUND");
        return 22;
    }

    setup_addr = resolve_local_text_offset(ls_mh, text_vmaddr, text_vmsize,
                                           LS_SETUP_TEXT_OFFSET);
    dispatch_addr = resolve_local_text_offset(ls_mh, text_vmaddr, text_vmsize,
                                              LS_GET_DISPATCH_TEXT_OFFSET);
    server_addr = resolve_local_text_offset(ls_mh, text_vmaddr, text_vmsize,
                                            LS_GET_SERVER_PORT_TEXT_OFFSET);

    fprintf(stderr,
            "PM_POSTIDENTITY_IMAGE:name=%s header=0x%08lx magic=0x%08lx cputype=%ld ncmds=%lu\n",
            ls_image_name != NULL ? ls_image_name : "(null)",
            (unsigned long)(uintptr_t)ls_mh,
            (unsigned long)ls_mh->magic,
            (long)ls_mh->cputype,
            (unsigned long)ls_mh->ncmds);
    fprintf(stderr,
            "PM_POSTIDENTITY_LAYOUT:textVMAddr=0x%08lx textVMSize=0x%08lx headerMatchesTextVMAddr=%s setupTextOffset=0x%08lx setupAddr=0x%08lx dispatchTextOffset=0x%08lx dispatchAddr=0x%08lx serverTextOffset=0x%08lx serverAddr=0x%08lx\n",
            (unsigned long)text_vmaddr,
            (unsigned long)text_vmsize,
            ((uintptr_t)ls_mh == (uintptr_t)text_vmaddr) ? "YES" : "NO",
            (unsigned long)LS_SETUP_TEXT_OFFSET,
            (unsigned long)(uintptr_t)setup_addr,
            (unsigned long)LS_GET_DISPATCH_TEXT_OFFSET,
            (unsigned long)(uintptr_t)dispatch_addr,
            (unsigned long)LS_GET_SERVER_PORT_TEXT_OFFSET,
            (unsigned long)(uintptr_t)server_addr);
    fflush(stderr);

    if (setup_addr == NULL || dispatch_addr == NULL || server_addr == NULL) {
        marker("PM_POSTIDENTITY_RESULT:LOCAL_OFFSET_INVALID");
        return 23;
    }

    fprintf(stderr,
            "PM_POSTIDENTITY_PROLOGUE:expected=0x%08lx setup=0x%08lx dispatch=0x%08lx server=0x%08lx\n",
            (unsigned long)LS_EXPECTED_PROLOGUE_WORD,
            (unsigned long)read_u32(setup_addr),
            (unsigned long)read_u32(dispatch_addr),
            (unsigned long)read_u32(server_addr));
    fflush(stderr);

    if (read_u32(setup_addr) != LS_EXPECTED_PROLOGUE_WORD ||
        read_u32(dispatch_addr) != LS_EXPECTED_PROLOGUE_WORD ||
        read_u32(server_addr) != LS_EXPECTED_PROLOGUE_WORD) {
        marker("PM_POSTIDENTITY_RESULT:LOCAL_PROLOGUE_MISMATCH");
        return 24;
    }

    get_dispatch = (get_dispatch_table_fn_t)dispatch_addr;
    get_server_port = (get_server_port_fn_t)server_addr;

    marker("PM_POSTIDENTITY_MILESTONE:M01_BEFORE_getProcessDispatchTable");
    dispatch_table = get_dispatch();
    marker("PM_POSTIDENTITY_MILESTONE:M02_AFTER_getProcessDispatchTable");

    fprintf(stderr,
            "PM_POSTIDENTITY_TABLE:pointer=0x%08lx nonzero=%s\n",
            (unsigned long)(uintptr_t)dispatch_table,
            dispatch_table != NULL ? "YES" : "NO");
    fflush(stderr);
    if (dispatch_table == NULL) {
        marker("PM_POSTIDENTITY_RESULT:DISPATCH_TABLE_NULL");
        return 25;
    }

    marker("PM_POSTIDENTITY_MILESTONE:M03_BEFORE_getProcessesServerPort");
    server_port = get_server_port();
    marker("PM_POSTIDENTITY_MILESTONE:M04_AFTER_getProcessesServerPort");

    fprintf(stderr,
            "PM_POSTIDENTITY_SERVER_PORT:port=0x%08lx nonzero=%s\n",
            (unsigned long)server_port,
            server_port != MACH_PORT_NULL ? "YES" : "NO");
    fflush(stderr);
    if (server_port == MACH_PORT_NULL) {
        marker("PM_POSTIDENTITY_RESULT:SERVER_PORT_NULL");
        return 26;
    }

    cg_mh = find_image(CG_IMAGE_SUFFIX, &cg_image_name, &cg_index);
    if (cg_mh == NULL) {
        marker("PM_CPS_DISCRIMINATOR_RESULT:COREGRAPHICS_IMAGE_NOT_FOUND");
        return 34;
    }
    if (cg_mh->magic != MH_MAGIC || cg_mh->cputype != CPU_TYPE_POWERPC) {
        marker("PM_CPS_DISCRIMINATOR_RESULT:COREGRAPHICS_NOT_PPC32");
        return 35;
    }

    cg_slide = _dyld_get_image_vmaddr_slide(cg_index);
    cps_with_options_addr = dlsym(RTLD_DEFAULT, "_CPSSetFrontProcessWithOptions");
    cps_set_front_addr = dlsym(RTLD_DEFAULT, "CPSSetFrontProcess");
    if (cps_with_options_addr == NULL || cps_set_front_addr == NULL) {
        marker("PM_CPS_DISCRIMINATOR_RESULT:CPS_SYMBOL_MISSING");
        return 36;
    }

    expected_cps_with_options =
        apply_slide(CG_CPS_WITH_OPTIONS_VMADDR, cg_slide);
    expected_cps_set_front =
        apply_slide(CG_CPS_SET_FRONT_VMADDR, cg_slide);
    connection_slot_addr =
        (void *)apply_slide(CG_CONNECTION_SLOT_VMADDR, cg_slide);

    cps_segment[0] = '\0';
    slot_segment[0] = '\0';
    if (!find_segment_for_vmaddr(cg_mh, CG_CPS_WITH_OPTIONS_VMADDR,
                                 cps_segment) ||
        !find_segment_for_vmaddr(cg_mh, CG_CONNECTION_SLOT_VMADDR,
                                 slot_segment)) {
        marker("PM_CPS_DISCRIMINATOR_RESULT:AUDITED_VMADDR_OUTSIDE_IMAGE");
        return 37;
    }

    fprintf(stderr,
            "PM_CPS_IMAGE:name=%s header=0x%08lx slide=%ld slideHex=0x%08lx cpsWithOptionsOriginal=0x%08lx cpsWithOptionsExpected=0x%08lx cpsWithOptionsResolved=0x%08lx cpsSetFrontOriginal=0x%08lx cpsSetFrontExpected=0x%08lx cpsSetFrontResolved=0x%08lx connectionSlotOriginal=0x%08lx connectionSlotRuntime=0x%08lx cpsSegment=%s slotSegment=%s\n",
            cg_image_name != NULL ? cg_image_name : "(null)",
            (unsigned long)(uintptr_t)cg_mh,
            (long)cg_slide,
            (unsigned long)(uintptr_t)cg_slide,
            (unsigned long)CG_CPS_WITH_OPTIONS_VMADDR,
            (unsigned long)expected_cps_with_options,
            (unsigned long)(uintptr_t)cps_with_options_addr,
            (unsigned long)CG_CPS_SET_FRONT_VMADDR,
            (unsigned long)expected_cps_set_front,
            (unsigned long)(uintptr_t)cps_set_front_addr,
            (unsigned long)CG_CONNECTION_SLOT_VMADDR,
            (unsigned long)(uintptr_t)connection_slot_addr,
            cps_segment,
            slot_segment);
    fflush(stderr);

    if ((uintptr_t)cps_with_options_addr != expected_cps_with_options ||
        (uintptr_t)cps_set_front_addr != expected_cps_set_front) {
        marker("PM_CPS_DISCRIMINATOR_RESULT:CPS_SYMBOL_ADDRESS_MISMATCH");
        return 38;
    }

    fprintf(stderr,
            "PM_CPS_PROLOGUE:expected=0x%08lx actual=0x%08lx\n",
            (unsigned long)CG_EXPECTED_PROLOGUE_WORD,
            (unsigned long)read_u32(cps_with_options_addr));
    fflush(stderr);
    if (read_u32(cps_with_options_addr) != CG_EXPECTED_PROLOGUE_WORD) {
        marker("PM_CPS_DISCRIMINATOR_RESULT:CPS_PROLOGUE_MISMATCH");
        return 39;
    }

    log_connection_state("preidentity", connection_slot_addr);

    self = getpid();
    fprintf(stderr, "PM_POSTIDENTITY_PID:%ld\n", (long)self);
    fflush(stderr);

    marker("PM_POSTIDENTITY_MILESTONE:M05_BEFORE_GetProcessForPID");
    status = GetProcessForPID(self, &psn);
    marker("PM_POSTIDENTITY_MILESTONE:M06_AFTER_GetProcessForPID");

    fprintf(stderr,
            "PM_POSTIDENTITY_STATUS:GetProcessForPID=%ld\n",
            (long)status);
    fprintf(stderr,
            "PM_POSTIDENTITY_PSN:high=0x%08lx low=0x%08lx\n",
            (unsigned long)psn.highLongOfPSN,
            (unsigned long)psn.lowLongOfPSN);
    fflush(stderr);

    if (status != noErr) {
        marker("PM_POSTIDENTITY_RESULT:GETPROCESSFORPID_RETURNED_ERROR");
        return 27;
    }
    if (psn.highLongOfPSN == 0 && psn.lowLongOfPSN == 0) {
        marker("PM_POSTIDENTITY_RESULT:GETPROCESSFORPID_ZERO_PSN");
        return 28;
    }

    marker("PM_POSTIDENTITY_RESULT:GETPROCESSFORPID_PASS");
    log_connection_state("postidentity", connection_slot_addr);

    marker("PM_POSTIDENTITY_MILESTONE:M07_BEFORE_GetProcessPID");
    status = GetProcessPID(&psn, &roundtrip_pid);
    marker("PM_POSTIDENTITY_MILESTONE:M08_AFTER_GetProcessPID");

    fprintf(stderr,
            "PM_POSTIDENTITY_STATUS:GetProcessPID=%ld\n",
            (long)status);
    fprintf(stderr,
            "PM_POSTIDENTITY_ROUNDTRIP:self=%ld returned=%ld match=%s\n",
            (long)self,
            (long)roundtrip_pid,
            (status == noErr && roundtrip_pid == self) ? "YES" : "NO");
    fflush(stderr);

    if (status != noErr) {
        marker("PM_POSTIDENTITY_RESULT:GETPROCESSPID_RETURNED_ERROR");
        return 29;
    }
    if (roundtrip_pid != self) {
        marker("PM_POSTIDENTITY_RESULT:GETPROCESSPID_PID_MISMATCH");
        return 30;
    }

    marker("PM_POSTIDENTITY_RESULT:GETPROCESSPID_ROUNDTRIP_PASS");

    marker("PM_POSTIDENTITY_MILESTONE:M09_BEFORE_TransformProcessType");
    status = TransformProcessType(&psn, kProcessTransformToForegroundApplication);
    marker("PM_POSTIDENTITY_MILESTONE:M10_AFTER_TransformProcessType");

    fprintf(stderr,
            "PM_POSTIDENTITY_STATUS:TransformProcessType=%ld\n",
            (long)status);
    fflush(stderr);

    if (status != noErr) {
        marker("PM_POSTIDENTITY_RESULT:TRANSFORMPROCESSTYPE_RETURNED_ERROR");
        return 31;
    }

    marker("PM_POSTIDENTITY_RESULT:TRANSFORMPROCESSTYPE_PASS");
    log_connection_state("posttransform", connection_slot_addr);

    cps_set_front = (cps_set_front_process_fn_t)cps_set_front_addr;
    marker("PM_CPS_DISCRIMINATOR_MILESTONE:M11_BEFORE_CPSSetFrontProcess");
    cps_status = cps_set_front(&psn);
    marker("PM_CPS_DISCRIMINATOR_MILESTONE:M12_AFTER_CPSSetFrontProcess");

    fprintf(stderr,
            "PM_CPS_DISCRIMINATOR_STATUS:CPSSetFrontProcess=%ld hex=0x%08lx\n",
            (long)cps_status,
            (unsigned long)(uint32_t)cps_status);
    fflush(stderr);
    log_connection_state("postcps", connection_slot_addr);

    if (cps_status == 0) {
        marker("PM_CPS_DISCRIMINATOR_RESULT:CPS_RAW_ZERO");
        marker("PM_CPS_DISCRIMINATOR_MILESTONE:M13_SUCCESS");
        return 0;
    }

    if ((uint32_t)cps_status == (uint32_t)CG_CPS_NO_CONNECTION_STATUS) {
        marker("PM_CPS_DISCRIMINATOR_RESULT:CPS_RAW_0X000003EB");
        return 32;
    }

    marker("PM_CPS_DISCRIMINATOR_RESULT:CPS_RAW_OTHER");
    return 33;
}
