#include <CoreFoundation/CoreFoundation.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BUILD_ID "hitoolbox-extras-resource-compat-v1"
#define BUILD_MARKER "PM_HITOOLBOX_EXTRAS_COMPAT_BUILD_ID:" BUILD_ID

#define MODE_ENV "ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE"
#define PATH_ENV "ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH"
#define MODE_SNOW_FORCE "snow-force-external-v1"
#define MODE_LION_FALLBACK "lion-fallback-external-v1"

typedef CFURLRef (*copy_resource_url_fn)(CFBundleRef,
                                         CFStringRef,
                                         CFStringRef,
                                         CFStringRef,
                                         CFStringRef);

struct interpose_tuple {
    const void *replacement;
    const void *replacee;
};

static struct interpose_tuple sResourceLookupInterpose;
static copy_resource_url_fn gOriginal = NULL;
static unsigned int gTargetCount = 0;
static int gResolutionLogged = 0;

static CFURLRef
rosetta_CFBundleCopyResourceURLForLocalization(CFBundleRef bundle,
                                               CFStringRef resourceName,
                                               CFStringRef resourceType,
                                               CFStringRef subDirName,
                                               CFStringRef localizationName);

static int
cfstring_equals(CFStringRef value, CFStringRef expected)
{
    if (value == NULL || expected == NULL)
        return 0;
    if (CFGetTypeID(value) != CFStringGetTypeID())
        return 0;
    return CFEqual(value, expected) ? 1 : 0;
}

static copy_resource_url_fn
original_function(void)
{
    if (gOriginal == NULL) {
        gOriginal = (copy_resource_url_fn)
            (uintptr_t)sResourceLookupInterpose.replacee;
    }

    if (!gResolutionLogged) {
        fprintf(stderr,
                "PM_HITOOLBOX_EXTRAS_COMPAT_ORIGINAL:source=interpose_replacee original=0x%08lx replacement=0x%08lx\n",
                (unsigned long)(uintptr_t)gOriginal,
                (unsigned long)(uintptr_t)&rosetta_CFBundleCopyResourceURLForLocalization);
        fflush(stderr);
        gResolutionLogged = 1;
    }

    return gOriginal;
}

static CFURLRef
external_resource_url(void)
{
    const char *path = getenv(PATH_ENV);

    if (path == NULL || path[0] != '/') {
        fprintf(stderr,
                "PM_HITOOLBOX_EXTRAS_COMPAT_EXTERNAL:result=INVALID_PATH\n");
        fflush(stderr);
        return NULL;
    }

    return CFURLCreateFromFileSystemRepresentation(
        kCFAllocatorDefault,
        (const UInt8 *)path,
        (CFIndex)strlen(path),
        (Boolean)0);
}

static CFURLRef
rosetta_CFBundleCopyResourceURLForLocalization(CFBundleRef bundle,
                                               CFStringRef resourceName,
                                               CFStringRef resourceType,
                                               CFStringRef subDirName,
                                               CFStringRef localizationName)
{
    copy_resource_url_fn fn = original_function();
    CFStringRef identifier = NULL;
    CFURLRef original = NULL;
    CFURLRef fallback = NULL;
    const char *mode;
    int exact = 0;

    if (fn == NULL ||
        fn == (copy_resource_url_fn)&rosetta_CFBundleCopyResourceURLForLocalization) {
        fprintf(stderr,
                "PM_HITOOLBOX_EXTRAS_COMPAT_RESULT:original=UNAVAILABLE\n");
        fflush(stderr);
        return NULL;
    }

    if (bundle != NULL)
        identifier = CFBundleGetIdentifier(bundle);

    exact =
        cfstring_equals(identifier, CFSTR("com.apple.HIToolbox")) &&
        cfstring_equals(resourceName, CFSTR("Extras")) &&
        cfstring_equals(resourceType, CFSTR("rsrc")) &&
        subDirName == NULL &&
        localizationName == NULL;

    if (!exact)
        return fn(bundle, resourceName, resourceType,
                  subDirName, localizationName);

    ++gTargetCount;
    mode = getenv(MODE_ENV);

    fprintf(stderr, "%s\n", BUILD_MARKER);
    fprintf(stderr,
            "PM_HITOOLBOX_EXTRAS_COMPAT_TARGET:index=%u mode=%s bundle=com.apple.HIToolbox name=Extras type=rsrc subdir=NULL localization=NULL caller=0x%08lx\n",
            gTargetCount,
            mode ? mode : "(unset)",
            (unsigned long)(uintptr_t)__builtin_return_address(0));
    fflush(stderr);

    if (mode != NULL && strcmp(mode, MODE_SNOW_FORCE) == 0) {
        fallback = external_resource_url();
        fprintf(stderr,
                "PM_HITOOLBOX_EXTRAS_COMPAT_RESULT:index=%u mode=%s original=SKIPPED fallback=%s\n",
                gTargetCount,
                MODE_SNOW_FORCE,
                fallback != NULL ? "NONNULL" : "NULL");
        fflush(stderr);
        return fallback;
    }

    original = fn(bundle, resourceName, resourceType,
                  subDirName, localizationName);

    if (mode != NULL && strcmp(mode, MODE_LION_FALLBACK) == 0) {
        if (original != NULL) {
            fprintf(stderr,
                    "PM_HITOOLBOX_EXTRAS_COMPAT_RESULT:index=%u mode=%s original=NONNULL fallback=NOT_USED\n",
                    gTargetCount,
                    MODE_LION_FALLBACK);
            fflush(stderr);
            return original;
        }

        fallback = external_resource_url();
        fprintf(stderr,
                "PM_HITOOLBOX_EXTRAS_COMPAT_RESULT:index=%u mode=%s original=NULL fallback=%s\n",
                gTargetCount,
                MODE_LION_FALLBACK,
                fallback != NULL ? "NONNULL" : "NULL");
        fflush(stderr);
        return fallback;
    }

    fprintf(stderr,
            "PM_HITOOLBOX_EXTRAS_COMPAT_RESULT:index=%u mode=%s original=%s fallback=DISABLED\n",
            gTargetCount,
            mode ? mode : "(unset)",
            original != NULL ? "NONNULL" : "NULL");
    fflush(stderr);
    return original;
}

__attribute__((used))
static struct interpose_tuple sResourceLookupInterpose
__attribute__((section("__DATA,__interpose"))) = {
    (const void *)(uintptr_t)&rosetta_CFBundleCopyResourceURLForLocalization,
    (const void *)(uintptr_t)&CFBundleCopyResourceURLForLocalization
};
