#include <Security/AuthSession.h>
#include <bsm/audit.h>
#include <errno.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define COMPAT_BUILD_ID "security-session-auditinfo-api-v1"
#define COMPAT_BUILD_MARKER "PM_SECURITY_SESSION_API_COMPAT_BUILD_ID:" COMPAT_BUILD_ID
#define COMPAT_MODE_ENV "ROSETTA_SECURITY_SESSION_API_COMPAT_MODE"
#define COMPAT_MODE_PASSTHROUGH "passthrough"
#define COMPAT_MODE_LION_AUDITINFO "lion-auditinfo-v1"

typedef char auditinfo_size_must_be_0x30[
    sizeof(auditinfo_addr_t) == 0x30 ? 1 : -1];
typedef char auditinfo_asid_offset_must_be_0x24[
    offsetof(auditinfo_addr_t, ai_asid) == 0x24 ? 1 : -1];
typedef char auditinfo_flags_offset_must_be_0x28[
    offsetof(auditinfo_addr_t, ai_flags) == 0x28 ? 1 : -1];

typedef OSStatus (*session_get_info_fn)(SecuritySessionId,
                                        SecuritySessionId *,
                                        SessionAttributeBits *);

struct interpose_tuple {
    const void *replacement;
    const void *replacee;
};

static OSStatus rosetta_session_get_info(SecuritySessionId,
                                         SecuritySessionId *,
                                         SessionAttributeBits *);

static struct interpose_tuple sInterpose;

static unsigned int gCallCount = 0;

static uint32_t
get_u32(const unsigned char *p)
{
    uint32_t value;
    memcpy(&value, p, sizeof(value));
    return value;
}

static session_get_info_fn
original_session_get_info(void)
{
    return (session_get_info_fn)(uintptr_t)sInterpose.replacee;
}

static OSStatus
call_original(SecuritySessionId requested,
              SecuritySessionId *session_id,
              SessionAttributeBits *attributes)
{
    session_get_info_fn fn = original_session_get_info();
    OSStatus status;

    if (fn == NULL || fn == (session_get_info_fn)&rosetta_session_get_info)
        return (OSStatus)1;

    status = fn(requested, session_id, attributes);

    fprintf(stderr,
            "PM_SECURITY_SESSION_API_COMPAT_PASSTHROUGH_RETURN:status=%ld id=0x%08lx attrs=0x%08lx\n",
            (long)status,
            (unsigned long)((session_id != NULL) ? *session_id : 0),
            (unsigned long)((attributes != NULL) ? *attributes : 0));
    fflush(stderr);

    return status;
}

static OSStatus
rosetta_session_get_info(SecuritySessionId requested,
                         SecuritySessionId *session_id,
                         SessionAttributeBits *attributes)
{
    const char *mode;
    auditinfo_addr_t info;
    unsigned char *raw = (unsigned char *)&info;
    int rc;
    int saved_errno;
    uint32_t raw_word28;
    uint32_t raw_word2c;
    uint32_t asid;
    uint32_t flags_high;
    uint32_t flags_low;
    int target;

    ++gCallCount;
    mode = getenv(COMPAT_MODE_ENV);
    target = requested == callerSecuritySession;

    fprintf(stderr, "%s\n", COMPAT_BUILD_MARKER);
    fprintf(stderr,
            "PM_SECURITY_SESSION_API_COMPAT_CALL:index=%u mode=%s requested=0x%08lx targetCaller=%s\n",
            gCallCount,
            mode ? mode : "(unset)",
            (unsigned long)requested,
            target ? "YES" : "NO");
    fflush(stderr);

    if (!target) {
        fprintf(stderr,
                "PM_SECURITY_SESSION_API_COMPAT_NON_TARGET:PASSTHROUGH\n");
        fflush(stderr);
        return call_original(requested, session_id, attributes);
    }

    if (mode != NULL && strcmp(mode, COMPAT_MODE_PASSTHROUGH) == 0)
        return call_original(requested, session_id, attributes);

    if (mode == NULL || strcmp(mode, COMPAT_MODE_LION_AUDITINFO) != 0) {
        fprintf(stderr,
                "PM_SECURITY_SESSION_API_COMPAT_RESULT:MODE_REJECTED\n");
        fflush(stderr);
        return (OSStatus)1;
    }

    memset(&info, 0, sizeof(info));
    errno = 0;
    rc = getaudit_addr(&info, (int)sizeof(info));
    saved_errno = errno;

    raw_word28 = get_u32(raw + 0x28);
    raw_word2c = get_u32(raw + 0x2c);
    asid = (uint32_t)info.ai_asid;
    flags_high = (uint32_t)(((uint64_t)info.ai_flags) >> 32);
    flags_low = (uint32_t)((uint64_t)info.ai_flags);

    fprintf(stderr,
            "PM_SECURITY_SESSION_API_COMPAT_LAYOUT:size=0x%02lx asidOffset=0x%02lx flagsOffset=0x%02lx flagsSize=0x%02lx\n",
            (unsigned long)sizeof(info),
            (unsigned long)offsetof(auditinfo_addr_t, ai_asid),
            (unsigned long)offsetof(auditinfo_addr_t, ai_flags),
            (unsigned long)sizeof(info.ai_flags));
    fprintf(stderr,
            "PM_SECURITY_SESSION_API_COMPAT_AUDIT:rc=%d errno=%d rawWord28=0x%08lx rawWord2c=0x%08lx asid=0x%08lx flagsHigh=0x%08lx flagsLow=0x%08lx\n",
            rc,
            saved_errno,
            (unsigned long)raw_word28,
            (unsigned long)raw_word2c,
            (unsigned long)asid,
            (unsigned long)flags_high,
            (unsigned long)flags_low);
    fflush(stderr);

    if (rc != 0) {
        fprintf(stderr,
                "PM_SECURITY_SESSION_API_COMPAT_RESULT:AUDIT_READ_ERROR\n");
        fflush(stderr);
        return (OSStatus)1;
    }

    if (session_id != NULL)
        *session_id = (SecuritySessionId)asid;
    if (attributes != NULL)
        *attributes = (SessionAttributeBits)flags_low;

    fprintf(stderr,
            "PM_SECURITY_SESSION_API_COMPAT_RESULT:ADAPTER_PASS id=0x%08lx attrs=0x%08lx\n",
            (unsigned long)asid,
            (unsigned long)flags_low);
    fflush(stderr);

    return noErr;
}

__attribute__((used))
static struct interpose_tuple sInterpose
__attribute__((section("__DATA,__interpose"))) = {
    (const void *)(uintptr_t)&rosetta_session_get_info,
    (const void *)(uintptr_t)&SessionGetInfo
};
