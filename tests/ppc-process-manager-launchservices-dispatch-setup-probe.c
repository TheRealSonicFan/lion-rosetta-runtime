#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define LS_IMAGE_SUFFIX "/LaunchServices.framework/Versions/A/LaunchServices"
#define LS_SETUP_TEXT_OFFSET 0x00018070UL
#define LS_GET_DISPATCH_TEXT_OFFSET 0x00018654UL
#define LS_GET_SERVER_PORT_TEXT_OFFSET 0x000186a8UL
#define LS_EXPECTED_PROLOGUE_WORD 0x7c0802a6UL

typedef const void *(*get_dispatch_table_fn_t)(void);
typedef mach_port_t (*get_server_port_fn_t)(void);

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
find_launchservices_image(const char **name_out)
{
    uint32_t i;
    uint32_t n = _dyld_image_count();

    for (i = 0; i < n; ++i) {
        const char *name = _dyld_get_image_name(i);
        if (ends_with(name, LS_IMAGE_SUFFIX)) {
            if (name_out != NULL)
                *name_out = name;
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

    /*
     * In the Rosetta shared cache the in-memory LC_SEGMENT vmaddr has already
     * been rebased to the loaded cache address.  The static audit addresses
     * (0x18070, 0x18654, 0x186a8) are offsets from the original PPC image
     * __TEXT base, not absolute in-memory vmaddrs.  _dyld_get_image_header()
     * points at the loaded start of __TEXT, so resolve as header + offset.
     */
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

int
main(void)
{
    const struct mach_header *mh;
    const char *image_name = NULL;
    uint32_t text_vmaddr = 0;
    uint32_t text_vmsize = 0;
    void *setup_addr;
    void *dispatch_addr;
    void *server_addr;
    get_dispatch_table_fn_t get_dispatch;
    get_server_port_fn_t get_server_port;
    const void *dispatch_table;
    mach_port_t server_port;

    marker("PM_LS_DISPATCH_MILESTONE:M00_MAIN_ENTER");

    mh = find_launchservices_image(&image_name);
    if (mh == NULL) {
        marker("PM_LS_DISPATCH_RESULT:LAUNCHSERVICES_IMAGE_NOT_FOUND");
        return 20;
    }

    fprintf(stderr,
            "PM_LS_DISPATCH_IMAGE:name=%s header=0x%08lx magic=0x%08lx cputype=%ld ncmds=%lu\n",
            image_name != NULL ? image_name : "(null)",
            (unsigned long)(uintptr_t)mh,
            (unsigned long)mh->magic,
            (long)mh->cputype,
            (unsigned long)mh->ncmds);
    fflush(stderr);

    if (!find_text_segment(mh, &text_vmaddr, &text_vmsize)) {
        marker("PM_LS_DISPATCH_RESULT:TEXT_SEGMENT_NOT_FOUND");
        return 21;
    }

    setup_addr = resolve_local_text_offset(mh, text_vmaddr, text_vmsize,
                                           LS_SETUP_TEXT_OFFSET);
    dispatch_addr = resolve_local_text_offset(mh, text_vmaddr, text_vmsize,
                                              LS_GET_DISPATCH_TEXT_OFFSET);
    server_addr = resolve_local_text_offset(mh, text_vmaddr, text_vmsize,
                                            LS_GET_SERVER_PORT_TEXT_OFFSET);

    fprintf(stderr,
            "PM_LS_DISPATCH_LAYOUT:textVMAddr=0x%08lx textVMSize=0x%08lx headerMatchesTextVMAddr=%s setupTextOffset=0x%08lx setupAddr=0x%08lx dispatchTextOffset=0x%08lx dispatchAddr=0x%08lx serverTextOffset=0x%08lx serverAddr=0x%08lx\n",
            (unsigned long)text_vmaddr,
            (unsigned long)text_vmsize,
            ((uintptr_t)mh == (uintptr_t)text_vmaddr) ? "YES" : "NO",
            (unsigned long)LS_SETUP_TEXT_OFFSET,
            (unsigned long)(uintptr_t)setup_addr,
            (unsigned long)LS_GET_DISPATCH_TEXT_OFFSET,
            (unsigned long)(uintptr_t)dispatch_addr,
            (unsigned long)LS_GET_SERVER_PORT_TEXT_OFFSET,
            (unsigned long)(uintptr_t)server_addr);
    fflush(stderr);

    if (setup_addr == NULL || dispatch_addr == NULL || server_addr == NULL) {
        marker("PM_LS_DISPATCH_RESULT:LOCAL_OFFSET_INVALID");
        return 22;
    }

    fprintf(stderr,
            "PM_LS_DISPATCH_PROLOGUE:expected=0x%08lx setup=0x%08lx dispatch=0x%08lx server=0x%08lx\n",
            (unsigned long)LS_EXPECTED_PROLOGUE_WORD,
            (unsigned long)read_u32(setup_addr),
            (unsigned long)read_u32(dispatch_addr),
            (unsigned long)read_u32(server_addr));
    fflush(stderr);

    if (read_u32(setup_addr) != LS_EXPECTED_PROLOGUE_WORD ||
        read_u32(dispatch_addr) != LS_EXPECTED_PROLOGUE_WORD ||
        read_u32(server_addr) != LS_EXPECTED_PROLOGUE_WORD) {
        marker("PM_LS_DISPATCH_RESULT:LOCAL_PROLOGUE_MISMATCH");
        return 22;
    }

    get_dispatch = (get_dispatch_table_fn_t)dispatch_addr;
    get_server_port = (get_server_port_fn_t)server_addr;

    marker("PM_LS_DISPATCH_MILESTONE:M01_BEFORE_getProcessDispatchTable");
    dispatch_table = get_dispatch();
    marker("PM_LS_DISPATCH_MILESTONE:M02_AFTER_getProcessDispatchTable");

    fprintf(stderr,
            "PM_LS_DISPATCH_TABLE:pointer=0x%08lx nonzero=%s\n",
            (unsigned long)(uintptr_t)dispatch_table,
            dispatch_table != NULL ? "YES" : "NO");
    fflush(stderr);

    if (dispatch_table == NULL) {
        marker("PM_LS_DISPATCH_RESULT:DISPATCH_TABLE_NULL");
        return 23;
    }

    marker("PM_LS_DISPATCH_MILESTONE:M03_BEFORE_getProcessesServerPort");
    server_port = get_server_port();
    marker("PM_LS_DISPATCH_MILESTONE:M04_AFTER_getProcessesServerPort");

    fprintf(stderr,
            "PM_LS_DISPATCH_SERVER_PORT:port=0x%08lx nonzero=%s\n",
            (unsigned long)server_port,
            server_port != MACH_PORT_NULL ? "YES" : "NO");
    fflush(stderr);

    if (server_port == MACH_PORT_NULL) {
        marker("PM_LS_DISPATCH_RESULT:SERVER_PORT_NULL");
        return 24;
    }

    marker("PM_LS_DISPATCH_RESULT:DISPATCH_SETUP_PASS");
    marker("PM_LS_DISPATCH_MILESTONE:M05_SUCCESS");
    return 0;
}
