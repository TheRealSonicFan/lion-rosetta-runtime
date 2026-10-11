#include <CoreFoundation/CoreFoundation.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define BUILD_ID "hitoolbox-cfbundle-resource-trace-v1"
#define BUILD_MARKER "PM_HITOOLBOX_CFBUNDLE_TRACE_BUILD_ID:" BUILD_ID

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
                "PM_HITOOLBOX_CFBUNDLE_TRACE_ORIGINAL:source=interpose_replacee original=0x%08lx replacement=0x%08lx\n",
                (unsigned long)(uintptr_t)gOriginal,
                (unsigned long)(uintptr_t)&rosetta_CFBundleCopyResourceURLForLocalization);
        fflush(stderr);
        gResolutionLogged = 1;
    }

    return gOriginal;
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
    CFURLRef result;
    int exact = 0;

    if (bundle != NULL)
        identifier = CFBundleGetIdentifier(bundle);

    exact =
        cfstring_equals(identifier, CFSTR("com.apple.HIToolbox")) &&
        cfstring_equals(resourceName, CFSTR("Extras")) &&
        cfstring_equals(resourceType, CFSTR("rsrc")) &&
        subDirName == NULL &&
        localizationName == NULL;

    if (exact) {
        ++gTargetCount;
        fprintf(stderr, "%s\n", BUILD_MARKER);
        fprintf(stderr,
                "PM_HITOOLBOX_CFBUNDLE_TRACE_TARGET:index=%u bundle=com.apple.HIToolbox name=Extras type=rsrc subdir=NULL localization=NULL caller=0x%08lx\n",
                gTargetCount,
                (unsigned long)(uintptr_t)__builtin_return_address(0));
        fflush(stderr);
    }

    if (fn == NULL ||
        fn == (copy_resource_url_fn)&rosetta_CFBundleCopyResourceURLForLocalization) {
        if (exact) {
            fprintf(stderr,
                    "PM_HITOOLBOX_CFBUNDLE_TRACE_RESULT:index=%u original=UNAVAILABLE\n",
                    gTargetCount);
            fflush(stderr);
        }
        return NULL;
    }

    result = fn(bundle, resourceName, resourceType, subDirName, localizationName);

    if (exact) {
        unsigned char path[4096];
        Boolean have_path = false;

        path[0] = '\0';
        if (result != NULL) {
            have_path = CFURLGetFileSystemRepresentation(
                result, (Boolean)1, path, (CFIndex)sizeof(path));
        }

        fprintf(stderr,
                "PM_HITOOLBOX_CFBUNDLE_TRACE_RESULT:index=%u url=%s path=%s\n",
                gTargetCount,
                result != NULL ? "NONNULL" : "NULL",
                (result != NULL && have_path) ? (const char *)path : "(unavailable)");
        fflush(stderr);
    }

    return result;
}

__attribute__((used))
static struct interpose_tuple sResourceLookupInterpose
__attribute__((section("__DATA,__interpose"))) = {
    (const void *)(uintptr_t)&rosetta_CFBundleCopyResourceURLForLocalization,
    (const void *)(uintptr_t)&CFBundleCopyResourceURLForLocalization
};
