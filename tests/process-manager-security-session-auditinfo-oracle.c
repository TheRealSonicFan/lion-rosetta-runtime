#include <Security/AuthSession.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int getaudit_addr(void *, int);

#define AUDITINFO_ADDR_SIZE 0x30U
#define AUDITINFO_ASID_OFF  0x24U
#define AUDITINFO_FLAGS_OFF 0x28U

static uint32_t
get_u32(const unsigned char *p)
{
    uint32_t v;
    memcpy(&v, p, sizeof(v));
    return v;
}

static const char *
arch_name(void)
{
#if defined(__ppc__) || defined(__POWERPC__)
    return "ppc";
#elif defined(__i386__)
    return "i386";
#elif defined(__x86_64__)
    return "x86_64";
#else
    return "unknown";
#endif
}

static int
read_auditinfo(uint32_t *asid, uint32_t *flags)
{
    uint32_t storage[AUDITINFO_ADDR_SIZE / sizeof(uint32_t)];
    unsigned char *buf = (unsigned char *)storage;
    int rc;
    int saved_errno;

    memset(storage, 0, sizeof(storage));
    errno = 0;
    rc = getaudit_addr(buf, (int)AUDITINFO_ADDR_SIZE);
    saved_errno = errno;

    fprintf(stderr,
            "PM_SECURITY_AUDITINFO_GET:arch=%s rc=%d errno=%d size=0x%02lx word24=0x%08lx word28=0x%08lx\n",
            arch_name(),
            rc,
            saved_errno,
            (unsigned long)AUDITINFO_ADDR_SIZE,
            (unsigned long)get_u32(buf + AUDITINFO_ASID_OFF),
            (unsigned long)get_u32(buf + AUDITINFO_FLAGS_OFF));
    fflush(stderr);

    if (rc != 0)
        return 0;

    if (asid != NULL)
        *asid = get_u32(buf + AUDITINFO_ASID_OFF);
    if (flags != NULL)
        *flags = get_u32(buf + AUDITINFO_FLAGS_OFF);
    return 1;
}

static int
run_audit_only(void)
{
    uint32_t asid = 0;
    uint32_t flags = 0;

    if (!read_auditinfo(&asid, &flags)) {
        fprintf(stderr, "PM_SECURITY_AUDITINFO_RESULT:AUDIT_READ_ERROR\n");
        return 20;
    }

    fprintf(stderr,
            "PM_SECURITY_AUDITINFO_VALUE:ASID=0x%08lx FLAGS=0x%08lx\n",
            (unsigned long)asid,
            (unsigned long)flags);
    fprintf(stderr, "PM_SECURITY_AUDITINFO_RESULT:AUDIT_ONLY_PASS\n");
    fflush(stderr);
    return 0;
}

static int
run_session_audit(int require_attribute_match)
{
    SecuritySessionId sid = noSecuritySession;
    SessionAttributeBits attrs = 0;
    OSStatus status;
    uint32_t asid = 0;
    uint32_t flags = 0;
    int audit_ok;

    status = SessionGetInfo(callerSecuritySession, &sid, &attrs);
    fprintf(stderr,
            "PM_SECURITY_AUDITINFO_SESSION:status=%ld id=0x%08lx attrs=0x%08lx\n",
            (long)status,
            (unsigned long)sid,
            (unsigned long)attrs);
    fflush(stderr);

    audit_ok = read_auditinfo(&asid, &flags);
    if (!audit_ok) {
        fprintf(stderr, "PM_SECURITY_AUDITINFO_RESULT:AUDIT_READ_ERROR\n");
        return 21;
    }

    fprintf(stderr,
            "PM_SECURITY_AUDITINFO_COMPARE:sessionIdMatch=%s attrsMatch=%s\n",
            ((uint32_t)sid == asid) ? "YES" : "NO",
            ((uint32_t)attrs == flags) ? "YES" : "NO");
    fflush(stderr);

    if (status != noErr) {
        fprintf(stderr, "PM_SECURITY_AUDITINFO_RESULT:SESSION_ERROR\n");
        return 22;
    }
    if ((uint32_t)sid != asid) {
        fprintf(stderr, "PM_SECURITY_AUDITINFO_RESULT:SESSION_ID_MAPPING_MISMATCH\n");
        return 23;
    }

    if (require_attribute_match && (uint32_t)attrs != flags) {
        fprintf(stderr, "PM_SECURITY_AUDITINFO_RESULT:ATTRIBUTE_MAPPING_MISMATCH\n");
        return 23;
    }

    fprintf(stderr,
            "PM_SECURITY_AUDITINFO_RESULT:%s\n",
            require_attribute_match ?
                "SESSION_AUDIT_MATCH" :
                "SESSION_ID_AUDIT_MATCH");
    fflush(stderr);
    return 0;
}

int
main(int argc, char **argv)
{
    fprintf(stderr, "PM_SECURITY_AUDITINFO_MILESTONE:M00_MAIN_ENTER arch=%s\n",
            arch_name());
    fflush(stderr);

    if (argc != 2) {
        fprintf(stderr, "PM_SECURITY_AUDITINFO_RESULT:MODE_REQUIRED\n");
        return 24;
    }

    if (strcmp(argv[1], "audit-only") == 0)
        return run_audit_only();
    if (strcmp(argv[1], "session-id-audit") == 0)
        return run_session_audit(0);
    if (strcmp(argv[1], "session-audit") == 0)
        return run_session_audit(1);

    fprintf(stderr, "PM_SECURITY_AUDITINFO_RESULT:UNKNOWN_MODE\n");
    return 25;
}
