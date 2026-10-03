#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

int
main(void)
{
    const char *expected = "Rosetta CoreFoundation";
    char buffer[128];
    const void *values[1];
    CFStringRef string;
    CFArrayRef array;
    CFIndex length;
    CFIndex count;
    Boolean converted;

    string = CFStringCreateWithCString(NULL, expected, kCFStringEncodingUTF8);
    if (string == NULL) {
        fprintf(stderr, "CoreFoundation probe: CFStringCreateWithCString failed\n");
        return 2;
    }

    length = CFStringGetLength(string);
    memset(buffer, 0, sizeof(buffer));
    converted = CFStringGetCString(string, buffer, sizeof(buffer), kCFStringEncodingUTF8);
    if (!converted) {
        fprintf(stderr, "CoreFoundation probe: CFStringGetCString failed\n");
        CFRelease(string);
        return 3;
    }

    values[0] = string;
    array = CFArrayCreate(NULL, values, 1, &kCFTypeArrayCallBacks);
    if (array == NULL) {
        fprintf(stderr, "CoreFoundation probe: CFArrayCreate failed\n");
        CFRelease(string);
        return 4;
    }

    count = CFArrayGetCount(array);

    printf("Rosetta PPC CoreFoundation smoke test: pid=%ld length=%ld count=%ld value=%s\n",
           (long)getpid(), (long)length, (long)count, buffer);

    CFRelease(array);
    CFRelease(string);

    if (strcmp(buffer, expected) != 0 || count != 1 || length <= 0) {
        fprintf(stderr, "CoreFoundation probe: validation mismatch\n");
        return 5;
    }

    return 0;
}
