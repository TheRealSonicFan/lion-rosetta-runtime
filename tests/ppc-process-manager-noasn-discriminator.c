#include <Carbon/Carbon.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

#define MILESTONE_LOG_PATH "/tmp/rosetta-processmanager-noasn-milestone.log"

static void
append_line(const char *line)
{
    int fd;
    size_t len;

    if (line == NULL)
        return;

    len = strlen(line);
    (void)write(STDERR_FILENO, line, len);

    fd = open(MILESTONE_LOG_PATH, O_WRONLY | O_CREAT | O_APPEND, 0600);
    if (fd >= 0) {
        (void)write(fd, line, len);
        (void)close(fd);
    }
}

#define MILESTONE(name) append_line("PM_NOASN_MILESTONE:" name "\n")

static void
log_status(const char *name, OSStatus status)
{
    char line[256];
    snprintf(line, sizeof(line), "PM_NOASN_STATUS:%s=%ld\n", name, (long)status);
    append_line(line);
}

static void
log_psn(const ProcessSerialNumber *psn)
{
    char line[256];
    snprintf(line, sizeof(line),
             "PM_NOASN_PSN:0x%08lx:0x%08lx\n",
             (unsigned long)psn->highLongOfPSN,
             (unsigned long)psn->lowLongOfPSN);
    append_line(line);
}

static void
log_pid(pid_t pid)
{
    char line[256];
    snprintf(line, sizeof(line), "PM_NOASN_PID:%ld\n", (long)pid);
    append_line(line);
}

static void
log_env(void)
{
    const char *value = getenv("LSDONOTABORTIFNOASN");
    char line[256];

    snprintf(line, sizeof(line),
             "PM_NOASN_ENV:LSDONOTABORTIFNOASN=%s\n",
             value != NULL ? value : "(unset)");
    append_line(line);
}

int
main(void)
{
    ProcessSerialNumber psn = { 0, 0 };
    OSStatus status;
    pid_t self = getpid();
    const char *override = getenv("LSDONOTABORTIFNOASN");

    MILESTONE("M00_MAIN_ENTER");
    log_pid(self);
    log_env();

    if (override == NULL || strcmp(override, "0") != 0) {
        append_line("PM_NOASN_FAILURE:OVERRIDE_NOT_ZERO\n");
        MILESTONE("M01_OVERRIDE_INVALID");
        return 40;
    }

    MILESTONE("M02_BEFORE_GetProcessForPID");
    status = GetProcessForPID(self, &psn);
    log_status("GetProcessForPID", status);
    MILESTONE("M03_AFTER_GetProcessForPID");
    log_psn(&psn);

    if (status != noErr) {
        append_line("PM_NOASN_RESULT:GetProcessForPID_RETURNED_ERROR\n");
        MILESTONE("M04_RETURNED_ERROR");
        return 31;
    }

    if (psn.highLongOfPSN == 0 && psn.lowLongOfPSN == 0) {
        append_line("PM_NOASN_RESULT:NOERR_ZERO_PSN\n");
        MILESTONE("M05_NOERR_ZERO_PSN");
        return 32;
    }

    append_line("PM_NOASN_RESULT:NOERR_NONZERO_PSN\n");
    MILESTONE("M06_NOERR_NONZERO_PSN");
    return 0;
}
