#include <mach/mach.h>
#include <mach/mig_errors.h>
#include <mach/ndr.h>
#include <servers/bootstrap.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>

extern kern_return_t bootstrap_look_up2(mach_port_t,
                                         const char *,
                                         mach_port_t *,
                                         pid_t,
                                         uint64_t);
extern mach_port_t mig_get_reply_port(void);

#if defined(PM_CGS_SYNCHRONIZE_WINDOW_BACKING_STORE_COMPAT_INTEGRATION) && \
    defined(PM_CGS_SHAPEWINDOW_INLINE_COMPAT_INTEGRATION) && \
    defined(PM_CPS_REGISTRATION_CARBON_SMOKETEST_COMPAT) && \
    defined(PM_CGS_SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_INTEGRATION)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-carbon-smoketest-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-shapewindow-inline-backing-sync-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-selectwindow-orderfront-compat-v6"
#elif defined(PM_CGS_SHAPEWINDOW_INLINE_COMPAT_INTEGRATION) && \
    defined(PM_CPS_REGISTRATION_CARBON_SMOKETEST_COMPAT) && \
    defined(PM_CGS_SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_INTEGRATION)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-carbon-smoketest-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-shapewindow-inline-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-selectwindow-orderfront-compat-v5"
#elif defined(PM_CPS_REGISTRATION_CARBON_SMOKETEST_COMPAT) && \
    defined(PM_CGS_SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_INTEGRATION)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-carbon-smoketest-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-selectwindow-orderfront-compat-v4"
#elif defined(PM_CGS_SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_INTEGRATION) || \
    defined(PM_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_INTEGRATION) || \
    defined(PM_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_INTEGRATION)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-selectwindow-orderfront-compat-v3"
#elif defined(PM_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-trace-v1"
#elif defined(PM_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_INTEGRATION)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-compat-v1"
#elif defined(PM_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_INTEGRATION)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-compat-v1"
#elif defined(PM_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_INTEGRATION)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-compat-v1"
#elif defined(PM_CGS_SHOWWINDOW_UNKNOWN_TRACE)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-unknown-trace-v1"
#elif defined(PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_INTEGRATION)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-v1"
#elif defined(PM_CGS_POST_RELEASEBACKING_OPACITY_TRACE)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-trace-v1"
#elif defined(PM_CGS_RELEASEBACKING_COMPAT_INTEGRATION)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-v1"
#elif defined(PM_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-trace-v1"
#elif defined(PM_CGS_NEWWINDOW_COMPAT_INTEGRATION)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-v1"
#elif defined(PM_CGS_NEWWINDOW_TRACE)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-trace-v1"
#elif defined(PM_DISTRIBUTED_NOTIFICATIONS_INGRESS_INTEGRATION)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-v1"
#elif defined(PM_DISTRIBUTED_NOTIFICATIONS_COMPAT_PROTOCOL)
#define COMPAT_BUILD_ID "distributed-notifications-bootstrap-compat-protocol-v1"
#elif defined(PM_CPS_SETFRONT_COMPAT_INTEGRATION)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-v1"
#elif defined(PM_CPS_SETFRONT_COMPAT_PROTOCOL)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-protocol-v1"
#elif defined(PM_CPS_SETFRONT_TRACE)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-trace-v1"
#elif defined(PM_CPS_REGISTRATION_COMPAT_INTEGRATION)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-v1"
#elif defined(PM_CPS_REGISTRATION_TRACE)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-trace-v1"
#elif defined(PM_CGS_SERVER_VERSION_COMPAT_INTEGRATION)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-v1"
#elif defined(PM_CGS_CONNECTION_TRACE)
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5-cgs-trace-v2"
#else
#define COMPAT_BUILD_ID "dual-bootstrap-servercheckin-sessioninit-v5"
#endif
#define COMPAT_BUILD_MARKER "PM_CORESERVICES_COMPAT_BUILD_ID:" COMPAT_BUILD_ID
#define COMPAT_MODE_ENV "ROSETTA_CORESERVICES_COMPAT_MODE"
#define COMPAT_MODE_PASSTHROUGH "passthrough"
#define COMPAT_MODE_LION_DUAL "lion-dual-adapter"
#define COMPAT_MODE_LION_SESSIONINIT "lion-dual-sessioninit-adapter"

#if defined(PM_DISTRIBUTED_NOTIFICATIONS_COMPAT_PROTOCOL) || \
    defined(PM_DISTRIBUTED_NOTIFICATIONS_INGRESS_INTEGRATION)
static const char kDistributedNotificationsName[] =
    "com.apple.distributed_notifications.2";
#endif

#ifdef PM_DISTRIBUTED_NOTIFICATIONS_COMPAT_PROTOCOL
#define DISTNOTIFY_COMPAT_ENV "ROSETTA_DISTRIBUTED_NOTIFICATIONS_COMPAT_MODE"
#define DISTNOTIFY_COMPAT_PASSTHROUGH "passthrough"
#define DISTNOTIFY_COMPAT_LION_V1 "lion-lookup-v1"
#endif

#if defined(PM_CPS_SETFRONT_COMPAT_INTEGRATION) && !defined(PM_CPS_SETFRONT_COMPAT_PROTOCOL)
#define PM_CPS_SETFRONT_COMPAT_PROTOCOL 1
#endif

#if defined(PM_CGS_SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_INTEGRATION) && !defined(PM_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_INTEGRATION)
#define PM_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_INTEGRATION 1
#endif

#if defined(PM_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_INTEGRATION) && !defined(PM_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_INTEGRATION)
#define PM_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_INTEGRATION 1
#endif

#if defined(PM_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_INTEGRATION) && !defined(PM_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_TRACE)
#define PM_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_TRACE 1
#endif

#if defined(PM_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_INTEGRATION) && !defined(PM_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE)
#define PM_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE 1
#endif

#if defined(PM_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE) && !defined(PM_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_INTEGRATION)
#define PM_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_INTEGRATION 1
#endif

#if defined(PM_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_INTEGRATION) && !defined(PM_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_INTEGRATION)
#define PM_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_INTEGRATION 1
#endif

#if defined(PM_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_INTEGRATION) && !defined(PM_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_INTEGRATION)
#define PM_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_INTEGRATION 1
#endif

#if defined(PM_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_INTEGRATION) && !defined(PM_CGS_SHOWWINDOW_UNKNOWN_TRACE)
#define PM_CGS_SHOWWINDOW_UNKNOWN_TRACE 1
#endif

#if defined(PM_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_INTEGRATION) && !defined(PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_INTEGRATION)
#define PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_INTEGRATION 1
#endif

#if defined(PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_INTEGRATION) && !defined(PM_CGS_POST_RELEASEBACKING_OPACITY_TRACE)
#define PM_CGS_POST_RELEASEBACKING_OPACITY_TRACE 1
#endif

#if defined(PM_CGS_POST_RELEASEBACKING_OPACITY_TRACE) && !defined(PM_CGS_RELEASEBACKING_COMPAT_INTEGRATION)
#define PM_CGS_RELEASEBACKING_COMPAT_INTEGRATION 1
#endif

#if defined(PM_CGS_RELEASEBACKING_COMPAT_INTEGRATION) && !defined(PM_CGS_NEWWINDOW_COMPAT_INTEGRATION)
#define PM_CGS_NEWWINDOW_COMPAT_INTEGRATION 1
#endif

#if defined(PM_CGS_NEWWINDOW_COMPAT_INTEGRATION) && !defined(PM_CGS_NEWWINDOW_TRACE)
#define PM_CGS_NEWWINDOW_TRACE 1
#endif

#if defined(PM_CGS_RELEASEBACKING_COMPAT_INTEGRATION) && !defined(PM_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE)
#define PM_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE 1
#endif

#if defined(PM_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE) && !defined(PM_CGS_CONNECTION_TRACE)
#define PM_CGS_CONNECTION_TRACE 1
#endif

#if defined(PM_CGS_SHOWWINDOW_UNKNOWN_TRACE) && !defined(PM_CGS_CONNECTION_TRACE)
#define PM_CGS_CONNECTION_TRACE 1
#endif

#ifdef PM_CGS_SHOWWINDOW_UNKNOWN_TRACE
#define CGS_SHOWWINDOW_UNKNOWN_TRACE_ENV "ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE"
#define CGS_SHOWWINDOW_UNKNOWN_TRACE_SNOW_V1 "snow-passive-v1"
#define CGS_SHOWWINDOW_UNKNOWN_TRACE_LION_V1 "lion-passive-v1"
#define CGS_SHOWWINDOW_UNKNOWN_TRACE_MAX 128U
#define CGS_SHOWWINDOW_UNKNOWN_TRACE_HEX_MAX 0x100U
#endif

#define LOOKUP_REQUEST_ID 0x00000194U
#define LOOKUP_REPLY_ID 0x000001f8U
#define LOOKUP_SEND_SIZE 0x000000bcU
#define LOOKUP_RECV_SIZE 0x0000006cU
#define LOOKUP_SUCCESS_SIZE 0x00000028U
#define LOOKUP_ERROR_SIZE 0x00000024U
#define LOOKUP_SERVICE_OFF 0x20U
#define LOOKUP_PID_OFF 0xa0U
#define LOOKUP_UUID_OFF 0xa4U
#define LOOKUP_FLAGS_OFF 0xb4U
#define LOOKUP_REPLY_DESC_COUNT_OFF 0x18U
#define LOOKUP_REPLY_PORT_OFF 0x1cU
#define LOOKUP_REPLY_RETCODE_OFF 0x20U
#define LOOKUP_MSG_OPTIONS 0x03000003U

#define CHECKIN_REQUEST_ID 0x00002710U
#define CHECKIN_REPLY_ID 0x00002774U
#define CHECKIN_LEGACY_BITS 0x80001513U
#define CHECKIN_LION_BITS 0x00001513U
#define CHECKIN_LEGACY_SEND_SIZE 0x00000028U
#define CHECKIN_LION_SEND_SIZE 0x00000018U
#define CHECKIN_RECV_SIZE 0x0000003cU
#define CHECKIN_SUCCESS_SIZE 0x00000034U
#define CHECKIN_REPLY_DESC_COUNT_OFF 0x18U
#define CHECKIN_REPLY_PORT_OFF 0x1cU
#define CHECKIN_REPLY_DISPOSITION_OFF 0x26U
#define CHECKIN_REPLY_TYPE_OFF 0x27U
#define CHECKIN_REPLY_OPTIONS_OFF 0x30U


#define SESSIONINIT_REQUEST_ID 0x00002712U
#define SESSIONINIT_REPLY_ID 0x00002776U
#define SESSIONINIT_BITS 0x00001513U
#define SESSIONINIT_LEGACY_SEND_SIZE 0x0000002cU
#define SESSIONINIT_LION_SEND_SIZE 0x00000028U
#define SESSIONINIT_RECV_SIZE 0x00000034U
#define SESSIONINIT_ERROR_SIZE 0x00000024U
#define SESSIONINIT_SUCCESS_SIZE 0x0000002cU
#define SESSIONINIT_NDR_OFF 0x18U
#define SESSIONINIT_LEGACY_PID_OFF 0x20U
#define SESSIONINIT_LEGACY_UID_OFF 0x24U
#define SESSIONINIT_LEGACY_LAYOUT_OFF 0x28U
#define SESSIONINIT_LION_UID_OFF 0x20U
#define SESSIONINIT_LION_LAYOUT_OFF 0x24U
#define SESSIONINIT_REPLY_RETCODE_OFF 0x20U

#define PRIVILEGED_SERVER_FLAG 0x0000000000000008ULL

#if defined(PM_CGS_CONNECTION_TRACE) || defined(PM_CGS_SERVER_VERSION_COMPAT_INTEGRATION)
#define CGS_SERVER_VERSION_REQUEST_ID 0x00007148U
#define CGS_SERVER_VERSION_REPLY_ID 0x000071acU
#define CGS_DEATHWATCH_REQUEST_ID 0x0000714cU
#define CGS_DEATHWATCH_REPLY_ID 0x000071b0U
#define CGS_NEW_CONNECTION_REQUEST_ID 0x00007469U
#define CGS_NEW_CONNECTION_REPLY_ID 0x000074cdU
#if defined(PM_CPS_REGISTRATION_TRACE) || defined(PM_CPS_REGISTRATION_COMPAT_INTEGRATION)
#define CGS_CHECKIN_APPLICATION_REQUEST_ID 0x00007372U
#define CGS_CHECKIN_APPLICATION_REPLY_ID 0x000073d6U
#define CGS_CREATE_APPLICATION_REQUEST_ID 0x000073c1U
#define CGS_CREATE_APPLICATION_REPLY_ID 0x00007425U
#endif
#ifdef PM_CPS_SETFRONT_TRACE
#define CGS_SET_FRONT_PROCESS_LEGACY_REQUEST_ID 0x0000729eU
#define CGS_SET_FRONT_PROCESS_LEGACY_REPLY_ID 0x00007302U
#define CGS_SET_FRONT_PROCESS_LION_REQUEST_ID 0x000072a1U
#define CGS_SET_FRONT_PROCESS_LION_REPLY_ID 0x00007305U
#endif
#ifdef PM_CGS_NEWWINDOW_TRACE
#define CGS_CREATE_WINDOW_INLINE_LEGACY_REQUEST_ID 0x00007394U
#define CGS_CREATE_WINDOW_INLINE_LEGACY_REPLY_ID 0x000073f8U
#define CGS_CREATE_WINDOW_INLINE_LION_REQUEST_ID 0x0000739aU
#define CGS_CREATE_WINDOW_INLINE_LION_REPLY_ID 0x000073feU
#endif
#ifdef PM_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE
#define CGS_SET_WINDOW_RELEASE_BACKING_LEGACY_REQUEST_ID 0x0000724bU
#define CGS_SET_WINDOW_RELEASE_BACKING_LEGACY_REPLY_ID 0x000072afU
#define CGS_SET_WINDOW_RELEASE_BACKING_LION_REQUEST_ID 0x0000724cU
#define CGS_SET_WINDOW_RELEASE_BACKING_LION_REPLY_ID 0x000072b0U
#endif
#ifdef PM_CGS_POST_RELEASEBACKING_OPACITY_TRACE
#define CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY_REQUEST_ID 0x0000724fU
#define CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY_REPLY_ID 0x000072b3U
#define CGS_CREATE_WINDOW_ALPHA_PLANE_LION_REQUEST_ID 0x00007250U
#define CGS_CREATE_WINDOW_ALPHA_PLANE_LION_REPLY_ID 0x000072b4U
#define CGS_TERMINATE_WINDOW_ALPHA_PLANE_LEGACY_REQUEST_ID 0x00007250U
#define CGS_TERMINATE_WINDOW_ALPHA_PLANE_LEGACY_REPLY_ID 0x000072b4U
#define CGS_TERMINATE_WINDOW_ALPHA_PLANE_LION_REQUEST_ID 0x00007251U
#define CGS_TERMINATE_WINDOW_ALPHA_PLANE_LION_REPLY_ID 0x000072b5U
#endif
#endif

#ifdef PM_CPS_REGISTRATION_COMPAT_INTEGRATION
#define CPS_REGISTRATION_COMPAT_ENV "ROSETTA_CPS_REGISTRATION_COMPAT_MODE"
#define CPS_REGISTRATION_COMPAT_PASSTHROUGH "passthrough"
#ifdef PM_CPS_REGISTRATION_CARBON_SMOKETEST_COMPAT
#define CPS_REGISTRATION_COMPAT_LION_V1 "lion-create-application-carbon-smoketest-v1"
#define CPS_REGISTRATION_LEGACY_SEND_SIZE 0x00000068U
#define CPS_REGISTRATION_LION_SEND_SIZE 0x00000074U
#define CPS_REGISTRATION_EXPECTED_STRING_LENGTH 0x00000026U
#define CPS_REGISTRATION_TAIL_BYTE_OFF 0x68U
#define CPS_REGISTRATION_TAIL_U32_0_OFF 0x6cU
#define CPS_REGISTRATION_TAIL_U32_1_OFF 0x70U
#else
#define CPS_REGISTRATION_COMPAT_LION_V1 "lion-create-application-v1"
#define CPS_REGISTRATION_LEGACY_SEND_SIZE 0x00000084U
#define CPS_REGISTRATION_LION_SEND_SIZE 0x00000090U
#define CPS_REGISTRATION_EXPECTED_STRING_LENGTH 0x00000043U
#define CPS_REGISTRATION_TAIL_BYTE_OFF 0x84U
#define CPS_REGISTRATION_TAIL_U32_0_OFF 0x88U
#define CPS_REGISTRATION_TAIL_U32_1_OFF 0x8cU
#endif
#define CPS_REGISTRATION_LEGACY_BITS 0x00001513U
#define CPS_REGISTRATION_MSG_OPTIONS 0x00000003U
#define CPS_REGISTRATION_RECV_SIZE 0x0000002cU
#define CPS_REGISTRATION_SUCCESS_REPLY_BITS 0x00001200U
#define CPS_REGISTRATION_SUCCESS_REPLY_SIZE 0x00000024U
#define CPS_REGISTRATION_NDR_OFF 0x18U
#define CPS_REGISTRATION_STRING_LENGTH_OFF 0x3cU
#define CPS_REGISTRATION_STRING_OFF 0x40U
#define CPS_REGISTRATION_REPLY_NDR_OFF 0x18U
#define CPS_REGISTRATION_REPLY_RESULT_OFF 0x20U
#define CPS_REGISTRATION_PRIVATE_BUFFER_SIZE 0x00000100U
#endif

#ifdef PM_CPS_SETFRONT_COMPAT_PROTOCOL
#define CPS_SETFRONT_COMPAT_ENV "ROSETTA_CPS_SETFRONT_COMPAT_MODE"
#define CPS_SETFRONT_COMPAT_PASSTHROUGH "passthrough"
#define CPS_SETFRONT_COMPAT_LION_V1 "lion-setfront-v1"
#define CPS_SETFRONT_LEGACY_BITS 0x00001513U
#define CPS_SETFRONT_MSG_OPTIONS 0x00000003U
#define CPS_SETFRONT_SEND_SIZE 0x00000030U
#define CPS_SETFRONT_RECV_SIZE 0x0000002cU
#define CPS_SETFRONT_SUCCESS_REPLY_BITS 0x00001200U
#define CPS_SETFRONT_SUCCESS_REPLY_SIZE 0x00000024U
#define CPS_SETFRONT_NDR_OFF 0x18U
#define CPS_SETFRONT_PSN_HIGH_OFF 0x20U
#define CPS_SETFRONT_PSN_LOW_OFF 0x24U
#define CPS_SETFRONT_ARG2_OFF 0x28U
#define CPS_SETFRONT_ARG3_OFF 0x2cU
#define CPS_SETFRONT_REPLY_NDR_OFF 0x18U
#define CPS_SETFRONT_REPLY_RESULT_OFF 0x20U
#define CPS_SETFRONT_PRIVATE_BUFFER_SIZE 0x00000040U
#endif

#ifdef PM_CGS_NEWWINDOW_COMPAT_INTEGRATION
#define CGS_NEWWINDOW_COMPAT_ENV "ROSETTA_CGS_NEWWINDOW_COMPAT_MODE"
#define CGS_NEWWINDOW_COMPAT_PASSTHROUGH "passthrough"
#define CGS_NEWWINDOW_COMPAT_LION_V1 "lion-inline-id-v1"
#define CGS_NEWWINDOW_LEGACY_BITS 0x00001513U
#define CGS_NEWWINDOW_MSG_OPTIONS 0x00000003U
#define CGS_NEWWINDOW_SEND_SIZE 0x00000068U
#define CGS_NEWWINDOW_RECV_SIZE 0x00000040U
#define CGS_NEWWINDOW_SUCCESS_REPLY_BITS 0x00001200U
#define CGS_NEWWINDOW_SUCCESS_REPLY_SIZE 0x00000038U
#define CGS_NEWWINDOW_ERROR_REPLY_SIZE 0x00000024U
#define CGS_NEWWINDOW_NDR_OFF 0x18U
#define CGS_NEWWINDOW_REPLY_RESULT_OFF 0x20U
#define CGS_NEWWINDOW_PRIVATE_BUFFER_SIZE 0x00000080U
#endif

#ifdef PM_CGS_RELEASEBACKING_COMPAT_INTEGRATION
#define CGS_RELEASEBACKING_COMPAT_ENV "ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE"
#define CGS_RELEASEBACKING_COMPAT_PASSTHROUGH "passthrough"
#define CGS_RELEASEBACKING_COMPAT_LION_V1 "lion-id-v1"
#define CGS_RELEASEBACKING_LEGACY_BITS 0x00001513U
#define CGS_RELEASEBACKING_MSG_OPTIONS 0x00000003U
#define CGS_RELEASEBACKING_SEND_SIZE 0x00000028U
#define CGS_RELEASEBACKING_RECV_SIZE 0x0000002cU
#define CGS_RELEASEBACKING_REPLY_BITS 0x00001200U
#define CGS_RELEASEBACKING_REPLY_SIZE 0x00000024U
#define CGS_RELEASEBACKING_NDR_OFF 0x18U
#define CGS_RELEASEBACKING_RESULT_OFF 0x20U
#define CGS_RELEASEBACKING_WINDOW_ID_OFF 0x20U
#define CGS_RELEASEBACKING_RELEASE_FLAG_OFF 0x24U
#define CGS_RELEASEBACKING_PRIVATE_BUFFER_SIZE 0x00000040U
#endif

#ifdef PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_INTEGRATION
#define CGS_OPACITY_ALPHA_CREATE_COMPAT_ENV "ROSETTA_CGS_OPACITY_ALPHA_CREATE_COMPAT_MODE"
#define CGS_OPACITY_ALPHA_CREATE_COMPAT_PASSTHROUGH "passthrough"
#define CGS_OPACITY_ALPHA_CREATE_COMPAT_LION_V1 "lion-id-v1"
#define CGS_OPACITY_ALPHA_CREATE_LEGACY_BITS 0x00001513U
#define CGS_OPACITY_ALPHA_CREATE_MSG_OPTIONS 0x00000003U
#define CGS_OPACITY_ALPHA_CREATE_SEND_SIZE 0x00000024U
#define CGS_OPACITY_ALPHA_CREATE_RECV_SIZE 0x0000002cU
#define CGS_OPACITY_ALPHA_CREATE_REPLY_BITS 0x00001200U
#define CGS_OPACITY_ALPHA_CREATE_REPLY_SIZE 0x00000024U
#define CGS_OPACITY_ALPHA_CREATE_NDR_OFF 0x18U
#define CGS_OPACITY_ALPHA_CREATE_RESULT_OFF 0x20U
#define CGS_OPACITY_ALPHA_CREATE_WINDOW_ID_OFF 0x20U
#define CGS_OPACITY_ALPHA_CREATE_PRIVATE_BUFFER_SIZE 0x00000040U
#endif

#ifdef PM_CGS_SHAPEWINDOW_INLINE_COMPAT_INTEGRATION
#define CGS_SHAPEWINDOW_INLINE_COMPAT_ENV "ROSETTA_CGS_SHAPEWINDOW_INLINE_COMPAT_MODE"
#define CGS_SHAPEWINDOW_INLINE_COMPAT_PASSTHROUGH "passthrough"
#define CGS_SHAPEWINDOW_INLINE_COMPAT_LION_V1 "lion-inline-id-v1"
#define CGS_SHAPEWINDOW_INLINE_LEGACY_REQUEST_ID 0x0000724dU
#define CGS_SHAPEWINDOW_INLINE_LEGACY_REPLY_ID 0x000072b1U
#define CGS_SHAPEWINDOW_INLINE_LION_REQUEST_ID 0x0000724eU
#define CGS_SHAPEWINDOW_INLINE_LION_REPLY_ID 0x000072b2U
#define CGS_SHAPEWINDOW_INLINE_BITS 0x00001513U
#define CGS_SHAPEWINDOW_INLINE_MSG_OPTIONS 0x00000003U
#define CGS_SHAPEWINDOW_INLINE_OBSERVED_SEND_SIZE 0x00000050U
#define CGS_SHAPEWINDOW_INLINE_RECV_SIZE 0x0000002cU
#define CGS_SHAPEWINDOW_INLINE_REPLY_BITS 0x00001200U
#define CGS_SHAPEWINDOW_INLINE_REPLY_SIZE 0x00000024U
#define CGS_SHAPEWINDOW_INLINE_NDR_OFF 0x18U
#define CGS_SHAPEWINDOW_INLINE_WINDOW_ID_OFF 0x20U
#define CGS_SHAPEWINDOW_INLINE_ARG1_OFF 0x24U
#define CGS_SHAPEWINDOW_INLINE_COUNT_OFF 0x28U
#define CGS_SHAPEWINDOW_INLINE_DATA_OFF 0x2cU
#define CGS_SHAPEWINDOW_INLINE_OBSERVED_COUNT 9U
#define CGS_SHAPEWINDOW_INLINE_RESULT_OFF 0x20U
#define CGS_SHAPEWINDOW_INLINE_PRIVATE_BUFFER_SIZE 0x00000080U
#endif

#ifdef PM_CGS_SYNCHRONIZE_WINDOW_BACKING_STORE_COMPAT_INTEGRATION
#define CGS_BACKING_SYNC_COMPAT_ENV "ROSETTA_CGS_SYNCHRONIZE_WINDOW_BACKING_STORE_COMPAT_MODE"
#define CGS_BACKING_SYNC_COMPAT_PASSTHROUGH "passthrough"
#define CGS_BACKING_SYNC_COMPAT_LION_V1 "lion-id-v1"
#define CGS_BACKING_SYNC_LEGACY_REQUEST_ID 0x00007265U
#define CGS_BACKING_SYNC_LEGACY_REPLY_ID 0x000072c9U
#define CGS_BACKING_SYNC_LION_REQUEST_ID 0x00007266U
#define CGS_BACKING_SYNC_LION_REPLY_ID 0x000072caU
#define CGS_BACKING_SYNC_BITS 0x00001513U
#define CGS_BACKING_SYNC_MSG_OPTIONS 0x00000003U
#define CGS_BACKING_SYNC_SEND_SIZE 0x0000002cU
#define CGS_BACKING_SYNC_RECV_SIZE 0x0000002cU
#define CGS_BACKING_SYNC_REPLY_BITS 0x00001200U
#define CGS_BACKING_SYNC_REPLY_SIZE 0x00000024U
#define CGS_BACKING_SYNC_NDR_OFF 0x18U
#define CGS_BACKING_SYNC_WINDOW_ID_OFF 0x20U
#define CGS_BACKING_SYNC_ARG1_OFF 0x24U
#define CGS_BACKING_SYNC_ARG2_OFF 0x28U
#define CGS_BACKING_SYNC_RESULT_OFF 0x20U
#define CGS_BACKING_SYNC_PRIVATE_BUFFER_SIZE 0x00000040U
#define CGS_BACKING_SYNC_MAX_EXACT_CALLS 32U
#endif

#ifdef PM_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_INTEGRATION
#define CGS_ADD_TRACKING_AREA_COMPAT_ENV "ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE"
#define CGS_ADD_TRACKING_AREA_COMPAT_PASSTHROUGH "passthrough"
#define CGS_ADD_TRACKING_AREA_COMPAT_LION_V1 "lion-inline-id-v1"
#define CGS_ADD_TRACKING_AREA_INLINE_LEGACY_REQUEST_ID 0x00007388U
#define CGS_ADD_TRACKING_AREA_INLINE_LEGACY_REPLY_ID 0x000073ecU
#define CGS_ADD_TRACKING_AREA_INLINE_LION_REQUEST_ID 0x0000738eU
#define CGS_ADD_TRACKING_AREA_INLINE_LION_REPLY_ID 0x000073f2U
#define CGS_ADD_TRACKING_AREA_LEGACY_BITS 0x00001513U
#define CGS_ADD_TRACKING_AREA_MSG_OPTIONS 0x00000003U
#define CGS_ADD_TRACKING_AREA_OBSERVED_SEND_SIZE 0x00000060U
#define CGS_ADD_TRACKING_AREA_RECV_SIZE 0x0000002cU
#define CGS_ADD_TRACKING_AREA_REPLY_BITS 0x00001200U
#define CGS_ADD_TRACKING_AREA_REPLY_SIZE 0x00000024U
#define CGS_ADD_TRACKING_AREA_NDR_OFF 0x18U
#define CGS_ADD_TRACKING_AREA_WINDOW_ID_OFF 0x20U
#define CGS_ADD_TRACKING_AREA_COUNT_OFF 0x24U
#define CGS_ADD_TRACKING_AREA_OBSERVED_COUNT 9U
#define CGS_ADD_TRACKING_AREA_RESULT_OFF 0x20U
#define CGS_ADD_TRACKING_AREA_PRIVATE_BUFFER_SIZE 0x00000080U
#endif

#ifdef PM_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_INTEGRATION
#define CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_ENV "ROSETTA_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE"
#define CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_PASSTHROUGH "passthrough"
#define CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_LION_V1 "lion-id-v1"
#define CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_LION_SELECTWINDOW_V1 "lion-selectwindow-id-v1"
#define CGS_ORDER_FRONT_CONDITIONALLY_LEGACY_REQUEST_ID 0x000072e7U
#define CGS_ORDER_FRONT_CONDITIONALLY_LEGACY_REPLY_ID 0x0000734bU
#define CGS_ORDER_FRONT_CONDITIONALLY_LION_REQUEST_ID 0x000072eaU
#define CGS_ORDER_FRONT_CONDITIONALLY_LION_REPLY_ID 0x0000734eU
#define CGS_ORDER_FRONT_CONDITIONALLY_BITS 0x00001513U
#define CGS_ORDER_FRONT_CONDITIONALLY_MSG_OPTIONS 0x00000003U
#define CGS_ORDER_FRONT_CONDITIONALLY_SEND_SIZE 0x00000034U
#define CGS_ORDER_FRONT_CONDITIONALLY_RECV_SIZE 0x0000002cU
#define CGS_ORDER_FRONT_CONDITIONALLY_REPLY_BITS 0x00001200U
#define CGS_ORDER_FRONT_CONDITIONALLY_REPLY_SIZE 0x00000024U
#define CGS_ORDER_FRONT_CONDITIONALLY_NDR_OFF 0x18U
#define CGS_ORDER_FRONT_CONDITIONALLY_ARG0_OFF 0x20U
#define CGS_ORDER_FRONT_CONDITIONALLY_ARG1_OFF 0x24U
#define CGS_ORDER_FRONT_CONDITIONALLY_WINDOW_ID_OFF 0x28U
#define CGS_ORDER_FRONT_CONDITIONALLY_ARG3_OFF 0x2cU
#define CGS_ORDER_FRONT_CONDITIONALLY_ARG4_OFF 0x30U
#define CGS_ORDER_FRONT_CONDITIONALLY_RESULT_OFF 0x20U
#define CGS_ORDER_FRONT_CONDITIONALLY_PRIVATE_BUFFER_SIZE 0x00000040U
#endif

#ifdef PM_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_INTEGRATION
#define CGS_SET_FRONT_WINDOW_COMPAT_ENV "ROSETTA_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE"
#define CGS_SET_FRONT_WINDOW_COMPAT_PASSTHROUGH "passthrough"
#define CGS_SET_FRONT_WINDOW_COMPAT_LION_V1 "lion-id-v1"
#define CGS_SET_FRONT_WINDOW_LEGACY_REQUEST_ID 0x000072f2U
#define CGS_SET_FRONT_WINDOW_LEGACY_REPLY_ID 0x00007356U
#define CGS_SET_FRONT_WINDOW_LION_REQUEST_ID 0x000072f5U
#define CGS_SET_FRONT_WINDOW_LION_REPLY_ID 0x00007359U
#define CGS_SET_FRONT_WINDOW_BITS 0x00001513U
#define CGS_SET_FRONT_WINDOW_MSG_OPTIONS 0x00000003U
#define CGS_SET_FRONT_WINDOW_SEND_SIZE 0x00000024U
#define CGS_SET_FRONT_WINDOW_RECV_SIZE 0x0000002cU
#define CGS_SET_FRONT_WINDOW_REPLY_BITS 0x00001200U
#define CGS_SET_FRONT_WINDOW_REPLY_SIZE 0x00000024U
#define CGS_SET_FRONT_WINDOW_NDR_OFF 0x18U
#define CGS_SET_FRONT_WINDOW_WINDOW_ID_OFF 0x20U
#define CGS_SET_FRONT_WINDOW_RESULT_OFF 0x20U
#define CGS_SET_FRONT_WINDOW_PRIVATE_BUFFER_SIZE 0x00000040U
#endif

#ifdef PM_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE
#define CGS_COLOR_PROFILE_CLIENT_LEGACY_REQUEST_ID 0x000074d4U
#define CGS_COLOR_PROFILE_CLIENT_LEGACY_REPLY_ID 0x00007538U
#define CGS_COLOR_PROFILE_CLIENT_LION_REQUEST_ID 0x000074d6U
#define CGS_COLOR_PROFILE_CLIENT_LION_REPLY_ID 0x0000753aU
#define CGS_COLOR_PROFILE_CLIENT_BITS 0x80001513U
#define CGS_COLOR_PROFILE_CLIENT_MSG_OPTIONS 0x00000003U
#define CGS_COLOR_PROFILE_CLIENT_SEND_SIZE 0x00000034U
#define CGS_COLOR_PROFILE_CLIENT_RECV_SIZE 0x00000030U
#define CGS_COLOR_PROFILE_CLIENT_SUCCESS_REPLY_SIZE 0x00000028U
#define CGS_COLOR_PROFILE_CLIENT_ERROR_REPLY_SIZE 0x00000024U
#define CGS_COLOR_PROFILE_CLIENT_DESC_COUNT_OFF 0x18U
#define CGS_COLOR_PROFILE_CLIENT_DESC_PORT_OFF 0x1cU
#define CGS_COLOR_PROFILE_CLIENT_DESC_DISPOSITION_OFF 0x26U
#define CGS_COLOR_PROFILE_CLIENT_DESC_TYPE_OFF 0x27U
#define CGS_COLOR_PROFILE_CLIENT_NDR_OFF 0x28U
#define CGS_COLOR_PROFILE_CLIENT_PID_OFF 0x30U
#define CGS_COLOR_PROFILE_CLIENT_RESULT_OFF 0x20U
#define CGS_COLOR_PROFILE_CLIENT_ID_OFF 0x24U
#define CGS_COLOR_PROFILE_CLIENT_REPLY_NDR_OFF 0x18U
#define CGS_COLOR_PROFILE_CLIENT_REPLY_BITS 0x00001200U
#define CGS_COLOR_PROFILE_CLIENT_PRIVATE_BUFFER_SIZE 0x00000040U
#endif

#ifdef PM_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_INTEGRATION
#define CGS_COLOR_PROFILE_CLIENT_COMPAT_ENV "ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE"
#define CGS_COLOR_PROFILE_CLIENT_COMPAT_PASSTHROUGH "passthrough"
#define CGS_COLOR_PROFILE_CLIENT_COMPAT_LION_V1 "lion-id-v1"
#endif

#ifdef PM_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_TRACE
#define CGS_COLOR_PROFILE_RESOLVE_TRACE_BUILD_ID "color-profile-resolve-passive-trace-v1"
#define CGS_COLOR_PROFILE_RESOLVE_TRACE_BUILD_MARKER "PM_CGS_COLOR_PROFILE_RESOLVE_TRACE_BUILD_ID:" CGS_COLOR_PROFILE_RESOLVE_TRACE_BUILD_ID
#define CGS_COLOR_PROFILE_RESOLVE_LEGACY_REQUEST_ID 0x000074d7U
#define CGS_COLOR_PROFILE_RESOLVE_LEGACY_REPLY_ID 0x0000753bU
#define CGS_COLOR_PROFILE_RESOLVE_LION_REQUEST_ID 0x000074d9U
#define CGS_COLOR_PROFILE_RESOLVE_LION_REPLY_ID 0x0000753dU
#define CGS_COLOR_PROFILE_RESOLVE_BITS 0x80001513U
#define CGS_COLOR_PROFILE_RESOLVE_MSG_OPTIONS 0x00000003U
#define CGS_COLOR_PROFILE_RESOLVE_SEND_SIZE 0x00000038U
#define CGS_COLOR_PROFILE_RESOLVE_RECV_SIZE 0x0000003cU
#define CGS_COLOR_PROFILE_RESOLVE_SUCCESS_REPLY_SIZE 0x00000034U
#define CGS_COLOR_PROFILE_RESOLVE_ERROR_REPLY_SIZE 0x00000024U
#define CGS_COLOR_PROFILE_RESOLVE_DESC_COUNT_OFF 0x18U
#define CGS_COLOR_PROFILE_RESOLVE_DESC_PORT_OFF 0x1cU
#define CGS_COLOR_PROFILE_RESOLVE_DESC_DISPOSITION_OFF 0x26U
#define CGS_COLOR_PROFILE_RESOLVE_DESC_TYPE_OFF 0x27U
#define CGS_COLOR_PROFILE_RESOLVE_NDR_OFF 0x28U
#define CGS_COLOR_PROFILE_RESOLVE_CLIENT_ID_OFF 0x30U
#define CGS_COLOR_PROFILE_RESOLVE_PROFILE_ID_OFF 0x34U
#define CGS_COLOR_PROFILE_RESOLVE_RESULT_OFF 0x20U
#define CGS_COLOR_PROFILE_RESOLVE_OUT0_LO_OFF 0x24U
#define CGS_COLOR_PROFILE_RESOLVE_OUT0_HI_OFF 0x28U
#define CGS_COLOR_PROFILE_RESOLVE_OUT1_LO_OFF 0x2cU
#define CGS_COLOR_PROFILE_RESOLVE_OUT1_HI_OFF 0x30U
#endif

#ifdef PM_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_INTEGRATION
#define CGS_COLOR_PROFILE_RESOLVE_COMPAT_BUILD_ID "color-profile-resolve-id-compat-v1"
#define CGS_COLOR_PROFILE_RESOLVE_COMPAT_BUILD_MARKER "PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_BUILD_ID:" CGS_COLOR_PROFILE_RESOLVE_COMPAT_BUILD_ID
#define CGS_COLOR_PROFILE_RESOLVE_COMPAT_ENV "ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_MODE"
#define CGS_COLOR_PROFILE_RESOLVE_COMPAT_PASSTHROUGH "passthrough"
#define CGS_COLOR_PROFILE_RESOLVE_COMPAT_LION_V1 "lion-id-v1"
#define CGS_COLOR_PROFILE_RESOLVE_PRIVATE_BUFFER_SIZE 0x00000040U
#define CGS_COLOR_PROFILE_RESOLVE_MAX_ADAPTED_CALLS 4U
#endif

#ifdef PM_CGS_SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_INTEGRATION
#define CGS_WINDOW_BACKING_INFO_COMPAT_BUILD_ID "window-backing-info-id-compat-v1"
#define CGS_WINDOW_BACKING_INFO_COMPAT_BUILD_MARKER "PM_CGS_WINDOW_BACKING_INFO_COMPAT_BUILD_ID:" CGS_WINDOW_BACKING_INFO_COMPAT_BUILD_ID
#define CGS_WINDOW_BACKING_INFO_COMPAT_ENV "ROSETTA_CGS_SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_MODE"
#define CGS_WINDOW_BACKING_INFO_COMPAT_PASSTHROUGH "passthrough"
#define CGS_WINDOW_BACKING_INFO_COMPAT_LION_V1 "lion-id-v1"
#define CGS_WINDOW_BACKING_INFO_LEGACY_REQUEST_ID 0x00007263U
#define CGS_WINDOW_BACKING_INFO_LEGACY_REPLY_ID 0x000072c7U
#define CGS_WINDOW_BACKING_INFO_LION_REQUEST_ID 0x00007264U
#define CGS_WINDOW_BACKING_INFO_LION_REPLY_ID 0x000072c8U
#define CGS_WINDOW_BACKING_INFO_BITS 0x00001513U
#define CGS_WINDOW_BACKING_INFO_MSG_OPTIONS 0x00000003U
#define CGS_WINDOW_BACKING_INFO_SEND_SIZE 0x00000024U
#define CGS_WINDOW_BACKING_INFO_RECV_SIZE 0x0000003cU
#define CGS_WINDOW_BACKING_INFO_SUCCESS_REPLY_SIZE 0x00000034U
#define CGS_WINDOW_BACKING_INFO_ERROR_REPLY_SIZE 0x00000024U
#define CGS_WINDOW_BACKING_INFO_WINDOW_ID_OFF 0x20U
#define CGS_WINDOW_BACKING_INFO_RESULT_OFF 0x20U
#define CGS_WINDOW_BACKING_INFO_OUT0_LO_OFF 0x24U
#define CGS_WINDOW_BACKING_INFO_OUT0_HI_OFF 0x28U
#define CGS_WINDOW_BACKING_INFO_OUT1_LO_OFF 0x2cU
#define CGS_WINDOW_BACKING_INFO_OUT1_HI_OFF 0x30U
#define CGS_WINDOW_BACKING_INFO_REPLY_BITS 0x00001200U
#define CGS_WINDOW_BACKING_INFO_PRIVATE_BUFFER_SIZE 0x00000040U
#define CGS_WINDOW_BACKING_INFO_MAX_ADAPTED_CALLS 1U
#endif

#ifdef PM_CGS_SERVER_VERSION_COMPAT_INTEGRATION
#define CGS_SERVER_VERSION_COMPAT_ENV "ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE"
#define CGS_SERVER_VERSION_COMPAT_PASSTHROUGH "passthrough"
#define CGS_SERVER_VERSION_COMPAT_LION_V1 "lion-server-version-v1"
#define CGS_SERVER_VERSION_REPLY_SIZE 0x00000040U
#define CGS_SERVER_VERSION_REPLY_DESC_COUNT_OFF 0x18U
#define CGS_SERVER_VERSION_REPLY_PORT_OFF 0x1cU
#define CGS_SERVER_VERSION_REPLY_DISPOSITION_OFF 0x26U
#define CGS_SERVER_VERSION_REPLY_TYPE_OFF 0x27U
#define CGS_SERVER_VERSION_REPLY_NDR_OFF 0x28U
#define CGS_SERVER_VERSION_REPLY_MAJOR_OFF 0x30U
#define CGS_SERVER_VERSION_REPLY_MINOR_OFF 0x34U
#define CGS_SERVER_VERSION_REPLY_AUX_OFF 0x38U
#define CGS_SERVER_VERSION_REPLY_FLAGS_OFF 0x3cU
#define CGS_SERVER_VERSION_EXPECTED_DISPOSITION 0x11U
#define CGS_SERVER_VERSION_EXPECTED_TYPE 0x00U
#define CGS_SERVER_VERSION_LION_MAJOR 600U
#define CGS_SERVER_VERSION_LION_MINOR 0U
#define CGS_SERVER_VERSION_SNOW_MAJOR 545U
#define CGS_SERVER_VERSION_SNOW_MINOR 0U
#define CGS_SERVER_VERSION_EXPECTED_AUX 0x69333836U
#define CGS_SERVER_VERSION_EXPECTED_FLAGS 0x00000001U
#endif

static const char *kCoreServicesDName =
    "com.apple.CoreServices.coreservicesd";
#ifdef PM_CPS_REGISTRATION_COMPAT_INTEGRATION
#ifdef PM_CPS_REGISTRATION_CARBON_SMOKETEST_COMPAT
static const char kCPSRegistrationObservedName[] =
    "ppc-carbon-gui-smoketest-private-dyld";
#else
static const char kCPSRegistrationObservedName[] =
    "ppc-process-manager-cgs-session-bootstrap-integration-private-dyld";
#endif
#endif

typedef kern_return_t (*bootstrap_lookup2_fn)(mach_port_t,
                                              const char *,
                                              mach_port_t *,
                                              pid_t,
                                              uint64_t);
typedef mach_msg_return_t (*mach_msg_fn)(mach_msg_header_t *,
                                         mach_msg_option_t,
                                         mach_msg_size_t,
                                         mach_msg_size_t,
                                         mach_port_name_t,
                                         mach_msg_timeout_t,
                                         mach_port_name_t);

#ifdef PM_DISTRIBUTED_NOTIFICATIONS_INGRESS_INTEGRATION
extern kern_return_t rosetta_distnotify_handle_lookup2(
    bootstrap_lookup2_fn,
    mach_port_t,
    const char *,
    mach_port_t *,
    pid_t,
    uint64_t);
#endif

struct interpose_tuple {
    const void *replacement;
    const void *replacee;
};

static kern_return_t rosetta_bootstrap_look_up2(mach_port_t,
                                                 const char *,
                                                 mach_port_t *,
                                                 pid_t,
                                                 uint64_t);
static mach_msg_return_t rosetta_mach_msg(mach_msg_header_t *,
                                           mach_msg_option_t,
                                           mach_msg_size_t,
                                           mach_msg_size_t,
                                           mach_port_name_t,
                                           mach_msg_timeout_t,
                                           mach_port_name_t);

static struct interpose_tuple sInterposes[2];

static bootstrap_lookup2_fn gOriginalLookup = NULL;
static mach_msg_fn gOriginalMachMsg = NULL;
static unsigned int gBootstrapExactCallCount = 0;
static unsigned int gBootstrapAdaptedCallCount = 0;
#ifdef PM_DISTRIBUTED_NOTIFICATIONS_COMPAT_PROTOCOL
static unsigned int gDistributedNotificationsCompatCallCount = 0;
#endif
static unsigned int gServerCheckinExactCallCount = 0;
static unsigned int gServerCheckinAdaptedCallCount = 0;
static unsigned int gSessionInitExactCallCount = 0;
static unsigned int gSessionInitAdaptedCallCount = 0;
#if defined(PM_CGS_CONNECTION_TRACE) || defined(PM_CGS_SERVER_VERSION_COMPAT_INTEGRATION)
static unsigned int gCGSTraceCallCount = 0;
#endif
#ifdef PM_CGS_SERVER_VERSION_COMPAT_INTEGRATION
static unsigned int gCGSServerVersionCompatCallCount = 0;
#endif
#ifdef PM_CPS_REGISTRATION_COMPAT_INTEGRATION
static unsigned int gCPSRegistrationCompatCallCount = 0;
#endif
#ifdef PM_CPS_SETFRONT_COMPAT_PROTOCOL
static unsigned int gCPSSetFrontCompatCallCount = 0;
#endif
#ifdef PM_CGS_NEWWINDOW_COMPAT_INTEGRATION
static unsigned int gCGSNewWindowCompatCallCount = 0;
#endif
#ifdef PM_CGS_RELEASEBACKING_COMPAT_INTEGRATION
static unsigned int gCGSReleaseBackingCompatCallCount = 0;
#endif
#ifdef PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_INTEGRATION
static unsigned int gCGSOpacityAlphaCreateCompatCallCount = 0;
#endif
#ifdef PM_CGS_SHAPEWINDOW_INLINE_COMPAT_INTEGRATION
static unsigned int gCGSShapeWindowInlineCompatCallCount = 0;
#endif
#ifdef PM_CGS_SYNCHRONIZE_WINDOW_BACKING_STORE_COMPAT_INTEGRATION
static unsigned int gCGSBackingSyncCompatCallCount = 0;
static unsigned int gCGSBackingSyncExactCallCount = 0;
static uint32_t gCGSBackingSyncTargetWindowID = 0U;
#endif
#ifdef PM_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_INTEGRATION
static unsigned int gCGSAddTrackingAreaCompatCallCount = 0;
#endif
#ifdef PM_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_INTEGRATION
static unsigned int gCGSOrderFrontConditionallyCompatCallCount = 0;
#endif
#ifdef PM_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_INTEGRATION
static unsigned int gCGSSetFrontWindowCompatCallCount = 0;
#endif
#ifdef PM_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_INTEGRATION
static unsigned int gCGSColorProfileClientCompatCallCount = 0;
#endif
#ifdef PM_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_INTEGRATION
static unsigned int gCGSColorProfileResolveCompatCallCount = 0;
static unsigned int gCGSColorProfileResolveAdaptedCallCount = 0;
static int gCGSColorProfileClientCompatAdapterPassed = 0;
static uint32_t gCGSColorProfileClientCompatSemanticClientID = 0U;
static mach_port_t gCGSColorProfileClientCompatRemotePort = MACH_PORT_NULL;
static mach_port_t gCGSColorProfileClientCompatReplyPort = MACH_PORT_NULL;
static mach_port_t gCGSColorProfileClientCompatDescriptorPort = MACH_PORT_NULL;
#endif
#ifdef PM_CGS_SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_INTEGRATION
static unsigned int gCGSWindowBackingInfoCompatCallCount = 0;
static unsigned int gCGSWindowBackingInfoAdaptedCallCount = 0;
#endif
#ifdef PM_CGS_SHOWWINDOW_UNKNOWN_TRACE
static mach_port_t gCGSShowWindowTracePort = MACH_PORT_NULL;
static unsigned int gCGSShowWindowUnknownTraceCount = 0;
#endif
static mach_port_t gCoreServicesServerPort = MACH_PORT_NULL;
static mach_port_t gServerCheckinReplyPort = MACH_PORT_NULL;

static void
put_u32(unsigned char *p, uint32_t value)
{
    memcpy(p, &value, sizeof(value));
}

static uint32_t
get_u32(const unsigned char *p)
{
    uint32_t value;
    memcpy(&value, p, sizeof(value));
    return value;
}

#ifdef PM_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_INTEGRATION
static uint32_t
cgs_color_profile_decode_u32(const unsigned char *message,
                             uint32_t ndr_off,
                             uint32_t value_off)
{
    const unsigned char *local_ndr = (const unsigned char *)&NDR_record;
    uint32_t value = get_u32(message + value_off);

    if (message[ndr_off + 4U] != local_ndr[4]) {
        value = ((value & 0x000000ffU) << 24) |
                ((value & 0x0000ff00U) << 8) |
                ((value & 0x00ff0000U) >> 8) |
                ((value & 0xff000000U) >> 24);
    }
    return value;
}
#endif

#ifdef PM_CGS_SERVER_VERSION_COMPAT_INTEGRATION
static uint32_t
swap_u32(uint32_t value)
{
    return ((value & 0x000000ffU) << 24) |
           ((value & 0x0000ff00U) << 8) |
           ((value & 0x00ff0000U) >> 8) |
           ((value & 0xff000000U) >> 24);
}

static int
cgs_server_version_reply_is_swapped(const unsigned char *message)
{
    const unsigned char *local_ndr = (const unsigned char *)&NDR_record;

    return message[CGS_SERVER_VERSION_REPLY_NDR_OFF + 4U] !=
           local_ndr[4];
}

static uint32_t
decode_cgs_server_version_u32(const unsigned char *message, uint32_t off)
{
    uint32_t value = get_u32(message + off);

    if (cgs_server_version_reply_is_swapped(message))
        value = swap_u32(value);
    return value;
}

static void
encode_cgs_server_version_u32(unsigned char *message,
                              uint32_t off,
                              uint32_t value)
{
    if (cgs_server_version_reply_is_swapped(message))
        value = swap_u32(value);
    put_u32(message + off, value);
}

static void
maybe_normalize_cgs_server_version_reply(unsigned char *message,
                                         uint32_t request_id,
                                         int request_exact,
                                         mach_msg_size_t rcv_size,
                                         mach_msg_return_t mr,
                                         uint32_t reply_bits,
                                         uint32_t reply_size,
                                         uint32_t reply_id)
{
    const char *mode;
    unsigned char before[CGS_SERVER_VERSION_REPLY_SIZE];
    uint32_t descriptor_count;
    mach_port_t descriptor_port;
    uint32_t disposition;
    uint32_t descriptor_type;
    uint32_t major;
    uint32_t minor;
    uint32_t aux;
    uint32_t flags;
    unsigned int changed = 0;
    unsigned int outside_changed = 0;
    unsigned int off;

    if (request_id != CGS_SERVER_VERSION_REQUEST_ID ||
        mr != MACH_MSG_SUCCESS)
        return;

    ++gCGSServerVersionCompatCallCount;
    mode = getenv(CGS_SERVER_VERSION_COMPAT_ENV);

    if (!request_exact ||
        rcv_size < CGS_SERVER_VERSION_REPLY_SIZE ||
        (reply_bits & MACH_MSGH_BITS_COMPLEX) == 0 ||
        reply_size != CGS_SERVER_VERSION_REPLY_SIZE ||
        reply_id != CGS_SERVER_VERSION_REPLY_ID) {
        fprintf(stderr,
                "PM_CGS_SERVER_VERSION_COMPAT_RESULT:REQUEST_OR_REPLY_ENVELOPE_REJECTED index=%u mode=%s requestExact=%s replyBits=0x%08lx replySize=0x%08lx replyId=0x%08lx recv=0x%08lx\n",
                gCGSServerVersionCompatCallCount,
                mode ? mode : "(unset)",
                request_exact ? "YES" : "NO",
                (unsigned long)reply_bits,
                (unsigned long)reply_size,
                (unsigned long)reply_id,
                (unsigned long)rcv_size);
        fflush(stderr);
        return;
    }

    descriptor_count =
        get_u32(message + CGS_SERVER_VERSION_REPLY_DESC_COUNT_OFF);
    descriptor_port =
        (mach_port_t)get_u32(message + CGS_SERVER_VERSION_REPLY_PORT_OFF);
    disposition =
        (uint32_t)message[CGS_SERVER_VERSION_REPLY_DISPOSITION_OFF];
    descriptor_type =
        (uint32_t)message[CGS_SERVER_VERSION_REPLY_TYPE_OFF];

    major = decode_cgs_server_version_u32(
        message, CGS_SERVER_VERSION_REPLY_MAJOR_OFF);
    minor = decode_cgs_server_version_u32(
        message, CGS_SERVER_VERSION_REPLY_MINOR_OFF);
    aux = decode_cgs_server_version_u32(
        message, CGS_SERVER_VERSION_REPLY_AUX_OFF);
    flags = decode_cgs_server_version_u32(
        message, CGS_SERVER_VERSION_REPLY_FLAGS_OFF);

    fprintf(stderr,
            "PM_CGS_SERVER_VERSION_COMPAT_CALL:index=%u mode=%s replyBits=0x%08lx replySize=0x%08lx replyId=0x%08lx descriptorCount=%lu descriptorPort=0x%08lx disposition=0x%02lx type=0x%02lx ndrSwapped=%s major=%lu minor=%lu aux=0x%08lx flags=0x%08lx\n",
            gCGSServerVersionCompatCallCount,
            mode ? mode : "(unset)",
            (unsigned long)reply_bits,
            (unsigned long)reply_size,
            (unsigned long)reply_id,
            (unsigned long)descriptor_count,
            (unsigned long)descriptor_port,
            (unsigned long)disposition,
            (unsigned long)descriptor_type,
            cgs_server_version_reply_is_swapped(message) ? "YES" : "NO",
            (unsigned long)major,
            (unsigned long)minor,
            (unsigned long)aux,
            (unsigned long)flags);
    fflush(stderr);

    if (mode != NULL &&
        strcmp(mode, CGS_SERVER_VERSION_COMPAT_PASSTHROUGH) == 0) {
        fprintf(stderr,
                "PM_CGS_SERVER_VERSION_COMPAT_RESULT:PASSTHROUGH major=%lu minor=%lu\n",
                (unsigned long)major,
                (unsigned long)minor);
        fflush(stderr);
        return;
    }

    if (mode == NULL ||
        strcmp(mode, CGS_SERVER_VERSION_COMPAT_LION_V1) != 0) {
        fprintf(stderr,
                "PM_CGS_SERVER_VERSION_COMPAT_RESULT:MODE_REJECTED\n");
        fflush(stderr);
        return;
    }

    if (gCGSServerVersionCompatCallCount != 1U ||
        descriptor_count != 1U ||
        descriptor_port == MACH_PORT_NULL ||
        disposition != CGS_SERVER_VERSION_EXPECTED_DISPOSITION ||
        descriptor_type != CGS_SERVER_VERSION_EXPECTED_TYPE ||
        !cgs_server_version_reply_is_swapped(message) ||
        major != CGS_SERVER_VERSION_LION_MAJOR ||
        minor != CGS_SERVER_VERSION_LION_MINOR ||
        aux != CGS_SERVER_VERSION_EXPECTED_AUX ||
        flags != CGS_SERVER_VERSION_EXPECTED_FLAGS) {
        fprintf(stderr,
                "PM_CGS_SERVER_VERSION_COMPAT_RESULT:SHAPE_OR_VALUE_REJECTED\n");
        fflush(stderr);
        return;
    }

    memcpy(before, message, CGS_SERVER_VERSION_REPLY_SIZE);

    encode_cgs_server_version_u32(
        message,
        CGS_SERVER_VERSION_REPLY_MAJOR_OFF,
        CGS_SERVER_VERSION_SNOW_MAJOR);
    encode_cgs_server_version_u32(
        message,
        CGS_SERVER_VERSION_REPLY_MINOR_OFF,
        CGS_SERVER_VERSION_SNOW_MINOR);

    for (off = 0U; off < CGS_SERVER_VERSION_REPLY_SIZE; ++off) {
        if (before[off] != message[off]) {
            ++changed;
            if (off < CGS_SERVER_VERSION_REPLY_MAJOR_OFF ||
                off >= CGS_SERVER_VERSION_REPLY_MINOR_OFF + 4U)
                ++outside_changed;
        }
    }

    major = decode_cgs_server_version_u32(
        message, CGS_SERVER_VERSION_REPLY_MAJOR_OFF);
    minor = decode_cgs_server_version_u32(
        message, CGS_SERVER_VERSION_REPLY_MINOR_OFF);

    if (changed == 0U ||
        outside_changed != 0U ||
        major != CGS_SERVER_VERSION_SNOW_MAJOR ||
        minor != CGS_SERVER_VERSION_SNOW_MINOR ||
        get_u32(message + CGS_SERVER_VERSION_REPLY_DESC_COUNT_OFF) !=
            get_u32(before + CGS_SERVER_VERSION_REPLY_DESC_COUNT_OFF) ||
        get_u32(message + CGS_SERVER_VERSION_REPLY_PORT_OFF) !=
            get_u32(before + CGS_SERVER_VERSION_REPLY_PORT_OFF) ||
        message[CGS_SERVER_VERSION_REPLY_DISPOSITION_OFF] !=
            before[CGS_SERVER_VERSION_REPLY_DISPOSITION_OFF] ||
        message[CGS_SERVER_VERSION_REPLY_TYPE_OFF] !=
            before[CGS_SERVER_VERSION_REPLY_TYPE_OFF] ||
        decode_cgs_server_version_u32(
            message, CGS_SERVER_VERSION_REPLY_AUX_OFF) != aux ||
        decode_cgs_server_version_u32(
            message, CGS_SERVER_VERSION_REPLY_FLAGS_OFF) != flags) {
        memcpy(message, before, CGS_SERVER_VERSION_REPLY_SIZE);
        fprintf(stderr,
                "PM_CGS_SERVER_VERSION_COMPAT_RESULT:POSTCHECK_FAILED_RESTORED\n");
        fflush(stderr);
        return;
    }

    fprintf(stderr,
            "PM_CGS_SERVER_VERSION_COMPAT_ADAPTER:index=%u originalMajor=%lu originalMinor=%lu adaptedMajor=%lu adaptedMinor=%lu changedBytes=%u outsideVersionBytesChanged=%u raw30Before=0x%08lx raw30After=0x%08lx raw34Before=0x%08lx raw34After=0x%08lx\n",
            gCGSServerVersionCompatCallCount,
            (unsigned long)CGS_SERVER_VERSION_LION_MAJOR,
            (unsigned long)CGS_SERVER_VERSION_LION_MINOR,
            (unsigned long)major,
            (unsigned long)minor,
            changed,
            outside_changed,
            (unsigned long)get_u32(
                before + CGS_SERVER_VERSION_REPLY_MAJOR_OFF),
            (unsigned long)get_u32(
                message + CGS_SERVER_VERSION_REPLY_MAJOR_OFF),
            (unsigned long)get_u32(
                before + CGS_SERVER_VERSION_REPLY_MINOR_OFF),
            (unsigned long)get_u32(
                message + CGS_SERVER_VERSION_REPLY_MINOR_OFF));
    fprintf(stderr,
            "PM_CGS_SERVER_VERSION_COMPAT_RESULT:ADAPTER_PASS\n");
    fflush(stderr);
}
#endif

static int
is_lion_compat_mode(const char *mode)
{
    return mode != NULL &&
           (strcmp(mode, COMPAT_MODE_LION_DUAL) == 0 ||
            strcmp(mode, COMPAT_MODE_LION_SESSIONINIT) == 0);
}

static void
put_u64(unsigned char *p, uint64_t value)
{
    memcpy(p, &value, sizeof(value));
}

static bootstrap_lookup2_fn
original_lookup(void)
{
    if (gOriginalLookup == NULL) {
        gOriginalLookup = (bootstrap_lookup2_fn)
            (uintptr_t)sInterposes[0].replacee;
    }
    return gOriginalLookup;
}

static mach_msg_fn
original_mach_msg(void)
{
    if (gOriginalMachMsg == NULL) {
        gOriginalMachMsg = (mach_msg_fn)
            (uintptr_t)sInterposes[1].replacee;
    }
    return gOriginalMachMsg;
}

static mach_msg_return_t
call_original_mach_msg(mach_msg_header_t *msg,
                       mach_msg_option_t option,
                       mach_msg_size_t send_size,
                       mach_msg_size_t rcv_size,
                       mach_port_name_t rcv_name,
                       mach_msg_timeout_t timeout,
                       mach_port_name_t notify)
{
    mach_msg_fn fn = original_mach_msg();

    if (fn == NULL || fn == (mach_msg_fn)&rosetta_mach_msg)
        return MIG_BAD_ID;

    return fn(msg, option, send_size, rcv_size,
              rcv_name, timeout, notify);
}

#ifdef PM_CPS_REGISTRATION_COMPAT_INTEGRATION
static uint32_t
cps_registration_swap_u32(uint32_t value)
{
    return ((value & 0x000000ffU) << 24) |
           ((value & 0x0000ff00U) << 8) |
           ((value & 0x00ff0000U) >> 8) |
           ((value & 0xff000000U) >> 24);
}

static int
cps_registration_reply_is_swapped(const unsigned char *message)
{
    const unsigned char *local_ndr = (const unsigned char *)&NDR_record;

    return message[CPS_REGISTRATION_REPLY_NDR_OFF + 4U] != local_ndr[4];
}

static int32_t
decode_cps_registration_result(const unsigned char *message)
{
    uint32_t value = get_u32(message + CPS_REGISTRATION_REPLY_RESULT_OFF);

    if (cps_registration_reply_is_swapped(message))
        value = cps_registration_swap_u32(value);
    return (int32_t)value;
}

static int
is_exact_legacy_cps_registration_request(mach_msg_header_t *msg,
                                         mach_msg_option_t option,
                                         mach_msg_size_t send_size,
                                         mach_msg_size_t rcv_size,
                                         mach_port_name_t rcv_name,
                                         mach_msg_timeout_t timeout,
                                         mach_port_name_t notify)
{
    unsigned char *m = (unsigned char *)msg;

    if (msg == NULL)
        return 0;
    if (sizeof(kCPSRegistrationObservedName) !=
        CPS_REGISTRATION_EXPECTED_STRING_LENGTH)
        return 0;

    return get_u32(m + 0x00U) == CPS_REGISTRATION_LEGACY_BITS &&
           get_u32(m + 0x08U) != 0U &&
           get_u32(m + 0x0cU) == (uint32_t)rcv_name &&
           rcv_name != MACH_PORT_NULL &&
           get_u32(m + 0x14U) == CGS_CHECKIN_APPLICATION_REQUEST_ID &&
           option == (mach_msg_option_t)CPS_REGISTRATION_MSG_OPTIONS &&
           send_size == (mach_msg_size_t)CPS_REGISTRATION_LEGACY_SEND_SIZE &&
           rcv_size == (mach_msg_size_t)CPS_REGISTRATION_RECV_SIZE &&
           timeout == MACH_MSG_TIMEOUT_NONE &&
           notify == MACH_PORT_NULL &&
           memcmp(m + CPS_REGISTRATION_NDR_OFF,
                  &NDR_record, sizeof(NDR_record)) == 0 &&
           get_u32(m + CPS_REGISTRATION_STRING_LENGTH_OFF) ==
               CPS_REGISTRATION_EXPECTED_STRING_LENGTH &&
           memcmp(m + CPS_REGISTRATION_STRING_OFF,
                  kCPSRegistrationObservedName,
                  sizeof(kCPSRegistrationObservedName)) == 0;
}

static mach_msg_return_t
handle_cps_registration_compat(mach_msg_header_t *msg,
                               mach_msg_option_t option,
                               mach_msg_size_t send_size,
                               mach_msg_size_t rcv_size,
                               mach_port_name_t rcv_name,
                               mach_msg_timeout_t timeout,
                               mach_port_name_t notify)
{
    const char *mode;
    unsigned char *m = (unsigned char *)msg;
    uint32_t storage[CPS_REGISTRATION_PRIVATE_BUFFER_SIZE / sizeof(uint32_t)];
    unsigned char *adapted = (unsigned char *)storage;
    unsigned char source_before[CPS_REGISTRATION_LEGACY_SEND_SIZE];
    unsigned char native_reply_before[CPS_REGISTRATION_SUCCESS_REPLY_SIZE];
    mach_msg_return_t mr;
    uint32_t native_reply_bits;
    uint32_t native_reply_size;
    uint32_t native_reply_id;
    int32_t native_result;
    unsigned int changed_common = 0U;
    unsigned int source_changed = 0U;
    unsigned int reply_changed = 0U;
    unsigned int off;
    uint32_t copy_size;
    int exact;

    ++gCPSRegistrationCompatCallCount;
    mode = getenv(CPS_REGISTRATION_COMPAT_ENV);
    exact = is_exact_legacy_cps_registration_request(
        msg, option, send_size, rcv_size, rcv_name, timeout, notify);

    fprintf(stderr,
            "PM_CPS_REGISTRATION_COMPAT_CALL:index=%u mode=%s exact=%s bits=0x%08lx id=0x%08lx send=0x%08lx recv=0x%08lx remotePort=0x%08lx replyPort=0x%08lx stringLength=0x%08lx\n",
            gCPSRegistrationCompatCallCount,
            mode ? mode : "(unset)",
            exact ? "YES" : "NO",
            (unsigned long)get_u32(m + 0x00U),
            (unsigned long)get_u32(m + 0x14U),
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            (unsigned long)get_u32(m + 0x08U),
            (unsigned long)rcv_name,
            (unsigned long)get_u32(m + CPS_REGISTRATION_STRING_LENGTH_OFF));
    fflush(stderr);

    if (mode != NULL &&
        strcmp(mode, CPS_REGISTRATION_COMPAT_PASSTHROUGH) == 0) {
        fprintf(stderr,
                "PM_CPS_REGISTRATION_COMPAT_RESULT:PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    if (mode == NULL ||
        strcmp(mode, CPS_REGISTRATION_COMPAT_LION_V1) != 0 ||
        !exact ||
        gCPSRegistrationCompatCallCount != 1U) {
        fprintf(stderr,
                "PM_CPS_REGISTRATION_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    memset(storage, 0, sizeof(storage));
    memcpy(source_before, m, CPS_REGISTRATION_LEGACY_SEND_SIZE);
    memcpy(adapted, m, CPS_REGISTRATION_LEGACY_SEND_SIZE);
    put_u32(adapted + 0x14U, CGS_CREATE_APPLICATION_REQUEST_ID);
    adapted[CPS_REGISTRATION_TAIL_BYTE_OFF] = 0U;
    adapted[CPS_REGISTRATION_TAIL_BYTE_OFF + 1U] = 0U;
    adapted[CPS_REGISTRATION_TAIL_BYTE_OFF + 2U] = 0U;
    adapted[CPS_REGISTRATION_TAIL_BYTE_OFF + 3U] = 0U;
    put_u32(adapted + CPS_REGISTRATION_TAIL_U32_0_OFF, 0U);
    put_u32(adapted + CPS_REGISTRATION_TAIL_U32_1_OFF, 0x00000010U);

    for (off = 0U; off < CPS_REGISTRATION_LEGACY_SEND_SIZE; ++off) {
        if (adapted[off] != source_before[off])
            ++changed_common;
        if (m[off] != source_before[off])
            ++source_changed;
    }

    fprintf(stderr,
            "PM_CPS_REGISTRATION_COMPAT_ADAPTED_REQUEST:index=%u legacyId=0x%08lx lionId=0x%08lx legacySend=0x%08lx lionSend=0x%08lx changedCommonBytes=%u sourceChangedBytes=%u tailByte=0x%02x tailU32_0=0x%08lx tailU32_1=0x%08lx\n",
            gCPSRegistrationCompatCallCount,
            (unsigned long)get_u32(source_before + 0x14U),
            (unsigned long)get_u32(adapted + 0x14U),
            (unsigned long)send_size,
            (unsigned long)CPS_REGISTRATION_LION_SEND_SIZE,
            changed_common,
            source_changed,
            (unsigned int)adapted[CPS_REGISTRATION_TAIL_BYTE_OFF],
            (unsigned long)get_u32(
                adapted + CPS_REGISTRATION_TAIL_U32_0_OFF),
            (unsigned long)get_u32(
                adapted + CPS_REGISTRATION_TAIL_U32_1_OFF));
    fflush(stderr);

    if (changed_common != 1U ||
        source_changed != 0U ||
        get_u32(adapted + 0x14U) != CGS_CREATE_APPLICATION_REQUEST_ID ||
        adapted[CPS_REGISTRATION_TAIL_BYTE_OFF] != 0U ||
        adapted[CPS_REGISTRATION_TAIL_BYTE_OFF + 1U] != 0U ||
        adapted[CPS_REGISTRATION_TAIL_BYTE_OFF + 2U] != 0U ||
        adapted[CPS_REGISTRATION_TAIL_BYTE_OFF + 3U] != 0U ||
        get_u32(adapted + CPS_REGISTRATION_TAIL_U32_0_OFF) != 0U ||
        get_u32(adapted + CPS_REGISTRATION_TAIL_U32_1_OFF) != 0x10U) {
        fprintf(stderr,
                "PM_CPS_REGISTRATION_COMPAT_RESULT:REQUEST_POSTCHECK_FAILED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    mr = call_original_mach_msg(
        (mach_msg_header_t *)adapted,
        option,
        (mach_msg_size_t)CPS_REGISTRATION_LION_SEND_SIZE,
        rcv_size,
        rcv_name,
        timeout,
        notify);

    fprintf(stderr,
            "PM_CPS_REGISTRATION_COMPAT_NATIVE_MACH_RETURN:index=%u kr=%ld hex=0x%08lx\n",
            gCPSRegistrationCompatCallCount,
            (long)mr,
            (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    native_reply_bits = get_u32(adapted + 0x00U);
    native_reply_size = get_u32(adapted + 0x04U);
    native_reply_id = get_u32(adapted + 0x14U);
    native_result = 0;

    if (native_reply_size >= CPS_REGISTRATION_SUCCESS_REPLY_SIZE &&
        native_reply_size <= rcv_size) {
        memcpy(native_reply_before, adapted,
               CPS_REGISTRATION_SUCCESS_REPLY_SIZE);
    } else {
        memset(native_reply_before, 0, sizeof(native_reply_before));
    }

    if (native_reply_size >= CPS_REGISTRATION_SUCCESS_REPLY_SIZE)
        native_result = decode_cps_registration_result(adapted);

    fprintf(stderr,
            "PM_CPS_REGISTRATION_COMPAT_NATIVE_REPLY:index=%u bits=0x%08lx size=0x%08lx id=0x%08lx result=%ld ndrSwapped=%s raw20=0x%08lx\n",
            gCPSRegistrationCompatCallCount,
            (unsigned long)native_reply_bits,
            (unsigned long)native_reply_size,
            (unsigned long)native_reply_id,
            (long)native_result,
            native_reply_size >= CPS_REGISTRATION_SUCCESS_REPLY_SIZE &&
                cps_registration_reply_is_swapped(adapted) ? "YES" : "NO",
            native_reply_size >= CPS_REGISTRATION_SUCCESS_REPLY_SIZE ?
                (unsigned long)get_u32(
                    adapted + CPS_REGISTRATION_REPLY_RESULT_OFF) : 0UL);
    fflush(stderr);

    if (native_reply_bits != CPS_REGISTRATION_SUCCESS_REPLY_BITS ||
        native_reply_size != CPS_REGISTRATION_SUCCESS_REPLY_SIZE ||
        native_reply_id != CGS_CREATE_APPLICATION_REPLY_ID ||
        !cps_registration_reply_is_swapped(adapted) ||
        native_result != 0) {
        copy_size = native_reply_size;
        if (copy_size > rcv_size)
            copy_size = rcv_size;
        if (copy_size > CPS_REGISTRATION_PRIVATE_BUFFER_SIZE)
            copy_size = CPS_REGISTRATION_PRIVATE_BUFFER_SIZE;
        if (copy_size != 0U)
            memcpy(m, adapted, copy_size);
        fprintf(stderr,
                "PM_CPS_REGISTRATION_COMPAT_RESULT:NATIVE_REPLY_REJECTED\n");
        fflush(stderr);
        return mr;
    }

    put_u32(adapted + 0x14U, CGS_CHECKIN_APPLICATION_REPLY_ID);
    for (off = 0U; off < CPS_REGISTRATION_SUCCESS_REPLY_SIZE; ++off) {
        if (adapted[off] != native_reply_before[off])
            ++reply_changed;
    }

    if (reply_changed != 2U ||
        get_u32(adapted + 0x14U) != CGS_CHECKIN_APPLICATION_REPLY_ID ||
        get_u32(adapted + 0x04U) != CPS_REGISTRATION_SUCCESS_REPLY_SIZE ||
        decode_cps_registration_result(adapted) != 0) {
        memcpy(m, native_reply_before,
               CPS_REGISTRATION_SUCCESS_REPLY_SIZE);
        fprintf(stderr,
                "PM_CPS_REGISTRATION_COMPAT_RESULT:REPLY_POSTCHECK_FAILED_NATIVE_COPIED\n");
        fflush(stderr);
        return mr;
    }

    memcpy(m, adapted, CPS_REGISTRATION_SUCCESS_REPLY_SIZE);

    fprintf(stderr,
            "PM_CPS_REGISTRATION_COMPAT_ADAPTED_REPLY:index=%u nativeId=0x%08lx legacyId=0x%08lx size=0x%08lx changedBytes=%u result=%ld\n",
            gCPSRegistrationCompatCallCount,
            (unsigned long)CGS_CREATE_APPLICATION_REPLY_ID,
            (unsigned long)get_u32(m + 0x14U),
            (unsigned long)get_u32(m + 0x04U),
            reply_changed,
            (long)decode_cps_registration_result(m));
    fprintf(stderr,
            "PM_CPS_REGISTRATION_COMPAT_RESULT:ADAPTER_PASS\n");
    fflush(stderr);
    return mr;
}
#endif

#ifdef PM_CPS_SETFRONT_COMPAT_PROTOCOL
static uint32_t
cps_setfront_swap_u32(uint32_t value)
{
    return ((value & 0x000000ffU) << 24) |
           ((value & 0x0000ff00U) << 8) |
           ((value & 0x00ff0000U) >> 8) |
           ((value & 0xff000000U) >> 24);
}

static int
cps_setfront_reply_is_swapped(const unsigned char *message)
{
    const unsigned char *local_ndr = (const unsigned char *)&NDR_record;

    return message[CPS_SETFRONT_REPLY_NDR_OFF + 4U] != local_ndr[4];
}

static int32_t
decode_cps_setfront_result(const unsigned char *message)
{
    uint32_t value = get_u32(message + CPS_SETFRONT_REPLY_RESULT_OFF);

    if (cps_setfront_reply_is_swapped(message))
        value = cps_setfront_swap_u32(value);
    return (int32_t)value;
}

static int
is_exact_legacy_cps_setfront_request(mach_msg_header_t *msg,
                                     mach_msg_option_t option,
                                     mach_msg_size_t send_size,
                                     mach_msg_size_t rcv_size,
                                     mach_port_name_t rcv_name,
                                     mach_msg_timeout_t timeout,
                                     mach_port_name_t notify)
{
    unsigned char *m = (unsigned char *)msg;

    if (msg == NULL)
        return 0;

    return get_u32(m + 0x00U) == CPS_SETFRONT_LEGACY_BITS &&
           get_u32(m + 0x08U) != 0U &&
           get_u32(m + 0x0cU) == (uint32_t)rcv_name &&
           rcv_name != MACH_PORT_NULL &&
           get_u32(m + 0x14U) == CGS_SET_FRONT_PROCESS_LEGACY_REQUEST_ID &&
           option == (mach_msg_option_t)CPS_SETFRONT_MSG_OPTIONS &&
           send_size == (mach_msg_size_t)CPS_SETFRONT_SEND_SIZE &&
           rcv_size == (mach_msg_size_t)CPS_SETFRONT_RECV_SIZE &&
           timeout == MACH_MSG_TIMEOUT_NONE &&
           notify == MACH_PORT_NULL &&
           memcmp(m + CPS_SETFRONT_NDR_OFF,
                  &NDR_record, sizeof(NDR_record)) == 0 &&
           get_u32(m + CPS_SETFRONT_PSN_HIGH_OFF) == 0U &&
           get_u32(m + CPS_SETFRONT_PSN_LOW_OFF) != 0U &&
           get_u32(m + CPS_SETFRONT_ARG2_OFF) == 0U &&
           get_u32(m + CPS_SETFRONT_ARG3_OFF) == 0U;
}

static mach_msg_return_t
handle_cps_setfront_compat(mach_msg_header_t *msg,
                           mach_msg_option_t option,
                           mach_msg_size_t send_size,
                           mach_msg_size_t rcv_size,
                           mach_port_name_t rcv_name,
                           mach_msg_timeout_t timeout,
                           mach_port_name_t notify)
{
    const char *mode;
    unsigned char *m = (unsigned char *)msg;
    uint32_t storage[CPS_SETFRONT_PRIVATE_BUFFER_SIZE / sizeof(uint32_t)];
    unsigned char *adapted = (unsigned char *)storage;
    unsigned char source_before[CPS_SETFRONT_SEND_SIZE];
    unsigned char native_reply_before[CPS_SETFRONT_SUCCESS_REPLY_SIZE];
    mach_msg_return_t mr;
    uint32_t native_reply_bits;
    uint32_t native_reply_size;
    uint32_t native_reply_id;
    int32_t native_result = 0;
    unsigned int request_changed = 0U;
    unsigned int source_changed = 0U;
    unsigned int reply_changed = 0U;
    unsigned int off;
    uint32_t copy_size;
    int exact;

    ++gCPSSetFrontCompatCallCount;
    mode = getenv(CPS_SETFRONT_COMPAT_ENV);
    exact = is_exact_legacy_cps_setfront_request(
        msg, option, send_size, rcv_size, rcv_name, timeout, notify);

    fprintf(stderr,
            "PM_CPS_SETFRONT_COMPAT_CALL:index=%u mode=%s exact=%s bits=0x%08lx id=0x%08lx send=0x%08lx recv=0x%08lx remotePort=0x%08lx replyPort=0x%08lx psnHigh=0x%08lx psnLow=0x%08lx arg2=0x%08lx arg3=0x%08lx registrationCalls=%u\n",
            gCPSSetFrontCompatCallCount,
            mode ? mode : "(unset)",
            exact ? "YES" : "NO",
            (unsigned long)get_u32(m + 0x00U),
            (unsigned long)get_u32(m + 0x14U),
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            (unsigned long)get_u32(m + 0x08U),
            (unsigned long)rcv_name,
            (unsigned long)get_u32(m + CPS_SETFRONT_PSN_HIGH_OFF),
            (unsigned long)get_u32(m + CPS_SETFRONT_PSN_LOW_OFF),
            (unsigned long)get_u32(m + CPS_SETFRONT_ARG2_OFF),
            (unsigned long)get_u32(m + CPS_SETFRONT_ARG3_OFF),
            gCPSRegistrationCompatCallCount);
    fflush(stderr);

    if (mode != NULL &&
        strcmp(mode, CPS_SETFRONT_COMPAT_PASSTHROUGH) == 0) {
        fprintf(stderr,
                "PM_CPS_SETFRONT_COMPAT_RESULT:PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    if (mode == NULL ||
        strcmp(mode, CPS_SETFRONT_COMPAT_LION_V1) != 0 ||
        !exact ||
        gCPSSetFrontCompatCallCount != 1U ||
        gCPSRegistrationCompatCallCount != 1U) {
        fprintf(stderr,
                "PM_CPS_SETFRONT_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    memset(storage, 0, sizeof(storage));
    memcpy(source_before, m, CPS_SETFRONT_SEND_SIZE);
    memcpy(adapted, m, CPS_SETFRONT_SEND_SIZE);
    put_u32(adapted + 0x14U, CGS_SET_FRONT_PROCESS_LION_REQUEST_ID);

    for (off = 0U; off < CPS_SETFRONT_SEND_SIZE; ++off) {
        if (adapted[off] != source_before[off])
            ++request_changed;
        if (m[off] != source_before[off])
            ++source_changed;
    }

    fprintf(stderr,
            "PM_CPS_SETFRONT_COMPAT_ADAPTED_REQUEST:index=%u legacyId=0x%08lx lionId=0x%08lx send=0x%08lx recv=0x%08lx changedBytes=%u sourceChangedBytes=%u psnHigh=0x%08lx psnLow=0x%08lx arg2=0x%08lx arg3=0x%08lx\n",
            gCPSSetFrontCompatCallCount,
            (unsigned long)get_u32(source_before + 0x14U),
            (unsigned long)get_u32(adapted + 0x14U),
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            request_changed,
            source_changed,
            (unsigned long)get_u32(adapted + CPS_SETFRONT_PSN_HIGH_OFF),
            (unsigned long)get_u32(adapted + CPS_SETFRONT_PSN_LOW_OFF),
            (unsigned long)get_u32(adapted + CPS_SETFRONT_ARG2_OFF),
            (unsigned long)get_u32(adapted + CPS_SETFRONT_ARG3_OFF));
    fflush(stderr);

    if (request_changed != 1U ||
        source_changed != 0U ||
        get_u32(adapted + 0x14U) !=
            CGS_SET_FRONT_PROCESS_LION_REQUEST_ID ||
        memcmp(adapted + CPS_SETFRONT_NDR_OFF,
               source_before + CPS_SETFRONT_NDR_OFF,
               CPS_SETFRONT_SEND_SIZE - CPS_SETFRONT_NDR_OFF) != 0) {
        fprintf(stderr,
                "PM_CPS_SETFRONT_COMPAT_RESULT:REQUEST_POSTCHECK_FAILED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    mr = call_original_mach_msg((mach_msg_header_t *)adapted,
                                option,
                                send_size,
                                rcv_size,
                                rcv_name,
                                timeout,
                                notify);

    fprintf(stderr,
            "PM_CPS_SETFRONT_COMPAT_NATIVE_MACH_RETURN:index=%u kr=%ld hex=0x%08lx\n",
            gCPSSetFrontCompatCallCount,
            (long)mr,
            (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    native_reply_bits = get_u32(adapted + 0x00U);
    native_reply_size = get_u32(adapted + 0x04U);
    native_reply_id = get_u32(adapted + 0x14U);

    if (native_reply_size >= CPS_SETFRONT_SUCCESS_REPLY_SIZE &&
        native_reply_size <= rcv_size) {
        memcpy(native_reply_before, adapted,
               CPS_SETFRONT_SUCCESS_REPLY_SIZE);
        native_result = decode_cps_setfront_result(adapted);
    } else {
        memset(native_reply_before, 0, sizeof(native_reply_before));
    }

    fprintf(stderr,
            "PM_CPS_SETFRONT_COMPAT_NATIVE_REPLY:index=%u bits=0x%08lx size=0x%08lx id=0x%08lx result=%ld ndrSwapped=%s raw20=0x%08lx\n",
            gCPSSetFrontCompatCallCount,
            (unsigned long)native_reply_bits,
            (unsigned long)native_reply_size,
            (unsigned long)native_reply_id,
            (long)native_result,
            native_reply_size >= CPS_SETFRONT_SUCCESS_REPLY_SIZE &&
                cps_setfront_reply_is_swapped(adapted) ? "YES" : "NO",
            native_reply_size >= CPS_SETFRONT_SUCCESS_REPLY_SIZE ?
                (unsigned long)get_u32(
                    adapted + CPS_SETFRONT_REPLY_RESULT_OFF) : 0UL);
    fflush(stderr);

    if (native_reply_bits != CPS_SETFRONT_SUCCESS_REPLY_BITS ||
        native_reply_size != CPS_SETFRONT_SUCCESS_REPLY_SIZE ||
        native_reply_id != CGS_SET_FRONT_PROCESS_LION_REPLY_ID ||
        !cps_setfront_reply_is_swapped(adapted) ||
        native_result != 0) {
        copy_size = native_reply_size;
        if (copy_size > rcv_size)
            copy_size = rcv_size;
        if (copy_size > CPS_SETFRONT_PRIVATE_BUFFER_SIZE)
            copy_size = CPS_SETFRONT_PRIVATE_BUFFER_SIZE;
        if (copy_size != 0U)
            memcpy(m, adapted, copy_size);
        fprintf(stderr,
                "PM_CPS_SETFRONT_COMPAT_RESULT:NATIVE_REPLY_REJECTED\n");
        fflush(stderr);
        return mr;
    }

    put_u32(adapted + 0x14U, CGS_SET_FRONT_PROCESS_LEGACY_REPLY_ID);
    for (off = 0U; off < CPS_SETFRONT_SUCCESS_REPLY_SIZE; ++off) {
        if (adapted[off] != native_reply_before[off])
            ++reply_changed;
    }

    if (reply_changed != 1U ||
        get_u32(adapted + 0x14U) !=
            CGS_SET_FRONT_PROCESS_LEGACY_REPLY_ID ||
        get_u32(adapted + 0x04U) != CPS_SETFRONT_SUCCESS_REPLY_SIZE ||
        decode_cps_setfront_result(adapted) != 0) {
        memcpy(m, native_reply_before, CPS_SETFRONT_SUCCESS_REPLY_SIZE);
        fprintf(stderr,
                "PM_CPS_SETFRONT_COMPAT_RESULT:REPLY_POSTCHECK_FAILED_NATIVE_COPIED\n");
        fflush(stderr);
        return mr;
    }

    memcpy(m, adapted, CPS_SETFRONT_SUCCESS_REPLY_SIZE);
    fprintf(stderr,
            "PM_CPS_SETFRONT_COMPAT_ADAPTED_REPLY:index=%u nativeId=0x%08lx legacyId=0x%08lx size=0x%08lx changedBytes=%u result=%ld\n",
            gCPSSetFrontCompatCallCount,
            (unsigned long)CGS_SET_FRONT_PROCESS_LION_REPLY_ID,
            (unsigned long)get_u32(m + 0x14U),
            (unsigned long)get_u32(m + 0x04U),
            reply_changed,
            (long)decode_cps_setfront_result(m));
    fprintf(stderr,
            "PM_CPS_SETFRONT_COMPAT_RESULT:ADAPTER_PASS\n");
    fflush(stderr);
    return mr;
}
#endif

#ifdef PM_CGS_NEWWINDOW_COMPAT_INTEGRATION
static uint32_t
cgs_newwindow_swap_u32(uint32_t value)
{
    return ((value & 0x000000ffU) << 24) |
           ((value & 0x0000ff00U) << 8) |
           ((value & 0x00ff0000U) >> 8) |
           ((value & 0xff000000U) >> 24);
}

static int
cgs_newwindow_reply_is_swapped(const unsigned char *message)
{
    const unsigned char *local_ndr = (const unsigned char *)&NDR_record;

    return message[CGS_NEWWINDOW_NDR_OFF + 4U] != local_ndr[4];
}

static int32_t
decode_cgs_newwindow_result(const unsigned char *message)
{
    uint32_t value = get_u32(message + CGS_NEWWINDOW_REPLY_RESULT_OFF);

    if (cgs_newwindow_reply_is_swapped(message))
        value = cgs_newwindow_swap_u32(value);
    return (int32_t)value;
}

static int
is_exact_legacy_cgs_newwindow_request(mach_msg_header_t *msg,
                                      mach_msg_option_t option,
                                      mach_msg_size_t send_size,
                                      mach_msg_size_t rcv_size,
                                      mach_port_name_t rcv_name,
                                      mach_msg_timeout_t timeout,
                                      mach_port_name_t notify)
{
    unsigned char *m = (unsigned char *)msg;

    if (msg == NULL)
        return 0;

    return get_u32(m + 0x00U) == CGS_NEWWINDOW_LEGACY_BITS &&
           get_u32(m + 0x08U) != 0U &&
           get_u32(m + 0x0cU) == (uint32_t)rcv_name &&
           rcv_name != MACH_PORT_NULL &&
           get_u32(m + 0x14U) ==
               CGS_CREATE_WINDOW_INLINE_LEGACY_REQUEST_ID &&
           option == (mach_msg_option_t)CGS_NEWWINDOW_MSG_OPTIONS &&
           send_size == (mach_msg_size_t)CGS_NEWWINDOW_SEND_SIZE &&
           rcv_size == (mach_msg_size_t)CGS_NEWWINDOW_RECV_SIZE &&
           timeout == MACH_MSG_TIMEOUT_NONE &&
           notify == MACH_PORT_NULL &&
           memcmp(m + CGS_NEWWINDOW_NDR_OFF,
                  &NDR_record, sizeof(NDR_record)) == 0 &&
           get_u32(m + 0x20U) == 0x00000002U &&
           get_u32(m + 0x24U) == 0x00000009U &&
           get_u32(m + 0x28U) == 0x80000000U &&
           get_u32(m + 0x2cU) == 0x00000002U &&
           get_u32(m + 0x30U) == 0x00000062U &&
           get_u32(m + 0x34U) == 0x00000004U &&
           get_u32(m + 0x38U) == 0x00000078U &&
           get_u32(m + 0x3cU) == 0x00000079U &&
           get_u32(m + 0x40U) == 0x00000063U;
}

static mach_msg_return_t
handle_cgs_newwindow_compat(mach_msg_header_t *msg,
                            mach_msg_option_t option,
                            mach_msg_size_t send_size,
                            mach_msg_size_t rcv_size,
                            mach_port_name_t rcv_name,
                            mach_msg_timeout_t timeout,
                            mach_port_name_t notify)
{
    const char *mode;
    unsigned char *m = (unsigned char *)msg;
    uint32_t storage[
        CGS_NEWWINDOW_PRIVATE_BUFFER_SIZE / sizeof(uint32_t)];
    unsigned char *adapted = (unsigned char *)storage;
    unsigned char source_before[CGS_NEWWINDOW_SEND_SIZE];
    unsigned char native_reply_before[CGS_NEWWINDOW_RECV_SIZE];
    mach_msg_return_t mr;
    uint32_t native_reply_bits;
    uint32_t native_reply_size;
    uint32_t native_reply_id;
    uint32_t copy_size;
    uint32_t off;
    int32_t native_result = 0;
    int32_t adapted_result = 0;
    unsigned int request_changed = 0U;
    unsigned int request_body_changed = 0U;
    unsigned int source_changed = 0U;
    unsigned int reply_changed = 0U;
    unsigned int reply_body_changed = 0U;
    int exact;
    int reply_swapped = 0;
    int reply_is_success = 0;
    int reply_is_error = 0;
    const char *reply_class = "UNEXPECTED";

    ++gCGSNewWindowCompatCallCount;
    mode = getenv(CGS_NEWWINDOW_COMPAT_ENV);
    exact = is_exact_legacy_cgs_newwindow_request(
        msg, option, send_size, rcv_size, rcv_name, timeout, notify);

    fprintf(stderr,
            "PM_CGS_NEWWINDOW_COMPAT_CALL:index=%u mode=%s exact=%s bits=0x%08lx id=0x%08lx send=0x%08lx recv=0x%08lx remotePort=0x%08lx replyPort=0x%08lx registrationCalls=%u setFrontCalls=%u\n",
            gCGSNewWindowCompatCallCount,
            mode ? mode : "(unset)",
            exact ? "YES" : "NO",
            (unsigned long)get_u32(m + 0x00U),
            (unsigned long)get_u32(m + 0x14U),
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            (unsigned long)get_u32(m + 0x08U),
            (unsigned long)rcv_name,
            gCPSRegistrationCompatCallCount,
            gCPSSetFrontCompatCallCount);
    fflush(stderr);

    if (mode != NULL &&
        strcmp(mode, CGS_NEWWINDOW_COMPAT_PASSTHROUGH) == 0) {
        fprintf(stderr,
                "PM_CGS_NEWWINDOW_COMPAT_RESULT:PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    if (mode == NULL ||
        strcmp(mode, CGS_NEWWINDOW_COMPAT_LION_V1) != 0 ||
        !exact ||
        gCGSNewWindowCompatCallCount != 1U ||
        gCPSRegistrationCompatCallCount != 1U ||
        gCPSSetFrontCompatCallCount != 1U) {
        fprintf(stderr,
                "PM_CGS_NEWWINDOW_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    memset(storage, 0, sizeof(storage));
    memcpy(source_before, m, CGS_NEWWINDOW_SEND_SIZE);
    memcpy(adapted, m, CGS_NEWWINDOW_SEND_SIZE);
    put_u32(adapted + 0x14U,
            CGS_CREATE_WINDOW_INLINE_LION_REQUEST_ID);

    for (off = 0U; off < CGS_NEWWINDOW_SEND_SIZE; ++off) {
        if (adapted[off] != source_before[off]) {
            ++request_changed;
            if (off < 0x14U || off >= 0x18U)
                ++request_body_changed;
        }
        if (m[off] != source_before[off])
            ++source_changed;
    }

    fprintf(stderr,
            "PM_CGS_NEWWINDOW_COMPAT_ADAPTED_REQUEST:index=%u legacyId=0x%08lx lionId=0x%08lx send=0x%08lx recv=0x%08lx changedBytes=%u bodyChangedBytes=%u sourceChangedBytes=%u\n",
            gCGSNewWindowCompatCallCount,
            (unsigned long)get_u32(source_before + 0x14U),
            (unsigned long)get_u32(adapted + 0x14U),
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            request_changed,
            request_body_changed,
            source_changed);
    fflush(stderr);

    if (request_changed != 1U ||
        request_body_changed != 0U ||
        source_changed != 0U ||
        get_u32(adapted + 0x14U) !=
            CGS_CREATE_WINDOW_INLINE_LION_REQUEST_ID) {
        fprintf(stderr,
                "PM_CGS_NEWWINDOW_COMPAT_RESULT:REQUEST_POSTCHECK_FAILED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    mr = call_original_mach_msg((mach_msg_header_t *)adapted,
                                option,
                                send_size,
                                rcv_size,
                                rcv_name,
                                timeout,
                                notify);

    fprintf(stderr,
            "PM_CGS_NEWWINDOW_COMPAT_NATIVE_MACH_RETURN:index=%u kr=%ld hex=0x%08lx\n",
            gCGSNewWindowCompatCallCount,
            (long)mr,
            (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    native_reply_bits = get_u32(adapted + 0x00U);
    native_reply_size = get_u32(adapted + 0x04U);
    native_reply_id = get_u32(adapted + 0x14U);

    if (native_reply_size >= CGS_NEWWINDOW_ERROR_REPLY_SIZE &&
        native_reply_size <= CGS_NEWWINDOW_RECV_SIZE) {
        reply_swapped = cgs_newwindow_reply_is_swapped(adapted);
        native_result = decode_cgs_newwindow_result(adapted);
    }

    reply_is_success =
        native_reply_bits == CGS_NEWWINDOW_SUCCESS_REPLY_BITS &&
        native_reply_size == CGS_NEWWINDOW_SUCCESS_REPLY_SIZE &&
        native_reply_id == CGS_CREATE_WINDOW_INLINE_LION_REPLY_ID &&
        reply_swapped &&
        native_result == 0;

    reply_is_error =
        native_reply_bits == CGS_NEWWINDOW_SUCCESS_REPLY_BITS &&
        native_reply_size == CGS_NEWWINDOW_ERROR_REPLY_SIZE &&
        native_reply_id == CGS_CREATE_WINDOW_INLINE_LION_REPLY_ID &&
        reply_swapped &&
        native_result != 0;

    if (reply_is_success)
        reply_class = "SUCCESS";
    else if (reply_is_error)
        reply_class = "ERROR";

    fprintf(stderr,
            "PM_CGS_NEWWINDOW_COMPAT_NATIVE_REPLY:index=%u bits=0x%08lx size=0x%08lx id=0x%08lx result=%ld ndrSwapped=%s replyClass=%s raw20=0x%08lx\n",
            gCGSNewWindowCompatCallCount,
            (unsigned long)native_reply_bits,
            (unsigned long)native_reply_size,
            (unsigned long)native_reply_id,
            (long)native_result,
            reply_swapped ? "YES" : "NO",
            reply_class,
            native_reply_size >= CGS_NEWWINDOW_ERROR_REPLY_SIZE ?
                (unsigned long)get_u32(
                    adapted + CGS_NEWWINDOW_REPLY_RESULT_OFF) : 0UL);
    fflush(stderr);

    if (!reply_is_success && !reply_is_error) {
        copy_size = native_reply_size;
        if (copy_size > rcv_size)
            copy_size = rcv_size;
        if (copy_size > CGS_NEWWINDOW_PRIVATE_BUFFER_SIZE)
            copy_size = CGS_NEWWINDOW_PRIVATE_BUFFER_SIZE;
        if (copy_size != 0U)
            memcpy(m, adapted, copy_size);
        fprintf(stderr,
                "PM_CGS_NEWWINDOW_COMPAT_RESULT:NATIVE_REPLY_REJECTED\n");
        fflush(stderr);
        return mr;
    }

    memcpy(native_reply_before, adapted, native_reply_size);
    put_u32(adapted + 0x14U,
            CGS_CREATE_WINDOW_INLINE_LEGACY_REPLY_ID);

    for (off = 0U; off < native_reply_size; ++off) {
        if (adapted[off] != native_reply_before[off]) {
            ++reply_changed;
            if (off < 0x14U || off >= 0x18U)
                ++reply_body_changed;
        }
    }

    adapted_result = decode_cgs_newwindow_result(adapted);

    if (reply_changed != 1U ||
        reply_body_changed != 0U ||
        get_u32(adapted + 0x14U) !=
            CGS_CREATE_WINDOW_INLINE_LEGACY_REPLY_ID ||
        get_u32(adapted + 0x04U) != native_reply_size ||
        adapted_result != native_result) {
        memcpy(m, native_reply_before, native_reply_size);
        fprintf(stderr,
                "PM_CGS_NEWWINDOW_COMPAT_RESULT:REPLY_POSTCHECK_FAILED_NATIVE_COPIED\n");
        fflush(stderr);
        return mr;
    }

    memcpy(m, adapted, native_reply_size);
    fprintf(stderr,
            "PM_CGS_NEWWINDOW_COMPAT_ADAPTED_REPLY:index=%u nativeId=0x%08lx legacyId=0x%08lx size=0x%08lx changedBytes=%u bodyChangedBytes=%u result=%ld replyClass=%s\n",
            gCGSNewWindowCompatCallCount,
            (unsigned long)CGS_CREATE_WINDOW_INLINE_LION_REPLY_ID,
            (unsigned long)get_u32(m + 0x14U),
            (unsigned long)get_u32(m + 0x04U),
            reply_changed,
            reply_body_changed,
            (long)adapted_result,
            reply_class);
    fprintf(stderr,
            "PM_CGS_NEWWINDOW_COMPAT_RESULT:ADAPTER_PASS\n");
    fflush(stderr);
    return mr;
}
#endif

#ifdef PM_CGS_RELEASEBACKING_COMPAT_INTEGRATION
static uint32_t
cgs_releasebacking_swap_u32(uint32_t value)
{
    return ((value & 0x000000ffU) << 24) |
           ((value & 0x0000ff00U) << 8) |
           ((value & 0x00ff0000U) >> 8) |
           ((value & 0xff000000U) >> 24);
}

static int
cgs_releasebacking_reply_is_swapped(const unsigned char *message)
{
    const unsigned char *local_ndr = (const unsigned char *)&NDR_record;

    return message[CGS_RELEASEBACKING_NDR_OFF + 4U] != local_ndr[4];
}

static int32_t
decode_cgs_releasebacking_result(const unsigned char *message)
{
    uint32_t value = get_u32(message + CGS_RELEASEBACKING_RESULT_OFF);

    if (cgs_releasebacking_reply_is_swapped(message))
        value = cgs_releasebacking_swap_u32(value);
    return (int32_t)value;
}

static int
is_exact_legacy_cgs_releasebacking_request(mach_msg_header_t *msg,
                                           mach_msg_option_t option,
                                           mach_msg_size_t send_size,
                                           mach_msg_size_t rcv_size,
                                           mach_port_name_t rcv_name,
                                           mach_msg_timeout_t timeout,
                                           mach_port_name_t notify)
{
    unsigned char *m = (unsigned char *)msg;

    if (msg == NULL)
        return 0;

    return get_u32(m + 0x00U) == CGS_RELEASEBACKING_LEGACY_BITS &&
           get_u32(m + 0x08U) != 0U &&
           get_u32(m + 0x0cU) == (uint32_t)rcv_name &&
           rcv_name != MACH_PORT_NULL &&
           get_u32(m + 0x14U) ==
               CGS_SET_WINDOW_RELEASE_BACKING_LEGACY_REQUEST_ID &&
           option == (mach_msg_option_t)CGS_RELEASEBACKING_MSG_OPTIONS &&
           send_size == (mach_msg_size_t)CGS_RELEASEBACKING_SEND_SIZE &&
           rcv_size == (mach_msg_size_t)CGS_RELEASEBACKING_RECV_SIZE &&
           timeout == MACH_MSG_TIMEOUT_NONE &&
           notify == MACH_PORT_NULL &&
           memcmp(m + CGS_RELEASEBACKING_NDR_OFF,
                  &NDR_record, sizeof(NDR_record)) == 0 &&
           get_u32(m + CGS_RELEASEBACKING_WINDOW_ID_OFF) != 0U &&
           get_u32(m + CGS_RELEASEBACKING_RELEASE_FLAG_OFF) == 1U;
}

static mach_msg_return_t
handle_cgs_releasebacking_compat(mach_msg_header_t *msg,
                                 mach_msg_option_t option,
                                 mach_msg_size_t send_size,
                                 mach_msg_size_t rcv_size,
                                 mach_port_name_t rcv_name,
                                 mach_msg_timeout_t timeout,
                                 mach_port_name_t notify)
{
    const char *mode;
    unsigned char *m = (unsigned char *)msg;
    uint32_t storage[
        CGS_RELEASEBACKING_PRIVATE_BUFFER_SIZE / sizeof(uint32_t)];
    unsigned char *adapted = (unsigned char *)storage;
    unsigned char source_before[CGS_RELEASEBACKING_SEND_SIZE];
    unsigned char native_reply_before[CGS_RELEASEBACKING_REPLY_SIZE];
    mach_msg_return_t mr;
    uint32_t native_reply_bits;
    uint32_t native_reply_size;
    uint32_t native_reply_id;
    uint32_t off;
    int32_t native_result = 0;
    int32_t adapted_result = 0;
    unsigned int request_changed = 0U;
    unsigned int request_body_changed = 0U;
    unsigned int source_changed = 0U;
    unsigned int reply_changed = 0U;
    unsigned int reply_body_changed = 0U;
    int exact;
    int lion_showwindow_mode;
    int lion_selectwindow_mode;
    int call_index_ok;
    int reply_swapped = 0;
    const char *reply_class = "UNEXPECTED";

    ++gCGSReleaseBackingCompatCallCount;
    mode = getenv(CGS_RELEASEBACKING_COMPAT_ENV);
    exact = is_exact_legacy_cgs_releasebacking_request(
        msg, option, send_size, rcv_size, rcv_name, timeout, notify);

    fprintf(stderr,
            "PM_CGS_RELEASEBACKING_COMPAT_CALL:index=%u mode=%s exact=%s bits=0x%08lx id=0x%08lx send=0x%08lx recv=0x%08lx remotePort=0x%08lx replyPort=0x%08lx windowId=0x%08lx releaseFlag=0x%08lx newWindowCompatCalls=%u\n",
            gCGSReleaseBackingCompatCallCount,
            mode ? mode : "(unset)",
            exact ? "YES" : "NO",
            (unsigned long)get_u32(m + 0x00U),
            (unsigned long)get_u32(m + 0x14U),
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            (unsigned long)get_u32(m + 0x08U),
            (unsigned long)rcv_name,
            (unsigned long)get_u32(m + CGS_RELEASEBACKING_WINDOW_ID_OFF),
            (unsigned long)get_u32(m + CGS_RELEASEBACKING_RELEASE_FLAG_OFF),
            gCGSNewWindowCompatCallCount);
    fflush(stderr);

    if (mode != NULL &&
        strcmp(mode, CGS_RELEASEBACKING_COMPAT_PASSTHROUGH) == 0) {
        fprintf(stderr,
                "PM_CGS_RELEASEBACKING_COMPAT_RESULT:PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    if (mode == NULL ||
        strcmp(mode, CGS_RELEASEBACKING_COMPAT_LION_V1) != 0 ||
        !exact ||
        gCGSReleaseBackingCompatCallCount != 1U ||
        gCGSNewWindowCompatCallCount != 1U) {
        fprintf(stderr,
                "PM_CGS_RELEASEBACKING_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    memset(storage, 0, sizeof(storage));
    memcpy(source_before, m, CGS_RELEASEBACKING_SEND_SIZE);
    memcpy(adapted, m, CGS_RELEASEBACKING_SEND_SIZE);
    put_u32(adapted + 0x14U,
            CGS_SET_WINDOW_RELEASE_BACKING_LION_REQUEST_ID);

    for (off = 0U; off < CGS_RELEASEBACKING_SEND_SIZE; ++off) {
        if (adapted[off] != source_before[off]) {
            ++request_changed;
            if (off < 0x14U || off >= 0x18U)
                ++request_body_changed;
        }
        if (m[off] != source_before[off])
            ++source_changed;
    }

    fprintf(stderr,
            "PM_CGS_RELEASEBACKING_COMPAT_ADAPTED_REQUEST:index=%u legacyId=0x%08lx lionId=0x%08lx send=0x%08lx recv=0x%08lx changedBytes=%u bodyChangedBytes=%u sourceChangedBytes=%u windowId=0x%08lx releaseFlag=0x%08lx\n",
            gCGSReleaseBackingCompatCallCount,
            (unsigned long)get_u32(source_before + 0x14U),
            (unsigned long)get_u32(adapted + 0x14U),
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            request_changed,
            request_body_changed,
            source_changed,
            (unsigned long)get_u32(adapted + CGS_RELEASEBACKING_WINDOW_ID_OFF),
            (unsigned long)get_u32(adapted + CGS_RELEASEBACKING_RELEASE_FLAG_OFF));
    fflush(stderr);

    if (request_changed != 1U ||
        request_body_changed != 0U ||
        source_changed != 0U ||
        get_u32(adapted + 0x14U) !=
            CGS_SET_WINDOW_RELEASE_BACKING_LION_REQUEST_ID) {
        fprintf(stderr,
                "PM_CGS_RELEASEBACKING_COMPAT_RESULT:REQUEST_POSTCHECK_FAILED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    mr = call_original_mach_msg((mach_msg_header_t *)adapted,
                                option,
                                send_size,
                                rcv_size,
                                rcv_name,
                                timeout,
                                notify);

    fprintf(stderr,
            "PM_CGS_RELEASEBACKING_COMPAT_NATIVE_MACH_RETURN:index=%u kr=%ld hex=0x%08lx\n",
            gCGSReleaseBackingCompatCallCount,
            (long)mr,
            (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    native_reply_bits = get_u32(adapted + 0x00U);
    native_reply_size = get_u32(adapted + 0x04U);
    native_reply_id = get_u32(adapted + 0x14U);

    if (native_reply_size == CGS_RELEASEBACKING_REPLY_SIZE) {
        reply_swapped = cgs_releasebacking_reply_is_swapped(adapted);
        native_result = decode_cgs_releasebacking_result(adapted);
    }

    if (native_result == 0)
        reply_class = "SUCCESS";
    else
        reply_class = "ERROR";

    fprintf(stderr,
            "PM_CGS_RELEASEBACKING_COMPAT_NATIVE_REPLY:index=%u bits=0x%08lx size=0x%08lx id=0x%08lx result=%ld ndrSwapped=%s replyClass=%s raw20=0x%08lx\n",
            gCGSReleaseBackingCompatCallCount,
            (unsigned long)native_reply_bits,
            (unsigned long)native_reply_size,
            (unsigned long)native_reply_id,
            (long)native_result,
            reply_swapped ? "YES" : "NO",
            reply_class,
            native_reply_size >= CGS_RELEASEBACKING_REPLY_SIZE ?
                (unsigned long)get_u32(adapted + CGS_RELEASEBACKING_RESULT_OFF) :
                0UL);
    fflush(stderr);

    if (native_reply_bits != CGS_RELEASEBACKING_REPLY_BITS ||
        native_reply_size != CGS_RELEASEBACKING_REPLY_SIZE ||
        native_reply_id != CGS_SET_WINDOW_RELEASE_BACKING_LION_REPLY_ID ||
        !reply_swapped) {
        if (native_reply_size > 0U &&
            native_reply_size <= CGS_RELEASEBACKING_PRIVATE_BUFFER_SIZE)
            memcpy(m, adapted, native_reply_size);
        fprintf(stderr,
                "PM_CGS_RELEASEBACKING_COMPAT_RESULT:NATIVE_REPLY_REJECTED\n");
        fflush(stderr);
        return mr;
    }

    memcpy(native_reply_before, adapted, CGS_RELEASEBACKING_REPLY_SIZE);
    put_u32(adapted + 0x14U,
            CGS_SET_WINDOW_RELEASE_BACKING_LEGACY_REPLY_ID);

    for (off = 0U; off < CGS_RELEASEBACKING_REPLY_SIZE; ++off) {
        if (adapted[off] != native_reply_before[off]) {
            ++reply_changed;
            if (off < 0x14U || off >= 0x18U)
                ++reply_body_changed;
        }
    }

    adapted_result = decode_cgs_releasebacking_result(adapted);

    if (reply_changed != 1U ||
        reply_body_changed != 0U ||
        get_u32(adapted + 0x14U) !=
            CGS_SET_WINDOW_RELEASE_BACKING_LEGACY_REPLY_ID ||
        adapted_result != native_result) {
        memcpy(m, native_reply_before, CGS_RELEASEBACKING_REPLY_SIZE);
        fprintf(stderr,
                "PM_CGS_RELEASEBACKING_COMPAT_RESULT:REPLY_POSTCHECK_FAILED_NATIVE_COPIED\n");
        fflush(stderr);
        return mr;
    }

    memcpy(m, adapted, CGS_RELEASEBACKING_REPLY_SIZE);
    fprintf(stderr,
            "PM_CGS_RELEASEBACKING_COMPAT_ADAPTED_REPLY:index=%u nativeId=0x%08lx legacyId=0x%08lx size=0x%08lx changedBytes=%u bodyChangedBytes=%u result=%ld replyClass=%s\n",
            gCGSReleaseBackingCompatCallCount,
            (unsigned long)CGS_SET_WINDOW_RELEASE_BACKING_LION_REPLY_ID,
            (unsigned long)get_u32(m + 0x14U),
            (unsigned long)get_u32(m + 0x04U),
            reply_changed,
            reply_body_changed,
            (long)adapted_result,
            reply_class);
    fprintf(stderr,
            "PM_CGS_RELEASEBACKING_COMPAT_RESULT:ADAPTER_PASS\n");
    fflush(stderr);
    return mr;
}
#endif

#ifdef PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_INTEGRATION
static uint32_t
cgs_opacity_alpha_create_swap_u32(uint32_t value)
{
    return ((value & 0x000000ffU) << 24) |
           ((value & 0x0000ff00U) << 8) |
           ((value & 0x00ff0000U) >> 8) |
           ((value & 0xff000000U) >> 24);
}

static int
cgs_opacity_alpha_create_reply_is_swapped(const unsigned char *message)
{
    const unsigned char *local_ndr = (const unsigned char *)&NDR_record;

    return message[CGS_OPACITY_ALPHA_CREATE_NDR_OFF + 4U] != local_ndr[4];
}

static int32_t
decode_cgs_opacity_alpha_create_result(const unsigned char *message)
{
    uint32_t value =
        get_u32(message + CGS_OPACITY_ALPHA_CREATE_RESULT_OFF);

    if (cgs_opacity_alpha_create_reply_is_swapped(message))
        value = cgs_opacity_alpha_create_swap_u32(value);
    return (int32_t)value;
}

static int
is_exact_legacy_cgs_opacity_alpha_create_request(
    mach_msg_header_t *msg,
    mach_msg_option_t option,
    mach_msg_size_t send_size,
    mach_msg_size_t rcv_size,
    mach_port_name_t rcv_name,
    mach_msg_timeout_t timeout,
    mach_port_name_t notify)
{
    unsigned char *m = (unsigned char *)msg;

    if (msg == NULL)
        return 0;

    return get_u32(m + 0x00U) == CGS_OPACITY_ALPHA_CREATE_LEGACY_BITS &&
           get_u32(m + 0x08U) != 0U &&
           get_u32(m + 0x0cU) == (uint32_t)rcv_name &&
           rcv_name != MACH_PORT_NULL &&
           get_u32(m + 0x14U) ==
               CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY_REQUEST_ID &&
           option == (mach_msg_option_t)CGS_OPACITY_ALPHA_CREATE_MSG_OPTIONS &&
           send_size == (mach_msg_size_t)CGS_OPACITY_ALPHA_CREATE_SEND_SIZE &&
           rcv_size == (mach_msg_size_t)CGS_OPACITY_ALPHA_CREATE_RECV_SIZE &&
           timeout == MACH_MSG_TIMEOUT_NONE &&
           notify == MACH_PORT_NULL &&
           memcmp(m + CGS_OPACITY_ALPHA_CREATE_NDR_OFF,
                  &NDR_record, sizeof(NDR_record)) == 0 &&
           get_u32(m + CGS_OPACITY_ALPHA_CREATE_WINDOW_ID_OFF) != 0U;
}

static mach_msg_return_t
handle_cgs_opacity_alpha_create_compat(mach_msg_header_t *msg,
                                       mach_msg_option_t option,
                                       mach_msg_size_t send_size,
                                       mach_msg_size_t rcv_size,
                                       mach_port_name_t rcv_name,
                                       mach_msg_timeout_t timeout,
                                       mach_port_name_t notify)
{
    const char *mode;
    unsigned char *m = (unsigned char *)msg;
    uint32_t storage[
        CGS_OPACITY_ALPHA_CREATE_PRIVATE_BUFFER_SIZE / sizeof(uint32_t)];
    unsigned char *adapted = (unsigned char *)storage;
    unsigned char source_before[CGS_OPACITY_ALPHA_CREATE_SEND_SIZE];
    unsigned char native_reply_before[CGS_OPACITY_ALPHA_CREATE_REPLY_SIZE];
    mach_msg_return_t mr;
    uint32_t native_reply_bits;
    uint32_t native_reply_size;
    uint32_t native_reply_id;
    uint32_t off;
    int32_t native_result = 0;
    int32_t adapted_result = 0;
    unsigned int request_changed = 0U;
    unsigned int request_body_changed = 0U;
    unsigned int source_changed = 0U;
    unsigned int reply_changed = 0U;
    unsigned int reply_body_changed = 0U;
    int exact;
    int reply_swapped = 0;
    const char *reply_class = "UNEXPECTED";

    ++gCGSOpacityAlphaCreateCompatCallCount;
    mode = getenv(CGS_OPACITY_ALPHA_CREATE_COMPAT_ENV);
    exact = is_exact_legacy_cgs_opacity_alpha_create_request(
        msg, option, send_size, rcv_size, rcv_name, timeout, notify);

    fprintf(stderr,
            "PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_CALL:index=%u mode=%s exact=%s bits=0x%08lx id=0x%08lx send=0x%08lx recv=0x%08lx remotePort=0x%08lx replyPort=0x%08lx windowId=0x%08lx releaseBackingCompatCalls=%u newWindowCompatCalls=%u\n",
            gCGSOpacityAlphaCreateCompatCallCount,
            mode ? mode : "(unset)",
            exact ? "YES" : "NO",
            (unsigned long)get_u32(m + 0x00U),
            (unsigned long)get_u32(m + 0x14U),
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            (unsigned long)get_u32(m + 0x08U),
            (unsigned long)rcv_name,
            (unsigned long)get_u32(
                m + CGS_OPACITY_ALPHA_CREATE_WINDOW_ID_OFF),
            gCGSReleaseBackingCompatCallCount,
            gCGSNewWindowCompatCallCount);
    fflush(stderr);

    if (mode != NULL &&
        strcmp(mode, CGS_OPACITY_ALPHA_CREATE_COMPAT_PASSTHROUGH) == 0) {
        fprintf(stderr,
                "PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_RESULT:PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    if (mode == NULL ||
        strcmp(mode, CGS_OPACITY_ALPHA_CREATE_COMPAT_LION_V1) != 0 ||
        !exact ||
        gCGSOpacityAlphaCreateCompatCallCount != 1U ||
        gCGSReleaseBackingCompatCallCount != 1U ||
        gCGSNewWindowCompatCallCount != 1U) {
        fprintf(stderr,
                "PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    memset(storage, 0, sizeof(storage));
    memcpy(source_before, m, CGS_OPACITY_ALPHA_CREATE_SEND_SIZE);
    memcpy(adapted, m, CGS_OPACITY_ALPHA_CREATE_SEND_SIZE);
    put_u32(adapted + 0x14U,
            CGS_CREATE_WINDOW_ALPHA_PLANE_LION_REQUEST_ID);

    for (off = 0U; off < CGS_OPACITY_ALPHA_CREATE_SEND_SIZE; ++off) {
        if (adapted[off] != source_before[off]) {
            ++request_changed;
            if (off < 0x14U || off >= 0x18U)
                ++request_body_changed;
        }
        if (m[off] != source_before[off])
            ++source_changed;
    }

    fprintf(stderr,
            "PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_ADAPTED_REQUEST:index=%u legacyId=0x%08lx lionId=0x%08lx send=0x%08lx recv=0x%08lx changedBytes=%u bodyChangedBytes=%u sourceChangedBytes=%u windowId=0x%08lx\n",
            gCGSOpacityAlphaCreateCompatCallCount,
            (unsigned long)get_u32(source_before + 0x14U),
            (unsigned long)get_u32(adapted + 0x14U),
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            request_changed,
            request_body_changed,
            source_changed,
            (unsigned long)get_u32(
                adapted + CGS_OPACITY_ALPHA_CREATE_WINDOW_ID_OFF));
    fflush(stderr);

    if (request_changed != 1U ||
        request_body_changed != 0U ||
        source_changed != 0U ||
        get_u32(adapted + 0x14U) !=
            CGS_CREATE_WINDOW_ALPHA_PLANE_LION_REQUEST_ID) {
        fprintf(stderr,
                "PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_RESULT:REQUEST_POSTCHECK_FAILED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    mr = call_original_mach_msg((mach_msg_header_t *)adapted,
                                option,
                                send_size,
                                rcv_size,
                                rcv_name,
                                timeout,
                                notify);

    fprintf(stderr,
            "PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_NATIVE_MACH_RETURN:index=%u kr=%ld hex=0x%08lx\n",
            gCGSOpacityAlphaCreateCompatCallCount,
            (long)mr,
            (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    native_reply_bits = get_u32(adapted + 0x00U);
    native_reply_size = get_u32(adapted + 0x04U);
    native_reply_id = get_u32(adapted + 0x14U);

    if (native_reply_size == CGS_OPACITY_ALPHA_CREATE_REPLY_SIZE) {
        reply_swapped =
            cgs_opacity_alpha_create_reply_is_swapped(adapted);
        native_result =
            decode_cgs_opacity_alpha_create_result(adapted);
    }

    if (native_result == 0)
        reply_class = "SUCCESS";
    else
        reply_class = "ERROR";

    fprintf(stderr,
            "PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_NATIVE_REPLY:index=%u bits=0x%08lx size=0x%08lx id=0x%08lx result=%ld ndrSwapped=%s replyClass=%s raw20=0x%08lx\n",
            gCGSOpacityAlphaCreateCompatCallCount,
            (unsigned long)native_reply_bits,
            (unsigned long)native_reply_size,
            (unsigned long)native_reply_id,
            (long)native_result,
            reply_swapped ? "YES" : "NO",
            reply_class,
            native_reply_size >= CGS_OPACITY_ALPHA_CREATE_REPLY_SIZE ?
                (unsigned long)get_u32(
                    adapted + CGS_OPACITY_ALPHA_CREATE_RESULT_OFF) : 0UL);
    fflush(stderr);

    if (native_reply_bits != CGS_OPACITY_ALPHA_CREATE_REPLY_BITS ||
        native_reply_size != CGS_OPACITY_ALPHA_CREATE_REPLY_SIZE ||
        native_reply_id !=
            CGS_CREATE_WINDOW_ALPHA_PLANE_LION_REPLY_ID ||
        !reply_swapped) {
        if (native_reply_size > 0U &&
            native_reply_size <=
                CGS_OPACITY_ALPHA_CREATE_PRIVATE_BUFFER_SIZE)
            memcpy(m, adapted, native_reply_size);
        fprintf(stderr,
                "PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_RESULT:NATIVE_REPLY_REJECTED\n");
        fflush(stderr);
        return mr;
    }

    memcpy(native_reply_before, adapted,
           CGS_OPACITY_ALPHA_CREATE_REPLY_SIZE);
    put_u32(adapted + 0x14U,
            CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY_REPLY_ID);

    for (off = 0U; off < CGS_OPACITY_ALPHA_CREATE_REPLY_SIZE; ++off) {
        if (adapted[off] != native_reply_before[off]) {
            ++reply_changed;
            if (off < 0x14U || off >= 0x18U)
                ++reply_body_changed;
        }
    }

    adapted_result = decode_cgs_opacity_alpha_create_result(adapted);

    if (reply_changed != 1U ||
        reply_body_changed != 0U ||
        get_u32(adapted + 0x14U) !=
            CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY_REPLY_ID ||
        adapted_result != native_result) {
        memcpy(m, native_reply_before,
               CGS_OPACITY_ALPHA_CREATE_REPLY_SIZE);
        fprintf(stderr,
                "PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_RESULT:REPLY_POSTCHECK_FAILED_NATIVE_COPIED\n");
        fflush(stderr);
        return mr;
    }

    memcpy(m, adapted, CGS_OPACITY_ALPHA_CREATE_REPLY_SIZE);
    fprintf(stderr,
            "PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_ADAPTED_REPLY:index=%u nativeId=0x%08lx legacyId=0x%08lx size=0x%08lx changedBytes=%u bodyChangedBytes=%u result=%ld replyClass=%s\n",
            gCGSOpacityAlphaCreateCompatCallCount,
            (unsigned long)CGS_CREATE_WINDOW_ALPHA_PLANE_LION_REPLY_ID,
            (unsigned long)get_u32(m + 0x14U),
            (unsigned long)get_u32(m + 0x04U),
            reply_changed,
            reply_body_changed,
            (long)adapted_result,
            reply_class);
    fprintf(stderr,
            "PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_RESULT:ADAPTER_PASS\n");
    fflush(stderr);
    return mr;
}
#endif

#ifdef PM_CGS_SHAPEWINDOW_INLINE_COMPAT_INTEGRATION
static uint32_t
cgs_shapewindow_inline_swap_u32(uint32_t value)
{
    return ((value & 0x000000ffU) << 24) |
           ((value & 0x0000ff00U) << 8) |
           ((value & 0x00ff0000U) >> 8) |
           ((value & 0xff000000U) >> 24);
}

static int
cgs_shapewindow_inline_reply_is_swapped(const unsigned char *message)
{
    const unsigned char *local_ndr = (const unsigned char *)&NDR_record;

    return message[CGS_SHAPEWINDOW_INLINE_NDR_OFF + 4U] != local_ndr[4];
}

static int32_t
decode_cgs_shapewindow_inline_result(const unsigned char *message)
{
    uint32_t value = get_u32(message + CGS_SHAPEWINDOW_INLINE_RESULT_OFF);

    if (cgs_shapewindow_inline_reply_is_swapped(message))
        value = cgs_shapewindow_inline_swap_u32(value);
    return (int32_t)value;
}

static int
is_exact_legacy_cgs_shapewindow_inline_request(
    mach_msg_header_t *msg,
    mach_msg_option_t option,
    mach_msg_size_t send_size,
    mach_msg_size_t rcv_size,
    mach_port_name_t rcv_name,
    mach_msg_timeout_t timeout,
    mach_port_name_t notify)
{
    static const uint32_t expected_shape[CGS_SHAPEWINDOW_INLINE_OBSERVED_COUNT] = {
        0x80000000U, 0x00000002U, 0x00000062U,
        0x00000004U, 0x00000078U, 0x00000208U,
        0x00000140U, 0x00000002U, 0x7fffffffU
    };
    unsigned char *m = (unsigned char *)msg;
    uint32_t count;
    uint32_t i;

    if (msg == NULL)
        return 0;

    count = get_u32(m + CGS_SHAPEWINDOW_INLINE_COUNT_OFF);
    if (count != CGS_SHAPEWINDOW_INLINE_OBSERVED_COUNT)
        return 0;

    for (i = 0U; i < CGS_SHAPEWINDOW_INLINE_OBSERVED_COUNT; ++i) {
        if (get_u32(m + CGS_SHAPEWINDOW_INLINE_DATA_OFF + 4U * i) !=
            expected_shape[i])
            return 0;
    }

    return get_u32(m + 0x00U) == CGS_SHAPEWINDOW_INLINE_BITS &&
           get_u32(m + 0x08U) != 0U &&
           get_u32(m + 0x08U) == (uint32_t)gCGSShowWindowTracePort &&
           get_u32(m + 0x0cU) == (uint32_t)rcv_name &&
           rcv_name != MACH_PORT_NULL &&
           get_u32(m + 0x14U) ==
               CGS_SHAPEWINDOW_INLINE_LEGACY_REQUEST_ID &&
           option == (mach_msg_option_t)CGS_SHAPEWINDOW_INLINE_MSG_OPTIONS &&
           send_size ==
               (mach_msg_size_t)CGS_SHAPEWINDOW_INLINE_OBSERVED_SEND_SIZE &&
           send_size == (mach_msg_size_t)(0x2cU + 4U * count) &&
           rcv_size == (mach_msg_size_t)CGS_SHAPEWINDOW_INLINE_RECV_SIZE &&
           timeout == MACH_MSG_TIMEOUT_NONE &&
           notify == MACH_PORT_NULL &&
           memcmp(m + CGS_SHAPEWINDOW_INLINE_NDR_OFF,
                  &NDR_record, sizeof(NDR_record)) == 0 &&
           get_u32(m + CGS_SHAPEWINDOW_INLINE_WINDOW_ID_OFF) != 0U &&
           get_u32(m + CGS_SHAPEWINDOW_INLINE_ARG1_OFF) == 1U;
}

static mach_msg_return_t
handle_cgs_shapewindow_inline_compat(
    mach_msg_header_t *msg,
    mach_msg_option_t option,
    mach_msg_size_t send_size,
    mach_msg_size_t rcv_size,
    mach_port_name_t rcv_name,
    mach_msg_timeout_t timeout,
    mach_port_name_t notify)
{
    const char *mode;
    unsigned char *m = (unsigned char *)msg;
    uint32_t storage[
        CGS_SHAPEWINDOW_INLINE_PRIVATE_BUFFER_SIZE / sizeof(uint32_t)];
    unsigned char *adapted = (unsigned char *)storage;
    unsigned char source_before[CGS_SHAPEWINDOW_INLINE_OBSERVED_SEND_SIZE];
    unsigned char native_reply_before[CGS_SHAPEWINDOW_INLINE_REPLY_SIZE];
    mach_msg_return_t mr;
    uint32_t native_reply_bits;
    uint32_t native_reply_size;
    uint32_t native_reply_id;
    uint32_t off;
    int32_t native_result = 0;
    int32_t adapted_result = 0;
    unsigned int request_changed = 0U;
    unsigned int request_body_changed = 0U;
    unsigned int source_changed = 0U;
    unsigned int reply_changed = 0U;
    unsigned int reply_body_changed = 0U;
    int exact;
    int reply_swapped = 0;
    const char *reply_class = "UNEXPECTED";

    ++gCGSShapeWindowInlineCompatCallCount;
    mode = getenv(CGS_SHAPEWINDOW_INLINE_COMPAT_ENV);
    exact = is_exact_legacy_cgs_shapewindow_inline_request(
        msg, option, send_size, rcv_size, rcv_name, timeout, notify);

    fprintf(stderr,
            "PM_CGS_SHAPEWINDOW_INLINE_COMPAT_CALL:index=%u mode=%s exact=%s bits=0x%08lx id=0x%08lx send=0x%08lx recv=0x%08lx remotePort=0x%08lx replyPort=0x%08lx windowId=0x%08lx arg1=%lu count=%lu\n",
            gCGSShapeWindowInlineCompatCallCount,
            mode ? mode : "(unset)",
            exact ? "YES" : "NO",
            (unsigned long)get_u32(m + 0x00U),
            (unsigned long)get_u32(m + 0x14U),
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            (unsigned long)get_u32(m + 0x08U),
            (unsigned long)rcv_name,
            (unsigned long)get_u32(m + CGS_SHAPEWINDOW_INLINE_WINDOW_ID_OFF),
            (unsigned long)get_u32(m + CGS_SHAPEWINDOW_INLINE_ARG1_OFF),
            (unsigned long)get_u32(m + CGS_SHAPEWINDOW_INLINE_COUNT_OFF));
    fflush(stderr);

    if (mode != NULL &&
        strcmp(mode, CGS_SHAPEWINDOW_INLINE_COMPAT_PASSTHROUGH) == 0) {
        fprintf(stderr,
                "PM_CGS_SHAPEWINDOW_INLINE_COMPAT_RESULT:PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    if (mode == NULL ||
        strcmp(mode, CGS_SHAPEWINDOW_INLINE_COMPAT_LION_V1) != 0 ||
        !exact ||
        gCGSShapeWindowInlineCompatCallCount != 1U) {
        fprintf(stderr,
                "PM_CGS_SHAPEWINDOW_INLINE_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    memset(storage, 0, sizeof(storage));
    memcpy(source_before, m, CGS_SHAPEWINDOW_INLINE_OBSERVED_SEND_SIZE);
    memcpy(adapted, m, CGS_SHAPEWINDOW_INLINE_OBSERVED_SEND_SIZE);
    put_u32(adapted + 0x14U, CGS_SHAPEWINDOW_INLINE_LION_REQUEST_ID);

    for (off = 0U; off < CGS_SHAPEWINDOW_INLINE_OBSERVED_SEND_SIZE; ++off) {
        if (adapted[off] != source_before[off]) {
            ++request_changed;
            if (off < 0x14U || off >= 0x18U)
                ++request_body_changed;
        }
        if (m[off] != source_before[off])
            ++source_changed;
    }

    fprintf(stderr,
            "PM_CGS_SHAPEWINDOW_INLINE_COMPAT_ADAPTED_REQUEST:index=%u legacyId=0x%08lx lionId=0x%08lx send=0x%08lx recv=0x%08lx changedBytes=%u bodyChangedBytes=%u sourceChangedBytes=%u windowId=0x%08lx count=%lu\n",
            gCGSShapeWindowInlineCompatCallCount,
            (unsigned long)get_u32(source_before + 0x14U),
            (unsigned long)get_u32(adapted + 0x14U),
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            request_changed,
            request_body_changed,
            source_changed,
            (unsigned long)get_u32(
                adapted + CGS_SHAPEWINDOW_INLINE_WINDOW_ID_OFF),
            (unsigned long)get_u32(
                adapted + CGS_SHAPEWINDOW_INLINE_COUNT_OFF));
    fflush(stderr);

    if (request_changed != 1U ||
        request_body_changed != 0U ||
        source_changed != 0U ||
        get_u32(adapted + 0x14U) !=
            CGS_SHAPEWINDOW_INLINE_LION_REQUEST_ID) {
        fprintf(stderr,
                "PM_CGS_SHAPEWINDOW_INLINE_COMPAT_RESULT:REQUEST_POSTCHECK_FAILED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    mr = call_original_mach_msg((mach_msg_header_t *)adapted,
                                option, send_size, rcv_size,
                                rcv_name, timeout, notify);

    fprintf(stderr,
            "PM_CGS_SHAPEWINDOW_INLINE_COMPAT_NATIVE_MACH_RETURN:index=%u kr=%ld hex=0x%08lx\n",
            gCGSShapeWindowInlineCompatCallCount,
            (long)mr,
            (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    native_reply_bits = get_u32(adapted + 0x00U);
    native_reply_size = get_u32(adapted + 0x04U);
    native_reply_id = get_u32(adapted + 0x14U);

    if (native_reply_size == CGS_SHAPEWINDOW_INLINE_REPLY_SIZE) {
        reply_swapped = cgs_shapewindow_inline_reply_is_swapped(adapted);
        native_result = decode_cgs_shapewindow_inline_result(adapted);
    }

    if (native_result == 0)
        reply_class = "SUCCESS";
    else
        reply_class = "ERROR";

    fprintf(stderr,
            "PM_CGS_SHAPEWINDOW_INLINE_COMPAT_NATIVE_REPLY:index=%u bits=0x%08lx size=0x%08lx id=0x%08lx result=%ld ndrSwapped=%s replyClass=%s raw20=0x%08lx\n",
            gCGSShapeWindowInlineCompatCallCount,
            (unsigned long)native_reply_bits,
            (unsigned long)native_reply_size,
            (unsigned long)native_reply_id,
            (long)native_result,
            reply_swapped ? "YES" : "NO",
            reply_class,
            native_reply_size >= CGS_SHAPEWINDOW_INLINE_REPLY_SIZE ?
                (unsigned long)get_u32(
                    adapted + CGS_SHAPEWINDOW_INLINE_RESULT_OFF) : 0UL);
    fflush(stderr);

    if (native_reply_bits != CGS_SHAPEWINDOW_INLINE_REPLY_BITS ||
        native_reply_size != CGS_SHAPEWINDOW_INLINE_REPLY_SIZE ||
        native_reply_id != CGS_SHAPEWINDOW_INLINE_LION_REPLY_ID ||
        !reply_swapped) {
        if (native_reply_size > 0U &&
            native_reply_size <= CGS_SHAPEWINDOW_INLINE_PRIVATE_BUFFER_SIZE)
            memcpy(m, adapted, native_reply_size);
        fprintf(stderr,
                "PM_CGS_SHAPEWINDOW_INLINE_COMPAT_RESULT:NATIVE_REPLY_REJECTED\n");
        fflush(stderr);
        return mr;
    }

    memcpy(native_reply_before, adapted, CGS_SHAPEWINDOW_INLINE_REPLY_SIZE);
    put_u32(adapted + 0x14U, CGS_SHAPEWINDOW_INLINE_LEGACY_REPLY_ID);

    for (off = 0U; off < CGS_SHAPEWINDOW_INLINE_REPLY_SIZE; ++off) {
        if (adapted[off] != native_reply_before[off]) {
            ++reply_changed;
            if (off < 0x14U || off >= 0x18U)
                ++reply_body_changed;
        }
    }

    adapted_result = decode_cgs_shapewindow_inline_result(adapted);

    if (reply_changed != 1U ||
        reply_body_changed != 0U ||
        get_u32(adapted + 0x14U) !=
            CGS_SHAPEWINDOW_INLINE_LEGACY_REPLY_ID ||
        adapted_result != native_result) {
        memcpy(m, native_reply_before, CGS_SHAPEWINDOW_INLINE_REPLY_SIZE);
        fprintf(stderr,
                "PM_CGS_SHAPEWINDOW_INLINE_COMPAT_RESULT:REPLY_POSTCHECK_FAILED_NATIVE_COPIED\n");
        fflush(stderr);
        return mr;
    }

    memcpy(m, adapted, CGS_SHAPEWINDOW_INLINE_REPLY_SIZE);
    fprintf(stderr,
            "PM_CGS_SHAPEWINDOW_INLINE_COMPAT_ADAPTED_REPLY:index=%u nativeId=0x%08lx legacyId=0x%08lx size=0x%08lx changedBytes=%u bodyChangedBytes=%u result=%ld replyClass=%s\n",
            gCGSShapeWindowInlineCompatCallCount,
            (unsigned long)CGS_SHAPEWINDOW_INLINE_LION_REPLY_ID,
            (unsigned long)get_u32(m + 0x14U),
            (unsigned long)get_u32(m + 0x04U),
            reply_changed,
            reply_body_changed,
            (long)adapted_result,
            reply_class);
    fprintf(stderr,
            "PM_CGS_SHAPEWINDOW_INLINE_COMPAT_RESULT:ADAPTER_PASS\n");
    fflush(stderr);
    return mr;
}
#endif

#ifdef PM_CGS_SYNCHRONIZE_WINDOW_BACKING_STORE_COMPAT_INTEGRATION
static uint32_t
cgs_backing_sync_swap_u32(uint32_t value)
{
    return ((value & 0x000000ffU) << 24) |
           ((value & 0x0000ff00U) << 8) |
           ((value & 0x00ff0000U) >> 8) |
           ((value & 0xff000000U) >> 24);
}

static int
cgs_backing_sync_reply_is_swapped(const unsigned char *message)
{
    const unsigned char *local_ndr = (const unsigned char *)&NDR_record;
    return message[CGS_BACKING_SYNC_NDR_OFF + 4U] != local_ndr[4];
}

static int32_t
decode_cgs_backing_sync_result(const unsigned char *message)
{
    uint32_t value = get_u32(message + CGS_BACKING_SYNC_RESULT_OFF);
    if (cgs_backing_sync_reply_is_swapped(message))
        value = cgs_backing_sync_swap_u32(value);
    return (int32_t)value;
}

static int
is_exact_legacy_cgs_backing_sync_request(
    mach_msg_header_t *msg,
    mach_msg_option_t option,
    mach_msg_size_t send_size,
    mach_msg_size_t rcv_size,
    mach_port_name_t rcv_name,
    mach_msg_timeout_t timeout,
    mach_port_name_t notify)
{
    unsigned char *m = (unsigned char *)msg;
    uint32_t window_id;

    if (msg == NULL)
        return 0;

    window_id = get_u32(m + CGS_BACKING_SYNC_WINDOW_ID_OFF);

    return get_u32(m + 0x00U) == CGS_BACKING_SYNC_BITS &&
           get_u32(m + 0x08U) != 0U &&
           get_u32(m + 0x08U) == (uint32_t)gCGSShowWindowTracePort &&
           get_u32(m + 0x0cU) == (uint32_t)rcv_name &&
           rcv_name != MACH_PORT_NULL &&
           get_u32(m + 0x14U) == CGS_BACKING_SYNC_LEGACY_REQUEST_ID &&
           option == (mach_msg_option_t)CGS_BACKING_SYNC_MSG_OPTIONS &&
           send_size == (mach_msg_size_t)CGS_BACKING_SYNC_SEND_SIZE &&
           rcv_size == (mach_msg_size_t)CGS_BACKING_SYNC_RECV_SIZE &&
           timeout == MACH_MSG_TIMEOUT_NONE &&
           notify == MACH_PORT_NULL &&
           memcmp(m + CGS_BACKING_SYNC_NDR_OFF,
                  &NDR_record, sizeof(NDR_record)) == 0 &&
           window_id != 0U &&
           get_u32(m + CGS_BACKING_SYNC_ARG1_OFF) == 3U &&
           get_u32(m + CGS_BACKING_SYNC_ARG2_OFF) == 1U &&
           (gCGSBackingSyncTargetWindowID == 0U ||
            gCGSBackingSyncTargetWindowID == window_id);
}

static mach_msg_return_t
handle_cgs_backing_sync_compat(
    mach_msg_header_t *msg,
    mach_msg_option_t option,
    mach_msg_size_t send_size,
    mach_msg_size_t rcv_size,
    mach_port_name_t rcv_name,
    mach_msg_timeout_t timeout,
    mach_port_name_t notify)
{
    const char *mode;
    unsigned char *m = (unsigned char *)msg;
    uint32_t storage[
        CGS_BACKING_SYNC_PRIVATE_BUFFER_SIZE / sizeof(uint32_t)];
    unsigned char *adapted = (unsigned char *)storage;
    unsigned char source_before[CGS_BACKING_SYNC_SEND_SIZE];
    unsigned char native_reply_before[CGS_BACKING_SYNC_REPLY_SIZE];
    mach_msg_return_t mr;
    uint32_t native_reply_bits;
    uint32_t native_reply_size;
    uint32_t native_reply_id;
    uint32_t window_id;
    uint32_t off;
    int32_t native_result = 0;
    int32_t adapted_result = 0;
    unsigned int request_changed = 0U;
    unsigned int request_body_changed = 0U;
    unsigned int source_changed = 0U;
    unsigned int reply_changed = 0U;
    unsigned int reply_body_changed = 0U;
    int exact;
    int reply_swapped = 0;
    const char *reply_class = "UNEXPECTED";

    ++gCGSBackingSyncCompatCallCount;
    mode = getenv(CGS_BACKING_SYNC_COMPAT_ENV);
    window_id = get_u32(m + CGS_BACKING_SYNC_WINDOW_ID_OFF);
    exact = is_exact_legacy_cgs_backing_sync_request(
        msg, option, send_size, rcv_size, rcv_name, timeout, notify);

    fprintf(stderr,
            "PM_CGS_BACKING_SYNC_COMPAT_CALL:index=%u exactIndex=%u mode=%s exact=%s bits=0x%08lx id=0x%08lx send=0x%08lx recv=0x%08lx remotePort=0x%08lx replyPort=0x%08lx windowId=0x%08lx arg1=%lu arg2=%lu\n",
            gCGSBackingSyncCompatCallCount,
            gCGSBackingSyncExactCallCount + (exact ? 1U : 0U),
            mode ? mode : "(unset)",
            exact ? "YES" : "NO",
            (unsigned long)get_u32(m + 0x00U),
            (unsigned long)get_u32(m + 0x14U),
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            (unsigned long)get_u32(m + 0x08U),
            (unsigned long)rcv_name,
            (unsigned long)window_id,
            (unsigned long)get_u32(m + CGS_BACKING_SYNC_ARG1_OFF),
            (unsigned long)get_u32(m + CGS_BACKING_SYNC_ARG2_OFF));
    fflush(stderr);

    if (mode != NULL &&
        strcmp(mode, CGS_BACKING_SYNC_COMPAT_PASSTHROUGH) == 0) {
        if (exact) {
            if (gCGSBackingSyncTargetWindowID == 0U)
                gCGSBackingSyncTargetWindowID = window_id;
            ++gCGSBackingSyncExactCallCount;
        }
        fprintf(stderr,
                "PM_CGS_BACKING_SYNC_COMPAT_RESULT:PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    if (mode == NULL ||
        strcmp(mode, CGS_BACKING_SYNC_COMPAT_LION_V1) != 0 ||
        !exact ||
        gCGSBackingSyncExactCallCount >= CGS_BACKING_SYNC_MAX_EXACT_CALLS) {
        fprintf(stderr,
                "PM_CGS_BACKING_SYNC_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    if (gCGSBackingSyncTargetWindowID == 0U)
        gCGSBackingSyncTargetWindowID = window_id;
    ++gCGSBackingSyncExactCallCount;

    memset(storage, 0, sizeof(storage));
    memcpy(source_before, m, CGS_BACKING_SYNC_SEND_SIZE);
    memcpy(adapted, m, CGS_BACKING_SYNC_SEND_SIZE);
    put_u32(adapted + 0x14U, CGS_BACKING_SYNC_LION_REQUEST_ID);

    for (off = 0U; off < CGS_BACKING_SYNC_SEND_SIZE; ++off) {
        if (adapted[off] != source_before[off]) {
            ++request_changed;
            if (off < 0x14U || off >= 0x18U)
                ++request_body_changed;
        }
        if (m[off] != source_before[off])
            ++source_changed;
    }

    fprintf(stderr,
            "PM_CGS_BACKING_SYNC_COMPAT_ADAPTED_REQUEST:index=%u legacyId=0x%08lx lionId=0x%08lx send=0x%08lx recv=0x%08lx changedBytes=%u bodyChangedBytes=%u sourceChangedBytes=%u windowId=0x%08lx arg1=%lu arg2=%lu\n",
            gCGSBackingSyncExactCallCount,
            (unsigned long)get_u32(source_before + 0x14U),
            (unsigned long)get_u32(adapted + 0x14U),
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            request_changed,
            request_body_changed,
            source_changed,
            (unsigned long)window_id,
            (unsigned long)get_u32(adapted + CGS_BACKING_SYNC_ARG1_OFF),
            (unsigned long)get_u32(adapted + CGS_BACKING_SYNC_ARG2_OFF));
    fflush(stderr);

    if (request_changed != 1U ||
        request_body_changed != 0U ||
        source_changed != 0U ||
        get_u32(adapted + 0x14U) != CGS_BACKING_SYNC_LION_REQUEST_ID) {
        fprintf(stderr,
                "PM_CGS_BACKING_SYNC_COMPAT_RESULT:REQUEST_POSTCHECK_FAILED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    mr = call_original_mach_msg((mach_msg_header_t *)adapted,
                                option, send_size, rcv_size,
                                rcv_name, timeout, notify);

    fprintf(stderr,
            "PM_CGS_BACKING_SYNC_COMPAT_NATIVE_MACH_RETURN:index=%u kr=%ld hex=0x%08lx\n",
            gCGSBackingSyncExactCallCount,
            (long)mr,
            (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    native_reply_bits = get_u32(adapted + 0x00U);
    native_reply_size = get_u32(adapted + 0x04U);
    native_reply_id = get_u32(adapted + 0x14U);

    if (native_reply_size == CGS_BACKING_SYNC_REPLY_SIZE) {
        reply_swapped = cgs_backing_sync_reply_is_swapped(adapted);
        native_result = decode_cgs_backing_sync_result(adapted);
    }
    reply_class = native_result == 0 ? "SUCCESS" : "ERROR";

    fprintf(stderr,
            "PM_CGS_BACKING_SYNC_COMPAT_NATIVE_REPLY:index=%u bits=0x%08lx size=0x%08lx id=0x%08lx result=%ld ndrSwapped=%s replyClass=%s raw20=0x%08lx\n",
            gCGSBackingSyncExactCallCount,
            (unsigned long)native_reply_bits,
            (unsigned long)native_reply_size,
            (unsigned long)native_reply_id,
            (long)native_result,
            reply_swapped ? "YES" : "NO",
            reply_class,
            native_reply_size >= CGS_BACKING_SYNC_REPLY_SIZE ?
                (unsigned long)get_u32(adapted + CGS_BACKING_SYNC_RESULT_OFF) : 0UL);
    fflush(stderr);

    if (native_reply_bits != CGS_BACKING_SYNC_REPLY_BITS ||
        native_reply_size != CGS_BACKING_SYNC_REPLY_SIZE ||
        native_reply_id != CGS_BACKING_SYNC_LION_REPLY_ID ||
        !reply_swapped) {
        if (native_reply_size > 0U &&
            native_reply_size <= CGS_BACKING_SYNC_PRIVATE_BUFFER_SIZE)
            memcpy(m, adapted, native_reply_size);
        fprintf(stderr,
                "PM_CGS_BACKING_SYNC_COMPAT_RESULT:NATIVE_REPLY_REJECTED\n");
        fflush(stderr);
        return mr;
    }

    memcpy(native_reply_before, adapted, CGS_BACKING_SYNC_REPLY_SIZE);
    put_u32(adapted + 0x14U, CGS_BACKING_SYNC_LEGACY_REPLY_ID);

    for (off = 0U; off < CGS_BACKING_SYNC_REPLY_SIZE; ++off) {
        if (adapted[off] != native_reply_before[off]) {
            ++reply_changed;
            if (off < 0x14U || off >= 0x18U)
                ++reply_body_changed;
        }
    }

    adapted_result = decode_cgs_backing_sync_result(adapted);

    if (reply_changed != 1U ||
        reply_body_changed != 0U ||
        get_u32(adapted + 0x14U) != CGS_BACKING_SYNC_LEGACY_REPLY_ID ||
        adapted_result != native_result) {
        memcpy(m, native_reply_before, CGS_BACKING_SYNC_REPLY_SIZE);
        fprintf(stderr,
                "PM_CGS_BACKING_SYNC_COMPAT_RESULT:REPLY_POSTCHECK_FAILED_NATIVE_COPIED\n");
        fflush(stderr);
        return mr;
    }

    memcpy(m, adapted, CGS_BACKING_SYNC_REPLY_SIZE);
    fprintf(stderr,
            "PM_CGS_BACKING_SYNC_COMPAT_ADAPTED_REPLY:index=%u nativeId=0x%08lx legacyId=0x%08lx size=0x%08lx changedBytes=%u bodyChangedBytes=%u result=%ld replyClass=%s\n",
            gCGSBackingSyncExactCallCount,
            (unsigned long)CGS_BACKING_SYNC_LION_REPLY_ID,
            (unsigned long)get_u32(m + 0x14U),
            (unsigned long)get_u32(m + 0x04U),
            reply_changed,
            reply_body_changed,
            (long)adapted_result,
            reply_class);
    fprintf(stderr,
            "PM_CGS_BACKING_SYNC_COMPAT_RESULT:ADAPTER_PASS\n");
    fflush(stderr);
    return mr;
}
#endif

#ifdef PM_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_INTEGRATION
static uint32_t
cgs_add_tracking_area_swap_u32(uint32_t value)
{
    return ((value & 0x000000ffU) << 24) |
           ((value & 0x0000ff00U) << 8) |
           ((value & 0x00ff0000U) >> 8) |
           ((value & 0xff000000U) >> 24);
}

static int
cgs_add_tracking_area_reply_is_swapped(const unsigned char *message)
{
    const unsigned char *local_ndr = (const unsigned char *)&NDR_record;

    return message[CGS_ADD_TRACKING_AREA_NDR_OFF + 4U] != local_ndr[4];
}

static int32_t
decode_cgs_add_tracking_area_result(const unsigned char *message)
{
    uint32_t value = get_u32(message + CGS_ADD_TRACKING_AREA_RESULT_OFF);

    if (cgs_add_tracking_area_reply_is_swapped(message))
        value = cgs_add_tracking_area_swap_u32(value);
    return (int32_t)value;
}

static int
is_exact_legacy_cgs_add_tracking_area_request(
    mach_msg_header_t *msg,
    mach_msg_option_t option,
    mach_msg_size_t send_size,
    mach_msg_size_t rcv_size,
    mach_port_name_t rcv_name,
    mach_msg_timeout_t timeout,
    mach_port_name_t notify)
{
    unsigned char *m = (unsigned char *)msg;
    uint32_t count;

    if (msg == NULL)
        return 0;

    count = get_u32(m + CGS_ADD_TRACKING_AREA_COUNT_OFF);

    return get_u32(m + 0x00U) == CGS_ADD_TRACKING_AREA_LEGACY_BITS &&
           get_u32(m + 0x08U) != 0U &&
           get_u32(m + 0x08U) == (uint32_t)gCGSShowWindowTracePort &&
           get_u32(m + 0x0cU) == (uint32_t)rcv_name &&
           rcv_name != MACH_PORT_NULL &&
           get_u32(m + 0x14U) ==
               CGS_ADD_TRACKING_AREA_INLINE_LEGACY_REQUEST_ID &&
           option == (mach_msg_option_t)CGS_ADD_TRACKING_AREA_MSG_OPTIONS &&
           send_size ==
               (mach_msg_size_t)CGS_ADD_TRACKING_AREA_OBSERVED_SEND_SIZE &&
           send_size == (mach_msg_size_t)(0x3cU + 4U * count) &&
           rcv_size == (mach_msg_size_t)CGS_ADD_TRACKING_AREA_RECV_SIZE &&
           timeout == MACH_MSG_TIMEOUT_NONE &&
           notify == MACH_PORT_NULL &&
           memcmp(m + CGS_ADD_TRACKING_AREA_NDR_OFF,
                  &NDR_record, sizeof(NDR_record)) == 0 &&
           get_u32(m + CGS_ADD_TRACKING_AREA_WINDOW_ID_OFF) != 0U &&
           count == CGS_ADD_TRACKING_AREA_OBSERVED_COUNT;
}

static mach_msg_return_t
handle_cgs_add_tracking_area_compat(mach_msg_header_t *msg,
                                    mach_msg_option_t option,
                                    mach_msg_size_t send_size,
                                    mach_msg_size_t rcv_size,
                                    mach_port_name_t rcv_name,
                                    mach_msg_timeout_t timeout,
                                    mach_port_name_t notify)
{
    const char *mode;
    unsigned char *m = (unsigned char *)msg;
    uint32_t storage[
        CGS_ADD_TRACKING_AREA_PRIVATE_BUFFER_SIZE / sizeof(uint32_t)];
    unsigned char *adapted = (unsigned char *)storage;
    unsigned char source_before[CGS_ADD_TRACKING_AREA_OBSERVED_SEND_SIZE];
    unsigned char native_reply_before[CGS_ADD_TRACKING_AREA_REPLY_SIZE];
    mach_msg_return_t mr;
    uint32_t native_reply_bits;
    uint32_t native_reply_size;
    uint32_t native_reply_id;
    uint32_t off;
    int32_t native_result = 0;
    int32_t adapted_result = 0;
    unsigned int request_changed = 0U;
    unsigned int request_body_changed = 0U;
    unsigned int source_changed = 0U;
    unsigned int reply_changed = 0U;
    unsigned int reply_body_changed = 0U;
    int exact;
    int reply_swapped = 0;
    const char *reply_class = "UNEXPECTED";

    ++gCGSAddTrackingAreaCompatCallCount;
    mode = getenv(CGS_ADD_TRACKING_AREA_COMPAT_ENV);
    exact = is_exact_legacy_cgs_add_tracking_area_request(
        msg, option, send_size, rcv_size, rcv_name, timeout, notify);

    fprintf(stderr,
            "PM_CGS_ADD_TRACKING_AREA_COMPAT_CALL:index=%u mode=%s exact=%s bits=0x%08lx id=0x%08lx send=0x%08lx recv=0x%08lx remotePort=0x%08lx replyPort=0x%08lx windowId=0x%08lx count=%lu opacityCreateCompatCalls=%u\n",
            gCGSAddTrackingAreaCompatCallCount,
            mode ? mode : "(unset)",
            exact ? "YES" : "NO",
            (unsigned long)get_u32(m + 0x00U),
            (unsigned long)get_u32(m + 0x14U),
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            (unsigned long)get_u32(m + 0x08U),
            (unsigned long)rcv_name,
            (unsigned long)get_u32(m + CGS_ADD_TRACKING_AREA_WINDOW_ID_OFF),
            (unsigned long)get_u32(m + CGS_ADD_TRACKING_AREA_COUNT_OFF),
            gCGSOpacityAlphaCreateCompatCallCount);
    fflush(stderr);

    if (mode != NULL &&
        strcmp(mode, CGS_ADD_TRACKING_AREA_COMPAT_PASSTHROUGH) == 0) {
        fprintf(stderr,
                "PM_CGS_ADD_TRACKING_AREA_COMPAT_RESULT:PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    if (mode == NULL ||
        strcmp(mode, CGS_ADD_TRACKING_AREA_COMPAT_LION_V1) != 0 ||
        !exact ||
        gCGSAddTrackingAreaCompatCallCount != 1U ||
        gCGSOpacityAlphaCreateCompatCallCount != 1U) {
        fprintf(stderr,
                "PM_CGS_ADD_TRACKING_AREA_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    memset(storage, 0, sizeof(storage));
    memcpy(source_before, m, CGS_ADD_TRACKING_AREA_OBSERVED_SEND_SIZE);
    memcpy(adapted, m, CGS_ADD_TRACKING_AREA_OBSERVED_SEND_SIZE);
    put_u32(adapted + 0x14U,
            CGS_ADD_TRACKING_AREA_INLINE_LION_REQUEST_ID);

    for (off = 0U; off < CGS_ADD_TRACKING_AREA_OBSERVED_SEND_SIZE; ++off) {
        if (adapted[off] != source_before[off]) {
            ++request_changed;
            if (off < 0x14U || off >= 0x18U)
                ++request_body_changed;
        }
        if (m[off] != source_before[off])
            ++source_changed;
    }

    fprintf(stderr,
            "PM_CGS_ADD_TRACKING_AREA_COMPAT_ADAPTED_REQUEST:index=%u legacyId=0x%08lx lionId=0x%08lx send=0x%08lx recv=0x%08lx changedBytes=%u bodyChangedBytes=%u sourceChangedBytes=%u windowId=0x%08lx count=%lu\n",
            gCGSAddTrackingAreaCompatCallCount,
            (unsigned long)get_u32(source_before + 0x14U),
            (unsigned long)get_u32(adapted + 0x14U),
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            request_changed,
            request_body_changed,
            source_changed,
            (unsigned long)get_u32(
                adapted + CGS_ADD_TRACKING_AREA_WINDOW_ID_OFF),
            (unsigned long)get_u32(
                adapted + CGS_ADD_TRACKING_AREA_COUNT_OFF));
    fflush(stderr);

    if (request_changed != 1U ||
        request_body_changed != 0U ||
        source_changed != 0U ||
        get_u32(adapted + 0x14U) !=
            CGS_ADD_TRACKING_AREA_INLINE_LION_REQUEST_ID) {
        fprintf(stderr,
                "PM_CGS_ADD_TRACKING_AREA_COMPAT_RESULT:REQUEST_POSTCHECK_FAILED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    mr = call_original_mach_msg((mach_msg_header_t *)adapted,
                                option,
                                send_size,
                                rcv_size,
                                rcv_name,
                                timeout,
                                notify);

    fprintf(stderr,
            "PM_CGS_ADD_TRACKING_AREA_COMPAT_NATIVE_MACH_RETURN:index=%u kr=%ld hex=0x%08lx\n",
            gCGSAddTrackingAreaCompatCallCount,
            (long)mr,
            (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    native_reply_bits = get_u32(adapted + 0x00U);
    native_reply_size = get_u32(adapted + 0x04U);
    native_reply_id = get_u32(adapted + 0x14U);

    if (native_reply_size == CGS_ADD_TRACKING_AREA_REPLY_SIZE) {
        reply_swapped = cgs_add_tracking_area_reply_is_swapped(adapted);
        native_result = decode_cgs_add_tracking_area_result(adapted);
    }

    if (native_result == 0)
        reply_class = "SUCCESS";
    else
        reply_class = "ERROR";

    fprintf(stderr,
            "PM_CGS_ADD_TRACKING_AREA_COMPAT_NATIVE_REPLY:index=%u bits=0x%08lx size=0x%08lx id=0x%08lx result=%ld ndrSwapped=%s replyClass=%s raw20=0x%08lx\n",
            gCGSAddTrackingAreaCompatCallCount,
            (unsigned long)native_reply_bits,
            (unsigned long)native_reply_size,
            (unsigned long)native_reply_id,
            (long)native_result,
            reply_swapped ? "YES" : "NO",
            reply_class,
            native_reply_size >= CGS_ADD_TRACKING_AREA_REPLY_SIZE ?
                (unsigned long)get_u32(
                    adapted + CGS_ADD_TRACKING_AREA_RESULT_OFF) : 0UL);
    fflush(stderr);

    if (native_reply_bits != CGS_ADD_TRACKING_AREA_REPLY_BITS ||
        native_reply_size != CGS_ADD_TRACKING_AREA_REPLY_SIZE ||
        native_reply_id != CGS_ADD_TRACKING_AREA_INLINE_LION_REPLY_ID ||
        !reply_swapped) {
        if (native_reply_size > 0U &&
            native_reply_size <= CGS_ADD_TRACKING_AREA_PRIVATE_BUFFER_SIZE)
            memcpy(m, adapted, native_reply_size);
        fprintf(stderr,
                "PM_CGS_ADD_TRACKING_AREA_COMPAT_RESULT:NATIVE_REPLY_REJECTED\n");
        fflush(stderr);
        return mr;
    }

    memcpy(native_reply_before, adapted, CGS_ADD_TRACKING_AREA_REPLY_SIZE);
    put_u32(adapted + 0x14U,
            CGS_ADD_TRACKING_AREA_INLINE_LEGACY_REPLY_ID);

    for (off = 0U; off < CGS_ADD_TRACKING_AREA_REPLY_SIZE; ++off) {
        if (adapted[off] != native_reply_before[off]) {
            ++reply_changed;
            if (off < 0x14U || off >= 0x18U)
                ++reply_body_changed;
        }
    }

    adapted_result = decode_cgs_add_tracking_area_result(adapted);

    if (reply_changed != 1U ||
        reply_body_changed != 0U ||
        get_u32(adapted + 0x14U) !=
            CGS_ADD_TRACKING_AREA_INLINE_LEGACY_REPLY_ID ||
        adapted_result != native_result) {
        memcpy(m, native_reply_before, CGS_ADD_TRACKING_AREA_REPLY_SIZE);
        fprintf(stderr,
                "PM_CGS_ADD_TRACKING_AREA_COMPAT_RESULT:REPLY_POSTCHECK_FAILED_NATIVE_COPIED\n");
        fflush(stderr);
        return mr;
    }

    memcpy(m, adapted, CGS_ADD_TRACKING_AREA_REPLY_SIZE);
    fprintf(stderr,
            "PM_CGS_ADD_TRACKING_AREA_COMPAT_ADAPTED_REPLY:index=%u nativeId=0x%08lx legacyId=0x%08lx size=0x%08lx changedBytes=%u bodyChangedBytes=%u result=%ld replyClass=%s\n",
            gCGSAddTrackingAreaCompatCallCount,
            (unsigned long)CGS_ADD_TRACKING_AREA_INLINE_LION_REPLY_ID,
            (unsigned long)get_u32(m + 0x14U),
            (unsigned long)get_u32(m + 0x04U),
            reply_changed,
            reply_body_changed,
            (long)adapted_result,
            reply_class);
    fprintf(stderr,
            "PM_CGS_ADD_TRACKING_AREA_COMPAT_RESULT:ADAPTER_PASS\n");
    fflush(stderr);
    return mr;
}
#endif

#ifdef PM_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_INTEGRATION
static uint32_t
cgs_order_front_conditionally_swap_u32(uint32_t value)
{
    return ((value & 0x000000ffU) << 24) |
           ((value & 0x0000ff00U) << 8) |
           ((value & 0x00ff0000U) >> 8) |
           ((value & 0xff000000U) >> 24);
}

static int
cgs_order_front_conditionally_reply_is_swapped(const unsigned char *message)
{
    const unsigned char *local_ndr = (const unsigned char *)&NDR_record;

    return message[CGS_ORDER_FRONT_CONDITIONALLY_NDR_OFF + 4U] !=
           local_ndr[4];
}

static int32_t
decode_cgs_order_front_conditionally_result(const unsigned char *message)
{
    uint32_t value =
        get_u32(message + CGS_ORDER_FRONT_CONDITIONALLY_RESULT_OFF);

    if (cgs_order_front_conditionally_reply_is_swapped(message))
        value = cgs_order_front_conditionally_swap_u32(value);
    return (int32_t)value;
}

static int
is_exact_legacy_cgs_order_front_conditionally_request(
    mach_msg_header_t *msg,
    mach_msg_option_t option,
    mach_msg_size_t send_size,
    mach_msg_size_t rcv_size,
    mach_port_name_t rcv_name,
    mach_msg_timeout_t timeout,
    mach_port_name_t notify)
{
    unsigned char *m = (unsigned char *)msg;

    if (msg == NULL)
        return 0;

    return get_u32(m + 0x00U) == CGS_ORDER_FRONT_CONDITIONALLY_BITS &&
           get_u32(m + 0x08U) != 0U &&
           get_u32(m + 0x08U) == (uint32_t)gCGSShowWindowTracePort &&
           get_u32(m + 0x0cU) == (uint32_t)rcv_name &&
           rcv_name != MACH_PORT_NULL &&
           get_u32(m + 0x14U) ==
               CGS_ORDER_FRONT_CONDITIONALLY_LEGACY_REQUEST_ID &&
           option ==
               (mach_msg_option_t)CGS_ORDER_FRONT_CONDITIONALLY_MSG_OPTIONS &&
           send_size ==
               (mach_msg_size_t)CGS_ORDER_FRONT_CONDITIONALLY_SEND_SIZE &&
           rcv_size ==
               (mach_msg_size_t)CGS_ORDER_FRONT_CONDITIONALLY_RECV_SIZE &&
           timeout == MACH_MSG_TIMEOUT_NONE &&
           notify == MACH_PORT_NULL &&
           memcmp(m + CGS_ORDER_FRONT_CONDITIONALLY_NDR_OFF,
                  &NDR_record, sizeof(NDR_record)) == 0 &&
           get_u32(m + CGS_ORDER_FRONT_CONDITIONALLY_WINDOW_ID_OFF) != 0U;
}

static mach_msg_return_t
handle_cgs_order_front_conditionally_compat(
    mach_msg_header_t *msg,
    mach_msg_option_t option,
    mach_msg_size_t send_size,
    mach_msg_size_t rcv_size,
    mach_port_name_t rcv_name,
    mach_msg_timeout_t timeout,
    mach_port_name_t notify)
{
    const char *mode;
    unsigned char *m = (unsigned char *)msg;
    uint32_t storage[
        CGS_ORDER_FRONT_CONDITIONALLY_PRIVATE_BUFFER_SIZE / sizeof(uint32_t)];
    unsigned char *adapted = (unsigned char *)storage;
    unsigned char source_before[CGS_ORDER_FRONT_CONDITIONALLY_SEND_SIZE];
    unsigned char native_reply_before[CGS_ORDER_FRONT_CONDITIONALLY_REPLY_SIZE];
    mach_msg_return_t mr;
    uint32_t native_reply_bits;
    uint32_t native_reply_size;
    uint32_t native_reply_id;
    uint32_t off;
    int32_t native_result = 0;
    int32_t adapted_result = 0;
    unsigned int request_changed = 0U;
    unsigned int request_body_changed = 0U;
    unsigned int source_changed = 0U;
    unsigned int reply_changed = 0U;
    unsigned int reply_body_changed = 0U;
    int exact;
    int lion_showwindow_mode;
    int lion_selectwindow_mode;
    int call_index_ok;
    int reply_swapped = 0;
    const char *reply_class = "UNEXPECTED";

    ++gCGSOrderFrontConditionallyCompatCallCount;
    mode = getenv(CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_ENV);
    exact = is_exact_legacy_cgs_order_front_conditionally_request(
        msg, option, send_size, rcv_size, rcv_name, timeout, notify);
    lion_showwindow_mode =
        mode != NULL &&
        strcmp(mode, CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_LION_V1) == 0;
    lion_selectwindow_mode =
        mode != NULL &&
        strcmp(mode,
               CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_LION_SELECTWINDOW_V1) == 0;
    call_index_ok =
        (gCGSOrderFrontConditionallyCompatCallCount == 1U &&
         gCGSAddTrackingAreaCompatCallCount == 0U) ||
        (lion_selectwindow_mode &&
         gCGSOrderFrontConditionallyCompatCallCount == 2U &&
         gCGSAddTrackingAreaCompatCallCount == 1U);

    fprintf(stderr,
            "PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_CALL:index=%u mode=%s exact=%s bits=0x%08lx id=0x%08lx send=0x%08lx recv=0x%08lx remotePort=0x%08lx replyPort=0x%08lx arg0=0x%08lx arg1=0x%08lx windowId=0x%08lx arg3=0x%08lx arg4=0x%08lx opacityCreateCompatCalls=%u addTrackingCompatCalls=%u\n",
            gCGSOrderFrontConditionallyCompatCallCount,
            mode ? mode : "(unset)",
            exact ? "YES" : "NO",
            (unsigned long)get_u32(m + 0x00U),
            (unsigned long)get_u32(m + 0x14U),
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            (unsigned long)get_u32(m + 0x08U),
            (unsigned long)rcv_name,
            (unsigned long)get_u32(
                m + CGS_ORDER_FRONT_CONDITIONALLY_ARG0_OFF),
            (unsigned long)get_u32(
                m + CGS_ORDER_FRONT_CONDITIONALLY_ARG1_OFF),
            (unsigned long)get_u32(
                m + CGS_ORDER_FRONT_CONDITIONALLY_WINDOW_ID_OFF),
            (unsigned long)get_u32(
                m + CGS_ORDER_FRONT_CONDITIONALLY_ARG3_OFF),
            (unsigned long)get_u32(
                m + CGS_ORDER_FRONT_CONDITIONALLY_ARG4_OFF),
            gCGSOpacityAlphaCreateCompatCallCount,
            gCGSAddTrackingAreaCompatCallCount);
    fflush(stderr);

    if (mode != NULL &&
        strcmp(mode,
               CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_PASSTHROUGH) == 0) {
        fprintf(stderr,
                "PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    if ((!lion_showwindow_mode && !lion_selectwindow_mode) ||
        !exact ||
        !call_index_ok ||
        gCGSOpacityAlphaCreateCompatCallCount != 1U) {
        fprintf(stderr,
                "PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    memset(storage, 0, sizeof(storage));
    memcpy(source_before, m, CGS_ORDER_FRONT_CONDITIONALLY_SEND_SIZE);
    memcpy(adapted, m, CGS_ORDER_FRONT_CONDITIONALLY_SEND_SIZE);
    put_u32(adapted + 0x14U,
            CGS_ORDER_FRONT_CONDITIONALLY_LION_REQUEST_ID);

    for (off = 0U; off < CGS_ORDER_FRONT_CONDITIONALLY_SEND_SIZE; ++off) {
        if (adapted[off] != source_before[off]) {
            ++request_changed;
            if (off < 0x14U || off >= 0x18U)
                ++request_body_changed;
        }
        if (m[off] != source_before[off])
            ++source_changed;
    }

    fprintf(stderr,
            "PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_ADAPTED_REQUEST:index=%u legacyId=0x%08lx lionId=0x%08lx send=0x%08lx recv=0x%08lx changedBytes=%u bodyChangedBytes=%u sourceChangedBytes=%u windowId=0x%08lx\n",
            gCGSOrderFrontConditionallyCompatCallCount,
            (unsigned long)get_u32(source_before + 0x14U),
            (unsigned long)get_u32(adapted + 0x14U),
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            request_changed,
            request_body_changed,
            source_changed,
            (unsigned long)get_u32(
                adapted + CGS_ORDER_FRONT_CONDITIONALLY_WINDOW_ID_OFF));
    fflush(stderr);

    if (request_changed != 1U ||
        request_body_changed != 0U ||
        source_changed != 0U ||
        get_u32(adapted + 0x14U) !=
            CGS_ORDER_FRONT_CONDITIONALLY_LION_REQUEST_ID) {
        fprintf(stderr,
                "PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:REQUEST_POSTCHECK_FAILED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    mr = call_original_mach_msg((mach_msg_header_t *)adapted,
                                option,
                                send_size,
                                rcv_size,
                                rcv_name,
                                timeout,
                                notify);

    fprintf(stderr,
            "PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_NATIVE_MACH_RETURN:index=%u kr=%ld hex=0x%08lx\n",
            gCGSOrderFrontConditionallyCompatCallCount,
            (long)mr,
            (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    native_reply_bits = get_u32(adapted + 0x00U);
    native_reply_size = get_u32(adapted + 0x04U);
    native_reply_id = get_u32(adapted + 0x14U);

    if (native_reply_size == CGS_ORDER_FRONT_CONDITIONALLY_REPLY_SIZE) {
        reply_swapped =
            cgs_order_front_conditionally_reply_is_swapped(adapted);
        native_result = decode_cgs_order_front_conditionally_result(adapted);
    }

    if (native_result == 0)
        reply_class = "SUCCESS";
    else
        reply_class = "ERROR";

    fprintf(stderr,
            "PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_NATIVE_REPLY:index=%u bits=0x%08lx size=0x%08lx id=0x%08lx result=%ld ndrSwapped=%s replyClass=%s raw20=0x%08lx\n",
            gCGSOrderFrontConditionallyCompatCallCount,
            (unsigned long)native_reply_bits,
            (unsigned long)native_reply_size,
            (unsigned long)native_reply_id,
            (long)native_result,
            reply_swapped ? "YES" : "NO",
            reply_class,
            native_reply_size >= CGS_ORDER_FRONT_CONDITIONALLY_REPLY_SIZE ?
                (unsigned long)get_u32(
                    adapted + CGS_ORDER_FRONT_CONDITIONALLY_RESULT_OFF) :
                0UL);
    fflush(stderr);

    if (native_reply_bits != CGS_ORDER_FRONT_CONDITIONALLY_REPLY_BITS ||
        native_reply_size != CGS_ORDER_FRONT_CONDITIONALLY_REPLY_SIZE ||
        native_reply_id != CGS_ORDER_FRONT_CONDITIONALLY_LION_REPLY_ID ||
        !reply_swapped) {
        if (native_reply_size > 0U &&
            native_reply_size <=
                CGS_ORDER_FRONT_CONDITIONALLY_PRIVATE_BUFFER_SIZE)
            memcpy(m, adapted, native_reply_size);
        fprintf(stderr,
                "PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:NATIVE_REPLY_REJECTED\n");
        fflush(stderr);
        return mr;
    }

    memcpy(native_reply_before, adapted,
           CGS_ORDER_FRONT_CONDITIONALLY_REPLY_SIZE);
    put_u32(adapted + 0x14U,
            CGS_ORDER_FRONT_CONDITIONALLY_LEGACY_REPLY_ID);

    for (off = 0U; off < CGS_ORDER_FRONT_CONDITIONALLY_REPLY_SIZE; ++off) {
        if (adapted[off] != native_reply_before[off]) {
            ++reply_changed;
            if (off < 0x14U || off >= 0x18U)
                ++reply_body_changed;
        }
    }

    adapted_result = decode_cgs_order_front_conditionally_result(adapted);

    if (reply_changed != 1U ||
        reply_body_changed != 0U ||
        get_u32(adapted + 0x14U) !=
            CGS_ORDER_FRONT_CONDITIONALLY_LEGACY_REPLY_ID ||
        adapted_result != native_result) {
        memcpy(m, native_reply_before,
               CGS_ORDER_FRONT_CONDITIONALLY_REPLY_SIZE);
        fprintf(stderr,
                "PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:REPLY_POSTCHECK_FAILED_NATIVE_COPIED\n");
        fflush(stderr);
        return mr;
    }

    memcpy(m, adapted, CGS_ORDER_FRONT_CONDITIONALLY_REPLY_SIZE);
    fprintf(stderr,
            "PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_ADAPTED_REPLY:index=%u nativeId=0x%08lx legacyId=0x%08lx size=0x%08lx changedBytes=%u bodyChangedBytes=%u result=%ld replyClass=%s\n",
            gCGSOrderFrontConditionallyCompatCallCount,
            (unsigned long)CGS_ORDER_FRONT_CONDITIONALLY_LION_REPLY_ID,
            (unsigned long)get_u32(m + 0x14U),
            (unsigned long)get_u32(m + 0x04U),
            reply_changed,
            reply_body_changed,
            (long)adapted_result,
            reply_class);
    fprintf(stderr,
            "PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS\n");
    fflush(stderr);
    return mr;
}
#endif

#ifdef PM_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_INTEGRATION
static uint32_t
cgs_set_front_window_swap_u32(uint32_t value)
{
    return ((value & 0x000000ffU) << 24) |
           ((value & 0x0000ff00U) << 8) |
           ((value & 0x00ff0000U) >> 8) |
           ((value & 0xff000000U) >> 24);
}

static int
cgs_set_front_window_reply_is_swapped(const unsigned char *message)
{
    const unsigned char *local_ndr = (const unsigned char *)&NDR_record;

    return message[CGS_SET_FRONT_WINDOW_NDR_OFF + 4U] != local_ndr[4];
}

static int32_t
decode_cgs_set_front_window_result(const unsigned char *message)
{
    uint32_t value = get_u32(message + CGS_SET_FRONT_WINDOW_RESULT_OFF);

    if (cgs_set_front_window_reply_is_swapped(message))
        value = cgs_set_front_window_swap_u32(value);
    return (int32_t)value;
}

static int
is_exact_legacy_cgs_set_front_window_request(
    mach_msg_header_t *msg,
    mach_msg_option_t option,
    mach_msg_size_t send_size,
    mach_msg_size_t rcv_size,
    mach_port_name_t rcv_name,
    mach_msg_timeout_t timeout,
    mach_port_name_t notify)
{
    unsigned char *m = (unsigned char *)msg;

    if (msg == NULL)
        return 0;

    return get_u32(m + 0x00U) == CGS_SET_FRONT_WINDOW_BITS &&
           get_u32(m + 0x08U) != 0U &&
           get_u32(m + 0x08U) == (uint32_t)gCGSShowWindowTracePort &&
           get_u32(m + 0x0cU) == (uint32_t)rcv_name &&
           rcv_name != MACH_PORT_NULL &&
           get_u32(m + 0x14U) == CGS_SET_FRONT_WINDOW_LEGACY_REQUEST_ID &&
           option == (mach_msg_option_t)CGS_SET_FRONT_WINDOW_MSG_OPTIONS &&
           send_size == (mach_msg_size_t)CGS_SET_FRONT_WINDOW_SEND_SIZE &&
           rcv_size == (mach_msg_size_t)CGS_SET_FRONT_WINDOW_RECV_SIZE &&
           timeout == MACH_MSG_TIMEOUT_NONE &&
           notify == MACH_PORT_NULL &&
           memcmp(m + CGS_SET_FRONT_WINDOW_NDR_OFF,
                  &NDR_record, sizeof(NDR_record)) == 0 &&
           get_u32(m + CGS_SET_FRONT_WINDOW_WINDOW_ID_OFF) != 0U;
}

static mach_msg_return_t
handle_cgs_set_front_window_compat(
    mach_msg_header_t *msg,
    mach_msg_option_t option,
    mach_msg_size_t send_size,
    mach_msg_size_t rcv_size,
    mach_port_name_t rcv_name,
    mach_msg_timeout_t timeout,
    mach_port_name_t notify)
{
    const char *mode;
    unsigned char *m = (unsigned char *)msg;
    uint32_t storage[
        CGS_SET_FRONT_WINDOW_PRIVATE_BUFFER_SIZE / sizeof(uint32_t)];
    unsigned char *adapted = (unsigned char *)storage;
    unsigned char source_before[CGS_SET_FRONT_WINDOW_SEND_SIZE];
    unsigned char native_reply_before[CGS_SET_FRONT_WINDOW_REPLY_SIZE];
    mach_msg_return_t mr;
    uint32_t native_reply_bits;
    uint32_t native_reply_size;
    uint32_t native_reply_id;
    uint32_t off;
    int32_t native_result = 0;
    int32_t adapted_result = 0;
    unsigned int request_changed = 0U;
    unsigned int request_body_changed = 0U;
    unsigned int source_changed = 0U;
    unsigned int reply_changed = 0U;
    unsigned int reply_body_changed = 0U;
    int exact;
    int reply_swapped = 0;
    const char *reply_class = "UNEXPECTED";

    ++gCGSSetFrontWindowCompatCallCount;
    mode = getenv(CGS_SET_FRONT_WINDOW_COMPAT_ENV);
    exact = is_exact_legacy_cgs_set_front_window_request(
        msg, option, send_size, rcv_size, rcv_name, timeout, notify);

    fprintf(stderr,
            "PM_CGS_SET_FRONT_WINDOW_COMPAT_CALL:index=%u mode=%s exact=%s bits=0x%08lx id=0x%08lx send=0x%08lx recv=0x%08lx remotePort=0x%08lx replyPort=0x%08lx windowId=0x%08lx opacityCreateCompatCalls=%u orderFrontCompatCalls=%u addTrackingCompatCalls=%u\n",
            gCGSSetFrontWindowCompatCallCount,
            mode ? mode : "(unset)",
            exact ? "YES" : "NO",
            (unsigned long)get_u32(m + 0x00U),
            (unsigned long)get_u32(m + 0x14U),
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            (unsigned long)get_u32(m + 0x08U),
            (unsigned long)rcv_name,
            (unsigned long)get_u32(m + CGS_SET_FRONT_WINDOW_WINDOW_ID_OFF),
            gCGSOpacityAlphaCreateCompatCallCount,
            gCGSOrderFrontConditionallyCompatCallCount,
            gCGSAddTrackingAreaCompatCallCount);
    fflush(stderr);

    if (mode != NULL &&
        strcmp(mode, CGS_SET_FRONT_WINDOW_COMPAT_PASSTHROUGH) == 0) {
        fprintf(stderr,
                "PM_CGS_SET_FRONT_WINDOW_COMPAT_RESULT:PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    if (mode == NULL ||
        strcmp(mode, CGS_SET_FRONT_WINDOW_COMPAT_LION_V1) != 0 ||
        !exact ||
        gCGSSetFrontWindowCompatCallCount != 1U ||
        gCGSOpacityAlphaCreateCompatCallCount != 1U ||
        gCGSOrderFrontConditionallyCompatCallCount != 1U ||
        gCGSAddTrackingAreaCompatCallCount != 1U) {
        fprintf(stderr,
                "PM_CGS_SET_FRONT_WINDOW_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    memset(storage, 0, sizeof(storage));
    memcpy(source_before, m, CGS_SET_FRONT_WINDOW_SEND_SIZE);
    memcpy(adapted, m, CGS_SET_FRONT_WINDOW_SEND_SIZE);
    put_u32(adapted + 0x14U, CGS_SET_FRONT_WINDOW_LION_REQUEST_ID);

    for (off = 0U; off < CGS_SET_FRONT_WINDOW_SEND_SIZE; ++off) {
        if (adapted[off] != source_before[off]) {
            ++request_changed;
            if (off < 0x14U || off >= 0x18U)
                ++request_body_changed;
        }
        if (m[off] != source_before[off])
            ++source_changed;
    }

    fprintf(stderr,
            "PM_CGS_SET_FRONT_WINDOW_COMPAT_ADAPTED_REQUEST:index=%u legacyId=0x%08lx lionId=0x%08lx send=0x%08lx recv=0x%08lx changedBytes=%u bodyChangedBytes=%u sourceChangedBytes=%u windowId=0x%08lx\n",
            gCGSSetFrontWindowCompatCallCount,
            (unsigned long)get_u32(source_before + 0x14U),
            (unsigned long)get_u32(adapted + 0x14U),
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            request_changed,
            request_body_changed,
            source_changed,
            (unsigned long)get_u32(
                adapted + CGS_SET_FRONT_WINDOW_WINDOW_ID_OFF));
    fflush(stderr);

    if (request_changed != 1U ||
        request_body_changed != 0U ||
        source_changed != 0U ||
        get_u32(adapted + 0x14U) != CGS_SET_FRONT_WINDOW_LION_REQUEST_ID) {
        fprintf(stderr,
                "PM_CGS_SET_FRONT_WINDOW_COMPAT_RESULT:REQUEST_POSTCHECK_FAILED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    mr = call_original_mach_msg((mach_msg_header_t *)adapted,
                                option,
                                send_size,
                                rcv_size,
                                rcv_name,
                                timeout,
                                notify);

    fprintf(stderr,
            "PM_CGS_SET_FRONT_WINDOW_COMPAT_NATIVE_MACH_RETURN:index=%u kr=%ld hex=0x%08lx\n",
            gCGSSetFrontWindowCompatCallCount,
            (long)mr,
            (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    native_reply_bits = get_u32(adapted + 0x00U);
    native_reply_size = get_u32(adapted + 0x04U);
    native_reply_id = get_u32(adapted + 0x14U);

    if (native_reply_size == CGS_SET_FRONT_WINDOW_REPLY_SIZE) {
        reply_swapped = cgs_set_front_window_reply_is_swapped(adapted);
        native_result = decode_cgs_set_front_window_result(adapted);
    }

    if (native_result == 0)
        reply_class = "SUCCESS";
    else
        reply_class = "ERROR";

    fprintf(stderr,
            "PM_CGS_SET_FRONT_WINDOW_COMPAT_NATIVE_REPLY:index=%u bits=0x%08lx size=0x%08lx id=0x%08lx result=%ld ndrSwapped=%s replyClass=%s raw20=0x%08lx\n",
            gCGSSetFrontWindowCompatCallCount,
            (unsigned long)native_reply_bits,
            (unsigned long)native_reply_size,
            (unsigned long)native_reply_id,
            (long)native_result,
            reply_swapped ? "YES" : "NO",
            reply_class,
            native_reply_size >= CGS_SET_FRONT_WINDOW_REPLY_SIZE ?
                (unsigned long)get_u32(
                    adapted + CGS_SET_FRONT_WINDOW_RESULT_OFF) : 0UL);
    fflush(stderr);

    if (native_reply_bits != CGS_SET_FRONT_WINDOW_REPLY_BITS ||
        native_reply_size != CGS_SET_FRONT_WINDOW_REPLY_SIZE ||
        native_reply_id != CGS_SET_FRONT_WINDOW_LION_REPLY_ID ||
        !reply_swapped) {
        if (native_reply_size > 0U &&
            native_reply_size <= CGS_SET_FRONT_WINDOW_PRIVATE_BUFFER_SIZE)
            memcpy(m, adapted, native_reply_size);
        fprintf(stderr,
                "PM_CGS_SET_FRONT_WINDOW_COMPAT_RESULT:NATIVE_REPLY_REJECTED\n");
        fflush(stderr);
        return mr;
    }

    memcpy(native_reply_before, adapted, CGS_SET_FRONT_WINDOW_REPLY_SIZE);
    put_u32(adapted + 0x14U, CGS_SET_FRONT_WINDOW_LEGACY_REPLY_ID);

    for (off = 0U; off < CGS_SET_FRONT_WINDOW_REPLY_SIZE; ++off) {
        if (adapted[off] != native_reply_before[off]) {
            ++reply_changed;
            if (off < 0x14U || off >= 0x18U)
                ++reply_body_changed;
        }
    }

    adapted_result = decode_cgs_set_front_window_result(adapted);

    if (reply_changed != 1U ||
        reply_body_changed != 0U ||
        get_u32(adapted + 0x14U) != CGS_SET_FRONT_WINDOW_LEGACY_REPLY_ID ||
        adapted_result != native_result) {
        memcpy(m, native_reply_before, CGS_SET_FRONT_WINDOW_REPLY_SIZE);
        fprintf(stderr,
                "PM_CGS_SET_FRONT_WINDOW_COMPAT_RESULT:REPLY_POSTCHECK_FAILED_NATIVE_COPIED\n");
        fflush(stderr);
        return mr;
    }

    memcpy(m, adapted, CGS_SET_FRONT_WINDOW_REPLY_SIZE);
    fprintf(stderr,
            "PM_CGS_SET_FRONT_WINDOW_COMPAT_ADAPTED_REPLY:index=%u nativeId=0x%08lx legacyId=0x%08lx size=0x%08lx changedBytes=%u bodyChangedBytes=%u result=%ld replyClass=%s\n",
            gCGSSetFrontWindowCompatCallCount,
            (unsigned long)CGS_SET_FRONT_WINDOW_LION_REPLY_ID,
            (unsigned long)get_u32(m + 0x14U),
            (unsigned long)get_u32(m + 0x04U),
            reply_changed,
            reply_body_changed,
            (long)adapted_result,
            reply_class);
    fprintf(stderr,
            "PM_CGS_SET_FRONT_WINDOW_COMPAT_RESULT:ADAPTER_PASS\n");
    fflush(stderr);
    return mr;
}
#endif

#ifdef PM_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_INTEGRATION
static int
is_exact_legacy_cgs_color_profile_client_request(
    mach_msg_header_t *msg,
    mach_msg_option_t option,
    mach_msg_size_t send_size,
    mach_msg_size_t rcv_size,
    mach_port_name_t rcv_name,
    mach_msg_timeout_t timeout,
    mach_port_name_t notify)
{
    unsigned char *m = (unsigned char *)msg;

    if (msg == NULL)
        return 0;

    /*
     * Keep "exact" identical to the passive live-trace geometry.  Port
     * provenance is Lion-only state and is checked separately by the adapter:
     * Snow's one successful ColorProfileClient request occurs before the first
     * CreateNewWindow request has established gCGSShowWindowTracePort.
     * The NDR bytes are preserved verbatim by this ID-only adapter and are not
     * an additional recognition constraint.
     */
    return get_u32(m + 0x00U) == CGS_COLOR_PROFILE_CLIENT_BITS &&
           get_u32(m + 0x08U) != 0U &&
           get_u32(m + 0x0cU) == (uint32_t)rcv_name &&
           rcv_name != MACH_PORT_NULL &&
           get_u32(m + 0x14U) == CGS_COLOR_PROFILE_CLIENT_LEGACY_REQUEST_ID &&
           option == (mach_msg_option_t)CGS_COLOR_PROFILE_CLIENT_MSG_OPTIONS &&
           send_size == (mach_msg_size_t)CGS_COLOR_PROFILE_CLIENT_SEND_SIZE &&
           rcv_size == (mach_msg_size_t)CGS_COLOR_PROFILE_CLIENT_RECV_SIZE &&
           timeout == MACH_MSG_TIMEOUT_NONE &&
           notify == MACH_PORT_NULL &&
           get_u32(m + CGS_COLOR_PROFILE_CLIENT_DESC_COUNT_OFF) == 1U &&
           get_u32(m + CGS_COLOR_PROFILE_CLIENT_DESC_PORT_OFF) != 0U &&
           m[CGS_COLOR_PROFILE_CLIENT_DESC_DISPOSITION_OFF] == 0x13U &&
           m[CGS_COLOR_PROFILE_CLIENT_DESC_TYPE_OFF] == 0x00U &&
           get_u32(m + CGS_COLOR_PROFILE_CLIENT_PID_OFF) != 0U;
}

static mach_msg_return_t
handle_cgs_color_profile_client_compat(
    mach_msg_header_t *msg,
    mach_msg_option_t option,
    mach_msg_size_t send_size,
    mach_msg_size_t rcv_size,
    mach_port_name_t rcv_name,
    mach_msg_timeout_t timeout,
    mach_port_name_t notify)
{
    const char *mode;
    unsigned char *m = (unsigned char *)msg;
    uint32_t storage[
        CGS_COLOR_PROFILE_CLIENT_PRIVATE_BUFFER_SIZE / sizeof(uint32_t)];
    unsigned char *adapted = (unsigned char *)storage;
    unsigned char source_before[CGS_COLOR_PROFILE_CLIENT_SEND_SIZE];
    unsigned char native_reply_before[CGS_COLOR_PROFILE_CLIENT_SUCCESS_REPLY_SIZE];
    mach_msg_return_t mr;
    uint32_t native_reply_bits;
    uint32_t native_reply_size;
    uint32_t native_reply_id;
    uint32_t native_result_raw = 0U;
    uint32_t native_client_id_raw = 0U;
    uint32_t adapted_result_raw = 0U;
    uint32_t adapted_client_id_raw = 0U;
    uint32_t off;
    unsigned int request_changed = 0U;
    unsigned int request_body_changed = 0U;
    unsigned int source_changed = 0U;
    unsigned int reply_changed = 0U;
    unsigned int reply_body_changed = 0U;
    int exact;
    int lion_port_exact;
    const char *reply_class = "UNEXPECTED";

    ++gCGSColorProfileClientCompatCallCount;
    mode = getenv(CGS_COLOR_PROFILE_CLIENT_COMPAT_ENV);
    exact = is_exact_legacy_cgs_color_profile_client_request(
        msg, option, send_size, rcv_size, rcv_name, timeout, notify);
    lion_port_exact =
        gCGSShowWindowTracePort != MACH_PORT_NULL &&
        get_u32(m + 0x08U) != 0U &&
        get_u32(m + 0x08U) != (uint32_t)gCGSShowWindowTracePort;

    fprintf(stderr,
            "PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_CALL:index=%u mode=%s exact=%s lionPortExact=%s applicationPort=0x%08lx bits=0x%08lx id=0x%08lx send=0x%08lx recv=0x%08lx remotePort=0x%08lx replyPort=0x%08lx descriptorCount=%lu descriptorPort=0x%08lx disposition=0x%02x type=0x%02x pid=%lu newWindowCompatCalls=%u releaseBackingCompatCalls=%u opacityCreateCompatCalls=%u orderFrontCompatCalls=%u addTrackingCompatCalls=%u setFrontWindowCompatCalls=%u\n",
            gCGSColorProfileClientCompatCallCount,
            mode ? mode : "(unset)",
            exact ? "YES" : "NO",
            lion_port_exact ? "YES" : "NO",
            (unsigned long)(uint32_t)gCGSShowWindowTracePort,
            (unsigned long)get_u32(m + 0x00U),
            (unsigned long)get_u32(m + 0x14U),
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            (unsigned long)get_u32(m + 0x08U),
            (unsigned long)rcv_name,
            (unsigned long)get_u32(m + CGS_COLOR_PROFILE_CLIENT_DESC_COUNT_OFF),
            (unsigned long)get_u32(m + CGS_COLOR_PROFILE_CLIENT_DESC_PORT_OFF),
            (unsigned int)m[CGS_COLOR_PROFILE_CLIENT_DESC_DISPOSITION_OFF],
            (unsigned int)m[CGS_COLOR_PROFILE_CLIENT_DESC_TYPE_OFF],
            (unsigned long)get_u32(m + CGS_COLOR_PROFILE_CLIENT_PID_OFF),
            gCGSNewWindowCompatCallCount,
            gCGSReleaseBackingCompatCallCount,
            gCGSOpacityAlphaCreateCompatCallCount,
            gCGSOrderFrontConditionallyCompatCallCount,
            gCGSAddTrackingAreaCompatCallCount,
            gCGSSetFrontWindowCompatCallCount);
    fflush(stderr);

    if (mode != NULL &&
        strcmp(mode, CGS_COLOR_PROFILE_CLIENT_COMPAT_PASSTHROUGH) == 0) {
        fprintf(stderr,
                "PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    if (mode == NULL ||
        strcmp(mode, CGS_COLOR_PROFILE_CLIENT_COMPAT_LION_V1) != 0 ||
        !exact ||
        !lion_port_exact ||
        gCGSColorProfileClientCompatCallCount != 1U ||
        gCGSNewWindowCompatCallCount != 1U ||
        gCGSReleaseBackingCompatCallCount != 1U ||
        gCGSOpacityAlphaCreateCompatCallCount != 1U ||
        gCGSOrderFrontConditionallyCompatCallCount != 0U ||
        gCGSAddTrackingAreaCompatCallCount != 0U ||
        gCGSSetFrontWindowCompatCallCount != 0U) {
        fprintf(stderr,
                "PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    memset(storage, 0, sizeof(storage));
    memcpy(source_before, m, CGS_COLOR_PROFILE_CLIENT_SEND_SIZE);
    memcpy(adapted, m, CGS_COLOR_PROFILE_CLIENT_SEND_SIZE);
    put_u32(adapted + 0x14U, CGS_COLOR_PROFILE_CLIENT_LION_REQUEST_ID);

    for (off = 0U; off < CGS_COLOR_PROFILE_CLIENT_SEND_SIZE; ++off) {
        if (adapted[off] != source_before[off]) {
            ++request_changed;
            if (off < 0x14U || off >= 0x18U)
                ++request_body_changed;
        }
        if (m[off] != source_before[off])
            ++source_changed;
    }

    fprintf(stderr,
            "PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_ADAPTED_REQUEST:index=%u legacyId=0x%08lx lionId=0x%08lx send=0x%08lx recv=0x%08lx changedBytes=%u bodyChangedBytes=%u sourceChangedBytes=%u descriptorPort=0x%08lx pid=%lu\n",
            gCGSColorProfileClientCompatCallCount,
            (unsigned long)get_u32(source_before + 0x14U),
            (unsigned long)get_u32(adapted + 0x14U),
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            request_changed,
            request_body_changed,
            source_changed,
            (unsigned long)get_u32(
                adapted + CGS_COLOR_PROFILE_CLIENT_DESC_PORT_OFF),
            (unsigned long)get_u32(
                adapted + CGS_COLOR_PROFILE_CLIENT_PID_OFF));
    fflush(stderr);

    if (request_changed != 1U ||
        request_body_changed != 0U ||
        source_changed != 0U ||
        get_u32(adapted + 0x14U) != CGS_COLOR_PROFILE_CLIENT_LION_REQUEST_ID) {
        fprintf(stderr,
                "PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:REQUEST_POSTCHECK_FAILED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    mr = call_original_mach_msg((mach_msg_header_t *)adapted,
                                option, send_size, rcv_size,
                                rcv_name, timeout, notify);

    fprintf(stderr,
            "PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_NATIVE_MACH_RETURN:index=%u kr=%ld hex=0x%08lx\n",
            gCGSColorProfileClientCompatCallCount,
            (long)mr,
            (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    native_reply_bits = get_u32(adapted + 0x00U);
    native_reply_size = get_u32(adapted + 0x04U);
    native_reply_id = get_u32(adapted + 0x14U);

    if (native_reply_size >= CGS_COLOR_PROFILE_CLIENT_ERROR_REPLY_SIZE)
        native_result_raw =
            get_u32(adapted + CGS_COLOR_PROFILE_CLIENT_RESULT_OFF);
    if (native_reply_size >= CGS_COLOR_PROFILE_CLIENT_SUCCESS_REPLY_SIZE)
        native_client_id_raw =
            get_u32(adapted + CGS_COLOR_PROFILE_CLIENT_ID_OFF);

    if (native_reply_size == CGS_COLOR_PROFILE_CLIENT_SUCCESS_REPLY_SIZE &&
        native_result_raw == 0U &&
        native_client_id_raw != 0U)
        reply_class = "SUCCESS";
    else if (native_reply_size == CGS_COLOR_PROFILE_CLIENT_ERROR_REPLY_SIZE &&
             native_result_raw != 0U)
        reply_class = "ERROR";

    fprintf(stderr,
            "PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_NATIVE_REPLY:index=%u bits=0x%08lx size=0x%08lx id=0x%08lx resultRaw=0x%08lx clientIdRaw=0x%08lx replyClass=%s\n",
            gCGSColorProfileClientCompatCallCount,
            (unsigned long)native_reply_bits,
            (unsigned long)native_reply_size,
            (unsigned long)native_reply_id,
            (unsigned long)native_result_raw,
            (unsigned long)native_client_id_raw,
            reply_class);
    fflush(stderr);

    if (native_reply_bits != CGS_COLOR_PROFILE_CLIENT_REPLY_BITS ||
        native_reply_id != CGS_COLOR_PROFILE_CLIENT_LION_REPLY_ID ||
        (native_reply_size != CGS_COLOR_PROFILE_CLIENT_SUCCESS_REPLY_SIZE &&
         native_reply_size != CGS_COLOR_PROFILE_CLIENT_ERROR_REPLY_SIZE) ||
        strcmp(reply_class, "UNEXPECTED") == 0) {
        if (native_reply_size > 0U &&
            native_reply_size <= CGS_COLOR_PROFILE_CLIENT_PRIVATE_BUFFER_SIZE)
            memcpy(m, adapted, native_reply_size);
        fprintf(stderr,
                "PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:NATIVE_REPLY_REJECTED\n");
        fflush(stderr);
        return mr;
    }

    memcpy(native_reply_before, adapted, native_reply_size);
    put_u32(adapted + 0x14U, CGS_COLOR_PROFILE_CLIENT_LEGACY_REPLY_ID);

    for (off = 0U; off < native_reply_size; ++off) {
        if (adapted[off] != native_reply_before[off]) {
            ++reply_changed;
            if (off < 0x14U || off >= 0x18U)
                ++reply_body_changed;
        }
    }

    adapted_result_raw =
        get_u32(adapted + CGS_COLOR_PROFILE_CLIENT_RESULT_OFF);
    if (native_reply_size >= CGS_COLOR_PROFILE_CLIENT_SUCCESS_REPLY_SIZE)
        adapted_client_id_raw =
            get_u32(adapted + CGS_COLOR_PROFILE_CLIENT_ID_OFF);

    if (reply_changed != 1U ||
        reply_body_changed != 0U ||
        get_u32(adapted + 0x14U) != CGS_COLOR_PROFILE_CLIENT_LEGACY_REPLY_ID ||
        adapted_result_raw != native_result_raw ||
        adapted_client_id_raw != native_client_id_raw) {
        memcpy(m, native_reply_before, native_reply_size);
        fprintf(stderr,
                "PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:REPLY_POSTCHECK_FAILED_NATIVE_COPIED\n");
        fflush(stderr);
        return mr;
    }

    memcpy(m, adapted, native_reply_size);
#ifdef PM_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_INTEGRATION
    if (strcmp(reply_class, "SUCCESS") == 0) {
        gCGSColorProfileClientCompatAdapterPassed = 1;
        gCGSColorProfileClientCompatSemanticClientID =
            cgs_color_profile_decode_u32(
                native_reply_before,
                CGS_COLOR_PROFILE_CLIENT_REPLY_NDR_OFF,
                CGS_COLOR_PROFILE_CLIENT_ID_OFF);
        gCGSColorProfileClientCompatRemotePort =
            (mach_port_t)get_u32(source_before + 0x08U);
        gCGSColorProfileClientCompatReplyPort = rcv_name;
        gCGSColorProfileClientCompatDescriptorPort =
            (mach_port_t)get_u32(
                source_before + CGS_COLOR_PROFILE_CLIENT_DESC_PORT_OFF);
        fprintf(stderr,
                "%s\n",
                CGS_COLOR_PROFILE_RESOLVE_COMPAT_BUILD_MARKER);
        fprintf(stderr,
                "PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_PREREQ:cpcAdapterPassed=YES clientId=%lu remotePort=0x%08lx replyPort=0x%08lx descriptorPort=0x%08lx\n",
                (unsigned long)gCGSColorProfileClientCompatSemanticClientID,
                (unsigned long)(uint32_t)gCGSColorProfileClientCompatRemotePort,
                (unsigned long)(uint32_t)gCGSColorProfileClientCompatReplyPort,
                (unsigned long)(uint32_t)gCGSColorProfileClientCompatDescriptorPort);
        fflush(stderr);
    }
#endif
    fprintf(stderr,
            "PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_ADAPTED_REPLY:index=%u nativeId=0x%08lx legacyId=0x%08lx size=0x%08lx changedBytes=%u bodyChangedBytes=%u resultRaw=0x%08lx clientIdRaw=0x%08lx replyClass=%s\n",
            gCGSColorProfileClientCompatCallCount,
            (unsigned long)CGS_COLOR_PROFILE_CLIENT_LION_REPLY_ID,
            (unsigned long)get_u32(m + 0x14U),
            (unsigned long)get_u32(m + 0x04U),
            reply_changed,
            reply_body_changed,
            (unsigned long)adapted_result_raw,
            (unsigned long)adapted_client_id_raw,
            reply_class);
    fprintf(stderr,
            "PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS\n");
    fflush(stderr);
    return mr;
}
#endif

#ifdef PM_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_INTEGRATION
static int
is_exact_legacy_cgs_color_profile_resolve_request(
    mach_msg_header_t *msg,
    mach_msg_option_t option,
    mach_msg_size_t send_size,
    mach_msg_size_t rcv_size,
    mach_port_name_t rcv_name,
    mach_msg_timeout_t timeout,
    mach_port_name_t notify)
{
    unsigned char *m = (unsigned char *)msg;

    if (msg == NULL)
        return 0;

    return get_u32(m + 0x00U) == CGS_COLOR_PROFILE_RESOLVE_BITS &&
           get_u32(m + 0x08U) != 0U &&
           get_u32(m + 0x0cU) == (uint32_t)rcv_name &&
           rcv_name != MACH_PORT_NULL &&
           get_u32(m + 0x14U) == CGS_COLOR_PROFILE_RESOLVE_LEGACY_REQUEST_ID &&
           option == (mach_msg_option_t)CGS_COLOR_PROFILE_RESOLVE_MSG_OPTIONS &&
           send_size == (mach_msg_size_t)CGS_COLOR_PROFILE_RESOLVE_SEND_SIZE &&
           rcv_size == (mach_msg_size_t)CGS_COLOR_PROFILE_RESOLVE_RECV_SIZE &&
           timeout == MACH_MSG_TIMEOUT_NONE &&
           notify == MACH_PORT_NULL &&
           get_u32(m + CGS_COLOR_PROFILE_RESOLVE_DESC_COUNT_OFF) == 1U &&
           get_u32(m + CGS_COLOR_PROFILE_RESOLVE_DESC_PORT_OFF) != 0U &&
           m[CGS_COLOR_PROFILE_RESOLVE_DESC_DISPOSITION_OFF] == 0x13U &&
           m[CGS_COLOR_PROFILE_RESOLVE_DESC_TYPE_OFF] == 0x00U &&
           cgs_color_profile_decode_u32(
               m,
               CGS_COLOR_PROFILE_RESOLVE_NDR_OFF,
               CGS_COLOR_PROFILE_RESOLVE_CLIENT_ID_OFF) != 0U &&
           cgs_color_profile_decode_u32(
               m,
               CGS_COLOR_PROFILE_RESOLVE_NDR_OFF,
               CGS_COLOR_PROFILE_RESOLVE_PROFILE_ID_OFF) == 1U;
}

static mach_msg_return_t
handle_cgs_color_profile_resolve_compat(
    mach_msg_header_t *msg,
    mach_msg_option_t option,
    mach_msg_size_t send_size,
    mach_msg_size_t rcv_size,
    mach_port_name_t rcv_name,
    mach_msg_timeout_t timeout,
    mach_port_name_t notify)
{
    const char *mode;
    unsigned char *m = (unsigned char *)msg;
    uint32_t storage[
        CGS_COLOR_PROFILE_RESOLVE_PRIVATE_BUFFER_SIZE / sizeof(uint32_t)];
    unsigned char *adapted = (unsigned char *)storage;
    unsigned char source_before[CGS_COLOR_PROFILE_RESOLVE_SEND_SIZE];
    unsigned char native_reply_before[CGS_COLOR_PROFILE_RESOLVE_SUCCESS_REPLY_SIZE];
    mach_msg_return_t mr;
    uint32_t native_reply_bits;
    uint32_t native_reply_size;
    uint32_t native_reply_id;
    uint32_t request_client_id;
    uint32_t request_profile_id;
    uint32_t native_result_raw = 0U;
    uint32_t native_out0_lo_raw = 0U;
    uint32_t native_out0_hi_raw = 0U;
    uint32_t native_out1_lo_raw = 0U;
    uint32_t native_out1_hi_raw = 0U;
    uint32_t off;
    unsigned int request_changed = 0U;
    unsigned int request_body_changed = 0U;
    unsigned int source_changed = 0U;
    unsigned int reply_changed = 0U;
    unsigned int reply_body_changed = 0U;
    int exact;
    int provenance_exact;

    ++gCGSColorProfileResolveCompatCallCount;
    mode = getenv(CGS_COLOR_PROFILE_RESOLVE_COMPAT_ENV);
    exact = is_exact_legacy_cgs_color_profile_resolve_request(
        msg, option, send_size, rcv_size, rcv_name, timeout, notify);
    request_client_id = exact ?
        cgs_color_profile_decode_u32(
            m,
            CGS_COLOR_PROFILE_RESOLVE_NDR_OFF,
            CGS_COLOR_PROFILE_RESOLVE_CLIENT_ID_OFF) : 0U;
    request_profile_id = exact ?
        cgs_color_profile_decode_u32(
            m,
            CGS_COLOR_PROFILE_RESOLVE_NDR_OFF,
            CGS_COLOR_PROFILE_RESOLVE_PROFILE_ID_OFF) : 0U;
    provenance_exact =
        exact &&
        gCGSColorProfileClientCompatAdapterPassed &&
        gCGSColorProfileClientCompatSemanticClientID != 0U &&
        request_client_id == gCGSColorProfileClientCompatSemanticClientID &&
        get_u32(m + 0x08U) ==
            (uint32_t)gCGSColorProfileClientCompatRemotePort &&
        rcv_name == gCGSColorProfileClientCompatReplyPort &&
        get_u32(m + CGS_COLOR_PROFILE_RESOLVE_DESC_PORT_OFF) ==
            (uint32_t)gCGSColorProfileClientCompatDescriptorPort;

    fprintf(stderr, "%s\n", CGS_COLOR_PROFILE_RESOLVE_COMPAT_BUILD_MARKER);
    fprintf(stderr,
            "PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_CALL:index=%u adapted=%u mode=%s exact=%s provenanceExact=%s clientId=%lu expectedClientId=%lu profileId=%lu remotePort=0x%08lx expectedRemotePort=0x%08lx replyPort=0x%08lx expectedReplyPort=0x%08lx descriptorPort=0x%08lx expectedDescriptorPort=0x%08lx\n",
            gCGSColorProfileResolveCompatCallCount,
            gCGSColorProfileResolveAdaptedCallCount,
            mode ? mode : "(unset)",
            exact ? "YES" : "NO",
            provenance_exact ? "YES" : "NO",
            (unsigned long)request_client_id,
            (unsigned long)gCGSColorProfileClientCompatSemanticClientID,
            (unsigned long)request_profile_id,
            (unsigned long)get_u32(m + 0x08U),
            (unsigned long)(uint32_t)gCGSColorProfileClientCompatRemotePort,
            (unsigned long)rcv_name,
            (unsigned long)(uint32_t)gCGSColorProfileClientCompatReplyPort,
            (unsigned long)get_u32(
                m + CGS_COLOR_PROFILE_RESOLVE_DESC_PORT_OFF),
            (unsigned long)(uint32_t)gCGSColorProfileClientCompatDescriptorPort);
    fflush(stderr);

    if (mode != NULL &&
        strcmp(mode, CGS_COLOR_PROFILE_RESOLVE_COMPAT_PASSTHROUGH) == 0) {
        fprintf(stderr,
                "PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    if (mode == NULL ||
        strcmp(mode, CGS_COLOR_PROFILE_RESOLVE_COMPAT_LION_V1) != 0 ||
        !provenance_exact ||
        gCGSColorProfileClientCompatCallCount != 1U ||
        gCGSColorProfileResolveAdaptedCallCount >=
            CGS_COLOR_PROFILE_RESOLVE_MAX_ADAPTED_CALLS) {
        fprintf(stderr,
                "PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    memset(storage, 0, sizeof(storage));
    memcpy(source_before, m, CGS_COLOR_PROFILE_RESOLVE_SEND_SIZE);
    memcpy(adapted, m, CGS_COLOR_PROFILE_RESOLVE_SEND_SIZE);
    put_u32(adapted + 0x14U, CGS_COLOR_PROFILE_RESOLVE_LION_REQUEST_ID);

    for (off = 0U; off < CGS_COLOR_PROFILE_RESOLVE_SEND_SIZE; ++off) {
        if (adapted[off] != source_before[off]) {
            ++request_changed;
            if (off < 0x14U || off >= 0x18U)
                ++request_body_changed;
        }
        if (m[off] != source_before[off])
            ++source_changed;
    }

    if (request_changed != 1U ||
        request_body_changed != 0U ||
        source_changed != 0U ||
        get_u32(adapted + 0x14U) !=
            CGS_COLOR_PROFILE_RESOLVE_LION_REQUEST_ID) {
        fprintf(stderr,
                "PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:REQUEST_POSTCHECK_FAILED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    ++gCGSColorProfileResolveAdaptedCallCount;
    fprintf(stderr,
            "PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_ADAPTED_REQUEST:index=%u legacyId=0x%08lx lionId=0x%08lx send=0x%08lx recv=0x%08lx changedBytes=%u bodyChangedBytes=%u sourceChangedBytes=%u clientId=%lu profileId=%lu\n",
            gCGSColorProfileResolveAdaptedCallCount,
            (unsigned long)get_u32(source_before + 0x14U),
            (unsigned long)get_u32(adapted + 0x14U),
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            request_changed,
            request_body_changed,
            source_changed,
            (unsigned long)request_client_id,
            (unsigned long)request_profile_id);
    fflush(stderr);

    mr = call_original_mach_msg((mach_msg_header_t *)adapted,
                                option, send_size, rcv_size,
                                rcv_name, timeout, notify);
    fprintf(stderr,
            "PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_NATIVE_MACH_RETURN:index=%u kr=%ld hex=0x%08lx\n",
            gCGSColorProfileResolveAdaptedCallCount,
            (long)mr,
            (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    native_reply_bits = get_u32(adapted + 0x00U);
    native_reply_size = get_u32(adapted + 0x04U);
    native_reply_id = get_u32(adapted + 0x14U);
    if (native_reply_size >= CGS_COLOR_PROFILE_RESOLVE_ERROR_REPLY_SIZE)
        native_result_raw =
            get_u32(adapted + CGS_COLOR_PROFILE_RESOLVE_RESULT_OFF);
    if (native_reply_size >= CGS_COLOR_PROFILE_RESOLVE_SUCCESS_REPLY_SIZE) {
        native_out0_lo_raw =
            get_u32(adapted + CGS_COLOR_PROFILE_RESOLVE_OUT0_LO_OFF);
        native_out0_hi_raw =
            get_u32(adapted + CGS_COLOR_PROFILE_RESOLVE_OUT0_HI_OFF);
        native_out1_lo_raw =
            get_u32(adapted + CGS_COLOR_PROFILE_RESOLVE_OUT1_LO_OFF);
        native_out1_hi_raw =
            get_u32(adapted + CGS_COLOR_PROFILE_RESOLVE_OUT1_HI_OFF);
    }

    fprintf(stderr,
            "PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_NATIVE_REPLY:index=%u bits=0x%08lx size=0x%08lx id=0x%08lx resultRaw=0x%08lx out0LoRaw=0x%08lx out0HiRaw=0x%08lx out1LoRaw=0x%08lx out1HiRaw=0x%08lx\n",
            gCGSColorProfileResolveAdaptedCallCount,
            (unsigned long)native_reply_bits,
            (unsigned long)native_reply_size,
            (unsigned long)native_reply_id,
            (unsigned long)native_result_raw,
            (unsigned long)native_out0_lo_raw,
            (unsigned long)native_out0_hi_raw,
            (unsigned long)native_out1_lo_raw,
            (unsigned long)native_out1_hi_raw);
    fflush(stderr);

    if (native_reply_bits != 0x00001200U ||
        native_reply_id != CGS_COLOR_PROFILE_RESOLVE_LION_REPLY_ID ||
        (native_reply_size != CGS_COLOR_PROFILE_RESOLVE_SUCCESS_REPLY_SIZE &&
         native_reply_size != CGS_COLOR_PROFILE_RESOLVE_ERROR_REPLY_SIZE)) {
        if (native_reply_size > 0U &&
            native_reply_size <= CGS_COLOR_PROFILE_RESOLVE_PRIVATE_BUFFER_SIZE)
            memcpy(m, adapted, native_reply_size);
        fprintf(stderr,
                "PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:NATIVE_REPLY_REJECTED\n");
        fflush(stderr);
        return mr;
    }

    memcpy(native_reply_before, adapted, native_reply_size);
    put_u32(adapted + 0x14U, CGS_COLOR_PROFILE_RESOLVE_LEGACY_REPLY_ID);

    for (off = 0U; off < native_reply_size; ++off) {
        if (adapted[off] != native_reply_before[off]) {
            ++reply_changed;
            if (off < 0x14U || off >= 0x18U)
                ++reply_body_changed;
        }
    }

    if (reply_changed != 1U ||
        reply_body_changed != 0U ||
        get_u32(adapted + 0x14U) !=
            CGS_COLOR_PROFILE_RESOLVE_LEGACY_REPLY_ID) {
        memcpy(m, native_reply_before, native_reply_size);
        fprintf(stderr,
                "PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:REPLY_POSTCHECK_FAILED_NATIVE_COPIED\n");
        fflush(stderr);
        return mr;
    }

    memcpy(m, adapted, native_reply_size);
    fprintf(stderr,
            "PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_ADAPTED_REPLY:index=%u nativeId=0x%08lx legacyId=0x%08lx size=0x%08lx changedBytes=%u bodyChangedBytes=%u resultRaw=0x%08lx out0LoRaw=0x%08lx out0HiRaw=0x%08lx out1LoRaw=0x%08lx out1HiRaw=0x%08lx\n",
            gCGSColorProfileResolveAdaptedCallCount,
            (unsigned long)CGS_COLOR_PROFILE_RESOLVE_LION_REPLY_ID,
            (unsigned long)get_u32(m + 0x14U),
            (unsigned long)get_u32(m + 0x04U),
            reply_changed,
            reply_body_changed,
            (unsigned long)native_result_raw,
            (unsigned long)native_out0_lo_raw,
            (unsigned long)native_out0_hi_raw,
            (unsigned long)native_out1_lo_raw,
            (unsigned long)native_out1_hi_raw);
    fprintf(stderr,
            "PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS\n");
    fflush(stderr);
    return mr;
}
#endif

#ifdef PM_CGS_SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_INTEGRATION
static int
is_exact_legacy_cgs_window_backing_info_request(
    mach_msg_header_t *msg,
    mach_msg_option_t option,
    mach_msg_size_t send_size,
    mach_msg_size_t rcv_size,
    mach_port_name_t rcv_name,
    mach_msg_timeout_t timeout,
    mach_port_name_t notify)
{
    unsigned char *m = (unsigned char *)msg;

    if (msg == NULL)
        return 0;

    return get_u32(m + 0x00U) == CGS_WINDOW_BACKING_INFO_BITS &&
           get_u32(m + 0x08U) != 0U &&
           get_u32(m + 0x0cU) == (uint32_t)rcv_name &&
           rcv_name != MACH_PORT_NULL &&
           get_u32(m + 0x14U) == CGS_WINDOW_BACKING_INFO_LEGACY_REQUEST_ID &&
           option == (mach_msg_option_t)CGS_WINDOW_BACKING_INFO_MSG_OPTIONS &&
           send_size == (mach_msg_size_t)CGS_WINDOW_BACKING_INFO_SEND_SIZE &&
           rcv_size == (mach_msg_size_t)CGS_WINDOW_BACKING_INFO_RECV_SIZE &&
           timeout == MACH_MSG_TIMEOUT_NONE &&
           notify == MACH_PORT_NULL &&
           get_u32(m + CGS_WINDOW_BACKING_INFO_WINDOW_ID_OFF) != 0U;
}

static mach_msg_return_t
handle_cgs_window_backing_info_compat(
    mach_msg_header_t *msg,
    mach_msg_option_t option,
    mach_msg_size_t send_size,
    mach_msg_size_t rcv_size,
    mach_port_name_t rcv_name,
    mach_msg_timeout_t timeout,
    mach_port_name_t notify)
{
    const char *mode;
    unsigned char *m = (unsigned char *)msg;
    uint32_t storage[
        CGS_WINDOW_BACKING_INFO_PRIVATE_BUFFER_SIZE / sizeof(uint32_t)];
    unsigned char *adapted = (unsigned char *)storage;
    unsigned char source_before[CGS_WINDOW_BACKING_INFO_SEND_SIZE];
    unsigned char native_reply_before[CGS_WINDOW_BACKING_INFO_SUCCESS_REPLY_SIZE];
    mach_msg_return_t mr;
    uint32_t native_reply_bits;
    uint32_t native_reply_size;
    uint32_t native_reply_id;
    uint32_t native_result_raw = 0U;
    uint32_t native_out0_lo_raw = 0U;
    uint32_t native_out0_hi_raw = 0U;
    uint32_t native_out1_lo_raw = 0U;
    uint32_t native_out1_hi_raw = 0U;
    uint32_t off;
    unsigned int request_changed = 0U;
    unsigned int request_body_changed = 0U;
    unsigned int source_changed = 0U;
    unsigned int reply_changed = 0U;
    unsigned int reply_body_changed = 0U;
    int exact;
    int application_port_exact;
    const char *reply_class = "UNEXPECTED";

    ++gCGSWindowBackingInfoCompatCallCount;
    mode = getenv(CGS_WINDOW_BACKING_INFO_COMPAT_ENV);
    exact = is_exact_legacy_cgs_window_backing_info_request(
        msg, option, send_size, rcv_size, rcv_name, timeout, notify);
    application_port_exact =
        gCGSShowWindowTracePort != MACH_PORT_NULL &&
        get_u32(m + 0x08U) == (uint32_t)gCGSShowWindowTracePort;

    fprintf(stderr, "%s\n", CGS_WINDOW_BACKING_INFO_COMPAT_BUILD_MARKER);
    fprintf(stderr,
            "PM_CGS_WINDOW_BACKING_INFO_COMPAT_CALL:index=%u adapted=%u mode=%s exact=%s applicationPortExact=%s applicationPort=0x%08lx remotePort=0x%08lx replyPort=0x%08lx windowId=%lu newWindowCompatCalls=%u releaseBackingCompatCalls=%u opacityCreateCompatCalls=%u orderFrontCompatCalls=%u addTrackingCompatCalls=%u setFrontWindowCompatCalls=%u colorProfileClientCompatCalls=%u colorProfileResolveCompatCalls=%u\n",
            gCGSWindowBackingInfoCompatCallCount,
            gCGSWindowBackingInfoAdaptedCallCount,
            mode ? mode : "(unset)",
            exact ? "YES" : "NO",
            application_port_exact ? "YES" : "NO",
            (unsigned long)(uint32_t)gCGSShowWindowTracePort,
            (unsigned long)get_u32(m + 0x08U),
            (unsigned long)rcv_name,
            (unsigned long)get_u32(m + CGS_WINDOW_BACKING_INFO_WINDOW_ID_OFF),
            gCGSNewWindowCompatCallCount,
            gCGSReleaseBackingCompatCallCount,
            gCGSOpacityAlphaCreateCompatCallCount,
            gCGSOrderFrontConditionallyCompatCallCount,
            gCGSAddTrackingAreaCompatCallCount,
            gCGSSetFrontWindowCompatCallCount,
            gCGSColorProfileClientCompatCallCount,
            gCGSColorProfileResolveCompatCallCount);
    fflush(stderr);

    if (mode != NULL &&
        strcmp(mode, CGS_WINDOW_BACKING_INFO_COMPAT_PASSTHROUGH) == 0) {
        fprintf(stderr,
                "PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    if (mode == NULL ||
        strcmp(mode, CGS_WINDOW_BACKING_INFO_COMPAT_LION_V1) != 0 ||
        !exact ||
        !application_port_exact ||
        gCGSWindowBackingInfoCompatCallCount != 1U ||
        gCGSWindowBackingInfoAdaptedCallCount >=
            CGS_WINDOW_BACKING_INFO_MAX_ADAPTED_CALLS ||
        gCGSNewWindowCompatCallCount != 1U ||
        gCGSReleaseBackingCompatCallCount != 1U ||
        gCGSOpacityAlphaCreateCompatCallCount != 1U ||
        gCGSOrderFrontConditionallyCompatCallCount != 0U ||
        gCGSAddTrackingAreaCompatCallCount != 0U ||
        gCGSSetFrontWindowCompatCallCount != 0U ||
        gCGSColorProfileClientCompatCallCount != 0U ||
        gCGSColorProfileResolveCompatCallCount != 0U) {
        fprintf(stderr,
                "PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    memset(storage, 0, sizeof(storage));
    memcpy(source_before, m, CGS_WINDOW_BACKING_INFO_SEND_SIZE);
    memcpy(adapted, m, CGS_WINDOW_BACKING_INFO_SEND_SIZE);
    put_u32(adapted + 0x14U, CGS_WINDOW_BACKING_INFO_LION_REQUEST_ID);

    for (off = 0U; off < CGS_WINDOW_BACKING_INFO_SEND_SIZE; ++off) {
        if (adapted[off] != source_before[off]) {
            ++request_changed;
            if (off < 0x14U || off >= 0x18U)
                ++request_body_changed;
        }
        if (m[off] != source_before[off])
            ++source_changed;
    }

    if (request_changed != 1U ||
        request_body_changed != 0U ||
        source_changed != 0U ||
        get_u32(adapted + 0x14U) != CGS_WINDOW_BACKING_INFO_LION_REQUEST_ID) {
        fprintf(stderr,
                "PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:REQUEST_POSTCHECK_FAILED_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    ++gCGSWindowBackingInfoAdaptedCallCount;
    fprintf(stderr,
            "PM_CGS_WINDOW_BACKING_INFO_COMPAT_ADAPTED_REQUEST:index=%u legacyId=0x%08lx lionId=0x%08lx send=0x%08lx recv=0x%08lx changedBytes=%u bodyChangedBytes=%u sourceChangedBytes=%u windowId=%lu\n",
            gCGSWindowBackingInfoAdaptedCallCount,
            (unsigned long)get_u32(source_before + 0x14U),
            (unsigned long)get_u32(adapted + 0x14U),
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            request_changed,
            request_body_changed,
            source_changed,
            (unsigned long)get_u32(
                adapted + CGS_WINDOW_BACKING_INFO_WINDOW_ID_OFF));
    fflush(stderr);

    mr = call_original_mach_msg((mach_msg_header_t *)adapted,
                                option, send_size, rcv_size,
                                rcv_name, timeout, notify);
    fprintf(stderr,
            "PM_CGS_WINDOW_BACKING_INFO_COMPAT_NATIVE_MACH_RETURN:index=%u kr=%ld hex=0x%08lx\n",
            gCGSWindowBackingInfoAdaptedCallCount,
            (long)mr,
            (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    native_reply_bits = get_u32(adapted + 0x00U);
    native_reply_size = get_u32(adapted + 0x04U);
    native_reply_id = get_u32(adapted + 0x14U);
    if (native_reply_size >= CGS_WINDOW_BACKING_INFO_ERROR_REPLY_SIZE)
        native_result_raw =
            get_u32(adapted + CGS_WINDOW_BACKING_INFO_RESULT_OFF);
    if (native_reply_size >= CGS_WINDOW_BACKING_INFO_SUCCESS_REPLY_SIZE) {
        native_out0_lo_raw =
            get_u32(adapted + CGS_WINDOW_BACKING_INFO_OUT0_LO_OFF);
        native_out0_hi_raw =
            get_u32(adapted + CGS_WINDOW_BACKING_INFO_OUT0_HI_OFF);
        native_out1_lo_raw =
            get_u32(adapted + CGS_WINDOW_BACKING_INFO_OUT1_LO_OFF);
        native_out1_hi_raw =
            get_u32(adapted + CGS_WINDOW_BACKING_INFO_OUT1_HI_OFF);
    }

    if (native_reply_size == CGS_WINDOW_BACKING_INFO_SUCCESS_REPLY_SIZE &&
        native_result_raw == 0U)
        reply_class = "SUCCESS";
    else if (native_reply_size == CGS_WINDOW_BACKING_INFO_ERROR_REPLY_SIZE &&
             native_result_raw != 0U)
        reply_class = "ERROR";

    fprintf(stderr,
            "PM_CGS_WINDOW_BACKING_INFO_COMPAT_NATIVE_REPLY:index=%u bits=0x%08lx size=0x%08lx id=0x%08lx resultRaw=0x%08lx out0LoRaw=0x%08lx out0HiRaw=0x%08lx out1LoRaw=0x%08lx out1HiRaw=0x%08lx replyClass=%s\n",
            gCGSWindowBackingInfoAdaptedCallCount,
            (unsigned long)native_reply_bits,
            (unsigned long)native_reply_size,
            (unsigned long)native_reply_id,
            (unsigned long)native_result_raw,
            (unsigned long)native_out0_lo_raw,
            (unsigned long)native_out0_hi_raw,
            (unsigned long)native_out1_lo_raw,
            (unsigned long)native_out1_hi_raw,
            reply_class);
    fflush(stderr);

    if (native_reply_bits != CGS_WINDOW_BACKING_INFO_REPLY_BITS ||
        native_reply_id != CGS_WINDOW_BACKING_INFO_LION_REPLY_ID ||
        strcmp(reply_class, "UNEXPECTED") == 0) {
        if (native_reply_size > 0U &&
            native_reply_size <= CGS_WINDOW_BACKING_INFO_PRIVATE_BUFFER_SIZE)
            memcpy(m, adapted, native_reply_size);
        fprintf(stderr,
                "PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:NATIVE_REPLY_REJECTED\n");
        fflush(stderr);
        return mr;
    }

    memcpy(native_reply_before, adapted, native_reply_size);
    put_u32(adapted + 0x14U, CGS_WINDOW_BACKING_INFO_LEGACY_REPLY_ID);

    for (off = 0U; off < native_reply_size; ++off) {
        if (adapted[off] != native_reply_before[off]) {
            ++reply_changed;
            if (off < 0x14U || off >= 0x18U)
                ++reply_body_changed;
        }
    }

    if (reply_changed != 1U ||
        reply_body_changed != 0U ||
        get_u32(adapted + 0x14U) != CGS_WINDOW_BACKING_INFO_LEGACY_REPLY_ID) {
        memcpy(m, native_reply_before, native_reply_size);
        fprintf(stderr,
                "PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:REPLY_POSTCHECK_FAILED_NATIVE_COPIED\n");
        fflush(stderr);
        return mr;
    }

    memcpy(m, adapted, native_reply_size);
    fprintf(stderr,
            "PM_CGS_WINDOW_BACKING_INFO_COMPAT_ADAPTED_REPLY:index=%u nativeId=0x%08lx legacyId=0x%08lx size=0x%08lx changedBytes=%u bodyChangedBytes=%u resultRaw=0x%08lx out0LoRaw=0x%08lx out0HiRaw=0x%08lx out1LoRaw=0x%08lx out1HiRaw=0x%08lx replyClass=%s\n",
            gCGSWindowBackingInfoAdaptedCallCount,
            (unsigned long)CGS_WINDOW_BACKING_INFO_LION_REPLY_ID,
            (unsigned long)get_u32(m + 0x14U),
            (unsigned long)get_u32(m + 0x04U),
            reply_changed,
            reply_body_changed,
            (unsigned long)native_result_raw,
            (unsigned long)native_out0_lo_raw,
            (unsigned long)native_out0_hi_raw,
            (unsigned long)native_out1_lo_raw,
            (unsigned long)native_out1_hi_raw,
            reply_class);
    fprintf(stderr,
            "PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS\n");
    fflush(stderr);
    return mr;
}
#endif

#if defined(PM_CGS_CONNECTION_TRACE) || defined(PM_CGS_SERVER_VERSION_COMPAT_INTEGRATION)
static const char *
cgs_trace_kind(uint32_t request_id)
{
    if (request_id == CGS_SERVER_VERSION_REQUEST_ID)
        return "SERVER_VERSION";
    if (request_id == CGS_DEATHWATCH_REQUEST_ID)
        return "DEATHWATCH";
    if (request_id == CGS_NEW_CONNECTION_REQUEST_ID)
        return "NEW_CONNECTION";
#ifdef PM_CPS_REGISTRATION_TRACE
    if (request_id == CGS_CHECKIN_APPLICATION_REQUEST_ID)
        return "CPS_CHECKIN_APPLICATION";
    if (request_id == CGS_CREATE_APPLICATION_REQUEST_ID)
        return "CPS_CREATE_APPLICATION";
#endif
#ifdef PM_CPS_SETFRONT_TRACE
    if (request_id == CGS_SET_FRONT_PROCESS_LEGACY_REQUEST_ID)
        return "CPS_SET_FRONT_PROCESS_LEGACY";
    if (request_id == CGS_SET_FRONT_PROCESS_LION_REQUEST_ID)
        return "CPS_SET_FRONT_PROCESS_LION";
#endif
#ifdef PM_CGS_NEWWINDOW_TRACE
    if (request_id == CGS_CREATE_WINDOW_INLINE_LEGACY_REQUEST_ID)
        return "CGS_CREATE_WINDOW_INLINE_LEGACY";
    if (request_id == CGS_CREATE_WINDOW_INLINE_LION_REQUEST_ID)
        return "CGS_CREATE_WINDOW_INLINE_LION";
#endif
#ifdef PM_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE
    if (request_id == CGS_SET_WINDOW_RELEASE_BACKING_LEGACY_REQUEST_ID)
        return "CGS_SET_WINDOW_RELEASE_BACKING_LEGACY";
    if (request_id == CGS_SET_WINDOW_RELEASE_BACKING_LION_REQUEST_ID)
        return "CGS_SET_WINDOW_RELEASE_BACKING_LION";
#endif
#ifdef PM_CGS_POST_RELEASEBACKING_OPACITY_TRACE
    if (request_id == CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY_REQUEST_ID)
        return "CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY";
    if (request_id == CGS_TERMINATE_WINDOW_ALPHA_PLANE_LEGACY_REQUEST_ID)
        return "CGS_TERMINATE_WINDOW_ALPHA_PLANE_LEGACY";
#endif
#ifdef PM_CGS_SHAPEWINDOW_INLINE_COMPAT_INTEGRATION
    if (request_id == CGS_SHAPEWINDOW_INLINE_LEGACY_REQUEST_ID)
        return "CGS_SHAPEWINDOW_INLINE_LEGACY";
    if (request_id == CGS_SHAPEWINDOW_INLINE_LION_REQUEST_ID)
        return "CGS_SHAPEWINDOW_INLINE_LION";
#endif
#ifdef PM_CGS_SYNCHRONIZE_WINDOW_BACKING_STORE_COMPAT_INTEGRATION
    if (request_id == CGS_BACKING_SYNC_LEGACY_REQUEST_ID)
        return "CGS_BACKING_SYNC_LEGACY";
    if (request_id == CGS_BACKING_SYNC_LION_REQUEST_ID)
        return "CGS_BACKING_SYNC_LION";
#endif
#ifdef PM_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_INTEGRATION
    if (request_id == CGS_ADD_TRACKING_AREA_INLINE_LEGACY_REQUEST_ID)
        return "CGS_ADD_TRACKING_AREA_INLINE_LEGACY";
    if (request_id == CGS_ADD_TRACKING_AREA_INLINE_LION_REQUEST_ID)
        return "CGS_ADD_TRACKING_AREA_INLINE_LION";
#endif
#ifdef PM_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_INTEGRATION
    if (request_id == CGS_ORDER_FRONT_CONDITIONALLY_LEGACY_REQUEST_ID)
        return "CGS_ORDER_FRONT_CONDITIONALLY_LEGACY";
    if (request_id == CGS_ORDER_FRONT_CONDITIONALLY_LION_REQUEST_ID)
        return "CGS_ORDER_FRONT_CONDITIONALLY_LION";
#endif
#ifdef PM_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_INTEGRATION
    if (request_id == CGS_SET_FRONT_WINDOW_LEGACY_REQUEST_ID)
        return "CGS_SET_FRONT_WINDOW_LEGACY";
    if (request_id == CGS_SET_FRONT_WINDOW_LION_REQUEST_ID)
        return "CGS_SET_FRONT_WINDOW_LION";
#endif
#ifdef PM_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE
    if (request_id == CGS_COLOR_PROFILE_CLIENT_LEGACY_REQUEST_ID)
        return "CGS_COLOR_PROFILE_CLIENT_LEGACY";
    if (request_id == CGS_COLOR_PROFILE_CLIENT_LION_REQUEST_ID)
        return "CGS_COLOR_PROFILE_CLIENT_LION";
#endif
#ifdef PM_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_TRACE
    if (request_id == CGS_COLOR_PROFILE_RESOLVE_LEGACY_REQUEST_ID)
        return "CGS_COLOR_PROFILE_RESOLVE_LEGACY";
    if (request_id == CGS_COLOR_PROFILE_RESOLVE_LION_REQUEST_ID)
        return "CGS_COLOR_PROFILE_RESOLVE_LION";
#endif
#ifdef PM_CGS_SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_INTEGRATION
    if (request_id == CGS_WINDOW_BACKING_INFO_LEGACY_REQUEST_ID)
        return "CGS_WINDOW_BACKING_INFO_LEGACY";
    if (request_id == CGS_WINDOW_BACKING_INFO_LION_REQUEST_ID)
        return "CGS_WINDOW_BACKING_INFO_LION";
#endif
#ifdef PM_CGS_SHOWWINDOW_UNKNOWN_TRACE
    if (gCGSShowWindowTracePort != MACH_PORT_NULL)
        return "CGS_SHOWWINDOW_UNKNOWN";
#endif
    return "UNKNOWN";
}

static uint32_t
cgs_trace_expected_reply(uint32_t request_id)
{
    if (request_id == CGS_SERVER_VERSION_REQUEST_ID)
        return CGS_SERVER_VERSION_REPLY_ID;
    if (request_id == CGS_DEATHWATCH_REQUEST_ID)
        return CGS_DEATHWATCH_REPLY_ID;
    if (request_id == CGS_NEW_CONNECTION_REQUEST_ID)
        return CGS_NEW_CONNECTION_REPLY_ID;
#ifdef PM_CPS_REGISTRATION_TRACE
    if (request_id == CGS_CHECKIN_APPLICATION_REQUEST_ID)
        return CGS_CHECKIN_APPLICATION_REPLY_ID;
    if (request_id == CGS_CREATE_APPLICATION_REQUEST_ID)
        return CGS_CREATE_APPLICATION_REPLY_ID;
#endif
#ifdef PM_CPS_SETFRONT_TRACE
    if (request_id == CGS_SET_FRONT_PROCESS_LEGACY_REQUEST_ID)
        return CGS_SET_FRONT_PROCESS_LEGACY_REPLY_ID;
    if (request_id == CGS_SET_FRONT_PROCESS_LION_REQUEST_ID)
        return CGS_SET_FRONT_PROCESS_LION_REPLY_ID;
#endif
#ifdef PM_CGS_NEWWINDOW_TRACE
    if (request_id == CGS_CREATE_WINDOW_INLINE_LEGACY_REQUEST_ID)
        return CGS_CREATE_WINDOW_INLINE_LEGACY_REPLY_ID;
    if (request_id == CGS_CREATE_WINDOW_INLINE_LION_REQUEST_ID)
        return CGS_CREATE_WINDOW_INLINE_LION_REPLY_ID;
#endif
#ifdef PM_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE
    if (request_id == CGS_SET_WINDOW_RELEASE_BACKING_LEGACY_REQUEST_ID)
        return CGS_SET_WINDOW_RELEASE_BACKING_LEGACY_REPLY_ID;
    if (request_id == CGS_SET_WINDOW_RELEASE_BACKING_LION_REQUEST_ID)
        return CGS_SET_WINDOW_RELEASE_BACKING_LION_REPLY_ID;
#endif
#ifdef PM_CGS_POST_RELEASEBACKING_OPACITY_TRACE
    if (request_id == CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY_REQUEST_ID)
        return CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY_REPLY_ID;
    if (request_id == CGS_TERMINATE_WINDOW_ALPHA_PLANE_LEGACY_REQUEST_ID)
        return CGS_TERMINATE_WINDOW_ALPHA_PLANE_LEGACY_REPLY_ID;
#endif
#ifdef PM_CGS_SHAPEWINDOW_INLINE_COMPAT_INTEGRATION
    if (request_id == CGS_SHAPEWINDOW_INLINE_LEGACY_REQUEST_ID)
        return CGS_SHAPEWINDOW_INLINE_LEGACY_REPLY_ID;
    if (request_id == CGS_SHAPEWINDOW_INLINE_LION_REQUEST_ID)
        return CGS_SHAPEWINDOW_INLINE_LION_REPLY_ID;
#endif
#ifdef PM_CGS_SYNCHRONIZE_WINDOW_BACKING_STORE_COMPAT_INTEGRATION
    if (request_id == CGS_BACKING_SYNC_LEGACY_REQUEST_ID)
        return CGS_BACKING_SYNC_LEGACY_REPLY_ID;
    if (request_id == CGS_BACKING_SYNC_LION_REQUEST_ID)
        return CGS_BACKING_SYNC_LION_REPLY_ID;
#endif
#ifdef PM_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_INTEGRATION
    if (request_id == CGS_ADD_TRACKING_AREA_INLINE_LEGACY_REQUEST_ID)
        return CGS_ADD_TRACKING_AREA_INLINE_LEGACY_REPLY_ID;
    if (request_id == CGS_ADD_TRACKING_AREA_INLINE_LION_REQUEST_ID)
        return CGS_ADD_TRACKING_AREA_INLINE_LION_REPLY_ID;
#endif
#ifdef PM_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_INTEGRATION
    if (request_id == CGS_ORDER_FRONT_CONDITIONALLY_LEGACY_REQUEST_ID)
        return CGS_ORDER_FRONT_CONDITIONALLY_LEGACY_REPLY_ID;
    if (request_id == CGS_ORDER_FRONT_CONDITIONALLY_LION_REQUEST_ID)
        return CGS_ORDER_FRONT_CONDITIONALLY_LION_REPLY_ID;
#endif
#ifdef PM_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_INTEGRATION
    if (request_id == CGS_SET_FRONT_WINDOW_LEGACY_REQUEST_ID)
        return CGS_SET_FRONT_WINDOW_LEGACY_REPLY_ID;
    if (request_id == CGS_SET_FRONT_WINDOW_LION_REQUEST_ID)
        return CGS_SET_FRONT_WINDOW_LION_REPLY_ID;
#endif
#ifdef PM_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE
    if (request_id == CGS_COLOR_PROFILE_CLIENT_LEGACY_REQUEST_ID)
        return CGS_COLOR_PROFILE_CLIENT_LEGACY_REPLY_ID;
    if (request_id == CGS_COLOR_PROFILE_CLIENT_LION_REQUEST_ID)
        return CGS_COLOR_PROFILE_CLIENT_LION_REPLY_ID;
#endif
#ifdef PM_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_TRACE
    if (request_id == CGS_COLOR_PROFILE_RESOLVE_LEGACY_REQUEST_ID)
        return CGS_COLOR_PROFILE_RESOLVE_LEGACY_REPLY_ID;
    if (request_id == CGS_COLOR_PROFILE_RESOLVE_LION_REQUEST_ID)
        return CGS_COLOR_PROFILE_RESOLVE_LION_REPLY_ID;
#endif
#ifdef PM_CGS_SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_INTEGRATION
    if (request_id == CGS_WINDOW_BACKING_INFO_LEGACY_REQUEST_ID)
        return CGS_WINDOW_BACKING_INFO_LEGACY_REPLY_ID;
    if (request_id == CGS_WINDOW_BACKING_INFO_LION_REQUEST_ID)
        return CGS_WINDOW_BACKING_INFO_LION_REPLY_ID;
#endif
#ifdef PM_CGS_SHOWWINDOW_UNKNOWN_TRACE
    if (gCGSShowWindowTracePort != MACH_PORT_NULL)
        return request_id + 0x64U;
#endif
    return 0U;
}

static int
is_cgs_trace_candidate(mach_msg_header_t *msg)
{
    unsigned char *m = (unsigned char *)msg;
    uint32_t request_id;

    if (msg == NULL)
        return 0;

    request_id = get_u32(m + 0x14);
    if (request_id == CGS_SERVER_VERSION_REQUEST_ID ||
        request_id == CGS_DEATHWATCH_REQUEST_ID ||
        request_id == CGS_NEW_CONNECTION_REQUEST_ID)
        return 1;
#ifdef PM_CPS_REGISTRATION_TRACE
    if (request_id == CGS_CHECKIN_APPLICATION_REQUEST_ID ||
        request_id == CGS_CREATE_APPLICATION_REQUEST_ID)
        return 1;
#endif
#ifdef PM_CPS_SETFRONT_TRACE
    if (request_id == CGS_SET_FRONT_PROCESS_LEGACY_REQUEST_ID ||
        request_id == CGS_SET_FRONT_PROCESS_LION_REQUEST_ID)
        return 1;
#endif
#ifdef PM_CGS_NEWWINDOW_TRACE
    if (request_id == CGS_CREATE_WINDOW_INLINE_LEGACY_REQUEST_ID ||
        request_id == CGS_CREATE_WINDOW_INLINE_LION_REQUEST_ID)
        return 1;
#endif
#ifdef PM_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE
    if (request_id == CGS_SET_WINDOW_RELEASE_BACKING_LEGACY_REQUEST_ID ||
        request_id == CGS_SET_WINDOW_RELEASE_BACKING_LION_REQUEST_ID)
        return 1;
#endif
#ifdef PM_CGS_POST_RELEASEBACKING_OPACITY_TRACE
    if (request_id == CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY_REQUEST_ID ||
        request_id == CGS_TERMINATE_WINDOW_ALPHA_PLANE_LEGACY_REQUEST_ID)
        return 1;
#endif
#ifdef PM_CGS_SHAPEWINDOW_INLINE_COMPAT_INTEGRATION
    if (request_id == CGS_SHAPEWINDOW_INLINE_LEGACY_REQUEST_ID ||
        request_id == CGS_SHAPEWINDOW_INLINE_LION_REQUEST_ID)
        return 1;
#endif
#ifdef PM_CGS_SYNCHRONIZE_WINDOW_BACKING_STORE_COMPAT_INTEGRATION
    if (request_id == CGS_BACKING_SYNC_LEGACY_REQUEST_ID ||
        request_id == CGS_BACKING_SYNC_LION_REQUEST_ID)
        return 1;
#endif
#ifdef PM_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_INTEGRATION
    if (request_id == CGS_ADD_TRACKING_AREA_INLINE_LEGACY_REQUEST_ID ||
        request_id == CGS_ADD_TRACKING_AREA_INLINE_LION_REQUEST_ID)
        return 1;
#endif
#ifdef PM_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_INTEGRATION
    if (request_id == CGS_ORDER_FRONT_CONDITIONALLY_LEGACY_REQUEST_ID ||
        request_id == CGS_ORDER_FRONT_CONDITIONALLY_LION_REQUEST_ID)
        return 1;
#endif
#ifdef PM_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_INTEGRATION
    if (request_id == CGS_SET_FRONT_WINDOW_LEGACY_REQUEST_ID ||
        request_id == CGS_SET_FRONT_WINDOW_LION_REQUEST_ID)
        return 1;
#endif
#ifdef PM_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE
    if (request_id == CGS_COLOR_PROFILE_CLIENT_LEGACY_REQUEST_ID ||
        request_id == CGS_COLOR_PROFILE_CLIENT_LION_REQUEST_ID)
        return 1;
#endif
#ifdef PM_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_TRACE
    if (request_id == CGS_COLOR_PROFILE_RESOLVE_LEGACY_REQUEST_ID ||
        request_id == CGS_COLOR_PROFILE_RESOLVE_LION_REQUEST_ID)
        return 1;
#endif
#ifdef PM_CGS_SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_INTEGRATION
    if (request_id == CGS_WINDOW_BACKING_INFO_LEGACY_REQUEST_ID ||
        request_id == CGS_WINDOW_BACKING_INFO_LION_REQUEST_ID)
        return 1;
#endif
    return 0;
}

#ifdef PM_CGS_SHOWWINDOW_UNKNOWN_TRACE
static int
cgs_showwindow_unknown_trace_mode_enabled(void)
{
    const char *mode = getenv(CGS_SHOWWINDOW_UNKNOWN_TRACE_ENV);

    return mode != NULL &&
           (strcmp(mode, CGS_SHOWWINDOW_UNKNOWN_TRACE_SNOW_V1) == 0 ||
            strcmp(mode, CGS_SHOWWINDOW_UNKNOWN_TRACE_LION_V1) == 0);
}

static int
is_cgs_showwindow_unknown_trace_candidate(mach_msg_header_t *msg,
                                           mach_msg_option_t option,
                                           mach_msg_size_t send_size,
                                           mach_msg_size_t rcv_size,
                                           mach_port_name_t rcv_name,
                                           mach_msg_timeout_t timeout,
                                           mach_port_name_t notify)
{
    unsigned char *m = (unsigned char *)msg;

    if (msg == NULL ||
        !cgs_showwindow_unknown_trace_mode_enabled() ||
        gCGSShowWindowTracePort == MACH_PORT_NULL ||
        gCGSOpacityAlphaCreateCompatCallCount == 0U ||
        gCGSShowWindowUnknownTraceCount >= CGS_SHOWWINDOW_UNKNOWN_TRACE_MAX)
        return 0;

    if ((mach_port_t)get_u32(m + 0x08U) != gCGSShowWindowTracePort ||
        send_size < 0x18U ||
        rcv_size < 0x18U ||
        rcv_name == MACH_PORT_NULL ||
        timeout != MACH_MSG_TIMEOUT_NONE ||
        notify != MACH_PORT_NULL)
        return 0;

    if ((option & MACH_SEND_MSG) == 0 || (option & MACH_RCV_MSG) == 0)
        return 0;

    return !is_cgs_trace_candidate(msg);
}

static void
emit_cgs_showwindow_unknown_hex(const char *marker,
                                unsigned int index,
                                const unsigned char *bytes,
                                uint32_t length)
{
    uint32_t emitted = length;
    uint32_t off;

    if (emitted > CGS_SHOWWINDOW_UNKNOWN_TRACE_HEX_MAX)
        emitted = CGS_SHOWWINDOW_UNKNOWN_TRACE_HEX_MAX;

    fprintf(stderr,
            "%sindex=%u length=0x%08lx emitted=0x%08lx truncated=%s data=",
            marker,
            index,
            (unsigned long)length,
            (unsigned long)emitted,
            emitted < length ? "YES" : "NO");
    for (off = 0U; off < emitted; ++off)
        fprintf(stderr, "%02x", (unsigned int)bytes[off]);
    fprintf(stderr, "\n");
    fflush(stderr);
}
#endif

static mach_msg_return_t
trace_cgs_message(mach_msg_header_t *msg,
                  mach_msg_option_t option,
                  mach_msg_size_t send_size,
                  mach_msg_size_t rcv_size,
                  mach_port_name_t rcv_name,
                  mach_msg_timeout_t timeout,
                  mach_port_name_t notify)
{
    unsigned char *m = (unsigned char *)msg;
    mach_msg_return_t mr;
    uint32_t request_id;
    uint32_t expected_reply;
    uint32_t reply_bits;
    uint32_t reply_size;
    uint32_t reply_id;
    uint32_t limit;
    uint32_t off;
#ifdef PM_CGS_SERVER_VERSION_COMPAT_INTEGRATION
    int server_version_request_exact = 0;
#endif
#ifdef PM_CGS_SHOWWINDOW_UNKNOWN_TRACE
    int showwindow_unknown_request = 0;
#endif

    request_id = get_u32(m + 0x14);
#ifdef PM_CGS_SHOWWINDOW_UNKNOWN_TRACE
    if (request_id == CGS_CREATE_WINDOW_INLINE_LEGACY_REQUEST_ID &&
        get_u32(m + 0x08U) != 0U)
        gCGSShowWindowTracePort =
            (mach_port_t)get_u32(m + 0x08U);
#endif
    expected_reply = cgs_trace_expected_reply(request_id);
#ifdef PM_CGS_SHOWWINDOW_UNKNOWN_TRACE
    showwindow_unknown_request = !is_cgs_trace_candidate(msg);
#endif
#ifdef PM_CGS_SERVER_VERSION_COMPAT_INTEGRATION
    if (request_id == CGS_SERVER_VERSION_REQUEST_ID) {
        server_version_request_exact =
            get_u32(m + 0x00) == 0x00001513U &&
            get_u32(m + 0x08) != 0U &&
            get_u32(m + 0x0c) == (uint32_t)rcv_name &&
            option == (mach_msg_option_t)0x00000003U &&
            send_size == (mach_msg_size_t)0x00000024U &&
            rcv_size == (mach_msg_size_t)0x00000048U &&
            rcv_name != MACH_PORT_NULL &&
            timeout == MACH_MSG_TIMEOUT_NONE &&
            notify == MACH_PORT_NULL;
    }
#endif
#ifdef PM_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE
    if (request_id == CGS_COLOR_PROFILE_CLIENT_LEGACY_REQUEST_ID ||
        request_id == CGS_COLOR_PROFILE_CLIENT_LION_REQUEST_ID) {
        int exact =
            get_u32(m + 0x00U) == CGS_COLOR_PROFILE_CLIENT_BITS &&
            get_u32(m + 0x08U) != 0U &&
            get_u32(m + 0x0cU) == (uint32_t)rcv_name &&
            option == (mach_msg_option_t)CGS_COLOR_PROFILE_CLIENT_MSG_OPTIONS &&
            send_size == (mach_msg_size_t)CGS_COLOR_PROFILE_CLIENT_SEND_SIZE &&
            rcv_size == (mach_msg_size_t)CGS_COLOR_PROFILE_CLIENT_RECV_SIZE &&
            rcv_name != MACH_PORT_NULL &&
            timeout == MACH_MSG_TIMEOUT_NONE &&
            notify == MACH_PORT_NULL &&
            get_u32(m + CGS_COLOR_PROFILE_CLIENT_DESC_COUNT_OFF) == 1U &&
            get_u32(m + CGS_COLOR_PROFILE_CLIENT_DESC_PORT_OFF) != 0U &&
            m[CGS_COLOR_PROFILE_CLIENT_DESC_DISPOSITION_OFF] == 0x13U &&
            m[CGS_COLOR_PROFILE_CLIENT_DESC_TYPE_OFF] == 0x00U &&
            get_u32(m + CGS_COLOR_PROFILE_CLIENT_PID_OFF) != 0U;
        fprintf(stderr,
                "PM_CGS_COLOR_PROFILE_CLIENT_TRACE_REQUEST:kind=%s exact=%s bits=0x%08lx id=0x%08lx send=0x%08lx recv=0x%08lx remotePort=0x%08lx replyPort=0x%08lx descriptorCount=%lu descriptorPort=0x%08lx disposition=0x%02x type=0x%02x pid=%lu\n",
                cgs_trace_kind(request_id),
                exact ? "YES" : "NO",
                (unsigned long)get_u32(m + 0x00U),
                (unsigned long)request_id,
                (unsigned long)send_size,
                (unsigned long)rcv_size,
                (unsigned long)get_u32(m + 0x08U),
                (unsigned long)rcv_name,
                (unsigned long)get_u32(m + CGS_COLOR_PROFILE_CLIENT_DESC_COUNT_OFF),
                (unsigned long)get_u32(m + CGS_COLOR_PROFILE_CLIENT_DESC_PORT_OFF),
                (unsigned int)m[CGS_COLOR_PROFILE_CLIENT_DESC_DISPOSITION_OFF],
                (unsigned int)m[CGS_COLOR_PROFILE_CLIENT_DESC_TYPE_OFF],
                (unsigned long)get_u32(m + CGS_COLOR_PROFILE_CLIENT_PID_OFF));
        fflush(stderr);
    }
#endif
#ifdef PM_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_TRACE
    if (request_id == CGS_COLOR_PROFILE_RESOLVE_LEGACY_REQUEST_ID ||
        request_id == CGS_COLOR_PROFILE_RESOLVE_LION_REQUEST_ID) {
        int exact =
            get_u32(m + 0x00U) == CGS_COLOR_PROFILE_RESOLVE_BITS &&
            get_u32(m + 0x08U) != 0U &&
            get_u32(m + 0x0cU) == (uint32_t)rcv_name &&
            option == (mach_msg_option_t)CGS_COLOR_PROFILE_RESOLVE_MSG_OPTIONS &&
            send_size == (mach_msg_size_t)CGS_COLOR_PROFILE_RESOLVE_SEND_SIZE &&
            rcv_size == (mach_msg_size_t)CGS_COLOR_PROFILE_RESOLVE_RECV_SIZE &&
            rcv_name != MACH_PORT_NULL &&
            timeout == MACH_MSG_TIMEOUT_NONE &&
            notify == MACH_PORT_NULL &&
            get_u32(m + CGS_COLOR_PROFILE_RESOLVE_DESC_COUNT_OFF) == 1U &&
            get_u32(m + CGS_COLOR_PROFILE_RESOLVE_DESC_PORT_OFF) != 0U &&
            m[CGS_COLOR_PROFILE_RESOLVE_DESC_DISPOSITION_OFF] == 0x13U &&
            m[CGS_COLOR_PROFILE_RESOLVE_DESC_TYPE_OFF] == 0x00U &&
            get_u32(m + CGS_COLOR_PROFILE_RESOLVE_CLIENT_ID_OFF) != 0U &&
            get_u32(m + CGS_COLOR_PROFILE_RESOLVE_PROFILE_ID_OFF) == 1U;
        fprintf(stderr, "%s\n", CGS_COLOR_PROFILE_RESOLVE_TRACE_BUILD_MARKER);
        fprintf(stderr,
                "PM_CGS_COLOR_PROFILE_RESOLVE_TRACE_REQUEST:kind=%s exact=%s bits=0x%08lx id=0x%08lx send=0x%08lx recv=0x%08lx remotePort=0x%08lx replyPort=0x%08lx descriptorCount=%lu descriptorPort=0x%08lx disposition=0x%02x type=0x%02x clientId=%lu profileId=%lu\n",
                cgs_trace_kind(request_id),
                exact ? "YES" : "NO",
                (unsigned long)get_u32(m + 0x00U),
                (unsigned long)request_id,
                (unsigned long)send_size,
                (unsigned long)rcv_size,
                (unsigned long)get_u32(m + 0x08U),
                (unsigned long)rcv_name,
                (unsigned long)get_u32(m + CGS_COLOR_PROFILE_RESOLVE_DESC_COUNT_OFF),
                (unsigned long)get_u32(m + CGS_COLOR_PROFILE_RESOLVE_DESC_PORT_OFF),
                (unsigned int)m[CGS_COLOR_PROFILE_RESOLVE_DESC_DISPOSITION_OFF],
                (unsigned int)m[CGS_COLOR_PROFILE_RESOLVE_DESC_TYPE_OFF],
                (unsigned long)get_u32(m + CGS_COLOR_PROFILE_RESOLVE_CLIENT_ID_OFF),
                (unsigned long)get_u32(m + CGS_COLOR_PROFILE_RESOLVE_PROFILE_ID_OFF));
        fflush(stderr);
    }
#endif
    ++gCGSTraceCallCount;

#ifdef PM_CGS_SHOWWINDOW_UNKNOWN_TRACE
    if (showwindow_unknown_request) {
        const char *showwindow_mode =
            getenv(CGS_SHOWWINDOW_UNKNOWN_TRACE_ENV);
        ++gCGSShowWindowUnknownTraceCount;
        fprintf(stderr,
                "PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_REQUEST:index=%u mode=%s traceIndex=%u bits=0x%08lx id=0x%08lx expectedReply=0x%08lx option=0x%08lx send=0x%08lx recv=0x%08lx remotePort=0x%08lx replyPort=0x%08lx\n",
                gCGSShowWindowUnknownTraceCount,
                showwindow_mode ? showwindow_mode : "(unset)",
                gCGSTraceCallCount,
                (unsigned long)get_u32(m + 0x00U),
                (unsigned long)request_id,
                (unsigned long)expected_reply,
                (unsigned long)(uint32_t)option,
                (unsigned long)send_size,
                (unsigned long)rcv_size,
                (unsigned long)get_u32(m + 0x08U),
                (unsigned long)rcv_name);
        emit_cgs_showwindow_unknown_hex(
            "PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_REQUEST_HEX:",
            gCGSShowWindowUnknownTraceCount,
            m,
            (uint32_t)send_size);
    }
#endif

    fprintf(stderr, "%s\n", COMPAT_BUILD_MARKER);
    fprintf(stderr,
            "PM_CGS_CONNECTION_TRACE_REQUEST:index=%u kind=%s bits=0x%08lx headerSizeObserved=0x%08lx id=0x%08lx expectedReply=0x%08lx option=0x%08lx send=0x%08lx recv=0x%08lx remotePort=0x%08lx headerReplyPort=0x%08lx receivePort=0x%08lx timeout=0x%08lx notify=0x%08lx\n",
            gCGSTraceCallCount,
            cgs_trace_kind(request_id),
            (unsigned long)get_u32(m + 0x00),
            (unsigned long)get_u32(m + 0x04),
            (unsigned long)request_id,
            (unsigned long)expected_reply,
            (unsigned long)(uint32_t)option,
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            (unsigned long)get_u32(m + 0x08),
            (unsigned long)get_u32(m + 0x0c),
            (unsigned long)rcv_name,
            (unsigned long)timeout,
            (unsigned long)notify);
    fflush(stderr);

    limit = (uint32_t)send_size;
#ifdef PM_CPS_REGISTRATION_TRACE
    if ((request_id == CGS_CHECKIN_APPLICATION_REQUEST_ID ||
         request_id == CGS_CREATE_APPLICATION_REQUEST_ID) &&
        limit > 0x80U)
        limit = 0x80U;
    else
#endif
    if (limit > 0x44U)
        limit = 0x44U;

    fprintf(stderr,
            "PM_CGS_CONNECTION_TRACE_REQUEST_WORDS:index=%u kind=%s",
            gCGSTraceCallCount,
            cgs_trace_kind(request_id));
    for (off = 0x18U; off + 4U <= limit; off += 4U) {
        fprintf(stderr,
                " off%02lx=0x%08lx",
                (unsigned long)off,
                (unsigned long)get_u32(m + off));
    }
    fprintf(stderr, "\n");
    fflush(stderr);

#ifdef PM_CPS_REGISTRATION_COMPAT_INTEGRATION
    if (request_id == CGS_CHECKIN_APPLICATION_REQUEST_ID) {
        mr = handle_cps_registration_compat(msg, option, send_size,
                                            rcv_size, rcv_name,
                                            timeout, notify);
    } else
#endif
#ifdef PM_CPS_SETFRONT_COMPAT_PROTOCOL
    if (request_id == CGS_SET_FRONT_PROCESS_LEGACY_REQUEST_ID) {
        mr = handle_cps_setfront_compat(msg, option, send_size,
                                        rcv_size, rcv_name,
                                        timeout, notify);
    } else
#endif
#ifdef PM_CGS_NEWWINDOW_COMPAT_INTEGRATION
    if (request_id == CGS_CREATE_WINDOW_INLINE_LEGACY_REQUEST_ID) {
        mr = handle_cgs_newwindow_compat(msg, option, send_size,
                                         rcv_size, rcv_name,
                                         timeout, notify);
    } else
#endif
#ifdef PM_CGS_RELEASEBACKING_COMPAT_INTEGRATION
    if (request_id == CGS_SET_WINDOW_RELEASE_BACKING_LEGACY_REQUEST_ID) {
        mr = handle_cgs_releasebacking_compat(msg, option, send_size,
                                              rcv_size, rcv_name,
                                              timeout, notify);
    } else
#endif
#ifdef PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_INTEGRATION
    if (request_id == CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY_REQUEST_ID) {
        mr = handle_cgs_opacity_alpha_create_compat(
            msg, option, send_size, rcv_size, rcv_name,
            timeout, notify);
    } else
#endif
#ifdef PM_CGS_SHAPEWINDOW_INLINE_COMPAT_INTEGRATION
    if (request_id == CGS_SHAPEWINDOW_INLINE_LEGACY_REQUEST_ID) {
        mr = handle_cgs_shapewindow_inline_compat(
            msg, option, send_size, rcv_size, rcv_name,
            timeout, notify);
    } else
#endif
#ifdef PM_CGS_SYNCHRONIZE_WINDOW_BACKING_STORE_COMPAT_INTEGRATION
    if (request_id == CGS_BACKING_SYNC_LEGACY_REQUEST_ID) {
        mr = handle_cgs_backing_sync_compat(
            msg, option, send_size, rcv_size, rcv_name,
            timeout, notify);
    } else
#endif
#ifdef PM_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_INTEGRATION
    if (request_id == CGS_ORDER_FRONT_CONDITIONALLY_LEGACY_REQUEST_ID) {
        mr = handle_cgs_order_front_conditionally_compat(
            msg, option, send_size, rcv_size, rcv_name,
            timeout, notify);
    } else
#endif
#ifdef PM_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_INTEGRATION
    if (request_id == CGS_SET_FRONT_WINDOW_LEGACY_REQUEST_ID &&
        send_size >= (mach_msg_size_t)CGS_SET_FRONT_WINDOW_SEND_SIZE &&
        get_u32(m + CGS_SET_FRONT_WINDOW_WINDOW_ID_OFF) != 0U) {
        mr = handle_cgs_set_front_window_compat(
            msg, option, send_size, rcv_size, rcv_name,
            timeout, notify);
    } else
#endif
#ifdef PM_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_INTEGRATION
    if (request_id == CGS_ADD_TRACKING_AREA_INLINE_LEGACY_REQUEST_ID) {
        mr = handle_cgs_add_tracking_area_compat(
            msg, option, send_size, rcv_size, rcv_name,
            timeout, notify);
    } else
#endif
#ifdef PM_CGS_SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_INTEGRATION
    if (request_id == CGS_WINDOW_BACKING_INFO_LEGACY_REQUEST_ID) {
        mr = handle_cgs_window_backing_info_compat(
            msg, option, send_size, rcv_size, rcv_name,
            timeout, notify);
    } else
#endif
#ifdef PM_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_INTEGRATION
    if (request_id == CGS_COLOR_PROFILE_RESOLVE_LEGACY_REQUEST_ID) {
        mr = handle_cgs_color_profile_resolve_compat(
            msg, option, send_size, rcv_size, rcv_name,
            timeout, notify);
    } else
#endif
#ifdef PM_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_INTEGRATION
    if (request_id == CGS_COLOR_PROFILE_CLIENT_LEGACY_REQUEST_ID) {
        mr = handle_cgs_color_profile_client_compat(
            msg, option, send_size, rcv_size, rcv_name,
            timeout, notify);
    } else
#endif
    {
        mr = call_original_mach_msg(msg, option, send_size,
                                    rcv_size, rcv_name,
                                    timeout, notify);
    }

    fprintf(stderr,
            "PM_CGS_CONNECTION_TRACE_MACH_RETURN:index=%u kind=%s kr=%ld hex=0x%08lx\n",
            gCGSTraceCallCount,
            cgs_trace_kind(request_id),
            (long)mr,
            (unsigned long)(uint32_t)mr);
    fflush(stderr);

#ifdef PM_CGS_SHOWWINDOW_UNKNOWN_TRACE
    if (showwindow_unknown_request) {
        fprintf(stderr,
                "PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_MACH_RETURN:index=%u id=0x%08lx kr=%ld hex=0x%08lx\n",
                gCGSShowWindowUnknownTraceCount,
                (unsigned long)request_id,
                (long)mr,
                (unsigned long)(uint32_t)mr);
        fflush(stderr);
        if (mr != MACH_MSG_SUCCESS)
            emit_cgs_showwindow_unknown_hex(
                "PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_FAILURE_BUFFER_HEX:",
                gCGSShowWindowUnknownTraceCount,
                m,
                (uint32_t)rcv_size);
    }
#endif

#ifdef PM_CGS_POST_RELEASEBACKING_OPACITY_TRACE
    if (mr != MACH_MSG_SUCCESS &&
        (request_id == CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY_REQUEST_ID ||
         request_id == CGS_TERMINATE_WINDOW_ALPHA_PLANE_LEGACY_REQUEST_ID)) {
        fprintf(stderr,
                "PM_CGS_OPACITY_ALPHA_TRACE_FAILURE_BUFFER:index=%u kind=%s kr=%ld hex=0x%08lx postBits=0x%08lx postSize=0x%08lx postId=0x%08lx off18=0x%08lx off1c=0x%08lx off20=0x%08lx\n",
                gCGSTraceCallCount,
                cgs_trace_kind(request_id),
                (long)mr,
                (unsigned long)(uint32_t)mr,
                (unsigned long)get_u32(m + 0x00),
                (unsigned long)get_u32(m + 0x04),
                (unsigned long)get_u32(m + 0x14),
                (unsigned long)get_u32(m + 0x18),
                (unsigned long)get_u32(m + 0x1c),
                (unsigned long)get_u32(m + 0x20));
        fflush(stderr);
    }
#endif

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    reply_bits = get_u32(m + 0x00);
    reply_size = get_u32(m + 0x04);
    reply_id = get_u32(m + 0x14);

    fprintf(stderr,
            "PM_CGS_CONNECTION_TRACE_REPLY:index=%u kind=%s bits=0x%08lx size=0x%08lx id=0x%08lx expected=0x%08lx idMatch=%s\n",
            gCGSTraceCallCount,
            cgs_trace_kind(request_id),
            (unsigned long)reply_bits,
            (unsigned long)reply_size,
            (unsigned long)reply_id,
            (unsigned long)expected_reply,
            reply_id == expected_reply ? "YES" : "NO");
    fflush(stderr);

#ifdef PM_CGS_SHOWWINDOW_UNKNOWN_TRACE
    if (showwindow_unknown_request)
        emit_cgs_showwindow_unknown_hex(
            "PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_REPLY_HEX:",
            gCGSShowWindowUnknownTraceCount,
            m,
            reply_size <= (uint32_t)rcv_size ?
                reply_size : (uint32_t)rcv_size);
#endif

    limit = reply_size;
    if (limit > (uint32_t)rcv_size)
        limit = (uint32_t)rcv_size;
    if (limit > 0x44U)
        limit = 0x44U;

    fprintf(stderr,
            "PM_CGS_CONNECTION_TRACE_REPLY_WORDS:index=%u kind=%s",
            gCGSTraceCallCount,
            cgs_trace_kind(request_id));
    for (off = 0x18U; off + 4U <= limit; off += 4U) {
        fprintf(stderr,
                " off%02lx=0x%08lx",
                (unsigned long)off,
                (unsigned long)get_u32(m + off));
    }
    fprintf(stderr, "\n");
    fflush(stderr);

#ifdef PM_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE
    if (request_id == CGS_COLOR_PROFILE_CLIENT_LEGACY_REQUEST_ID ||
        request_id == CGS_COLOR_PROFILE_CLIENT_LION_REQUEST_ID) {
        fprintf(stderr,
                "PM_CGS_COLOR_PROFILE_CLIENT_TRACE_REPLY:kind=%s bits=0x%08lx size=0x%08lx id=0x%08lx expected=0x%08lx resultRaw=0x%08lx clientIdRaw=0x%08lx\n",
                cgs_trace_kind(request_id),
                (unsigned long)reply_bits,
                (unsigned long)reply_size,
                (unsigned long)reply_id,
                (unsigned long)expected_reply,
                (unsigned long)(reply_size >= 0x24U ?
                    get_u32(m + CGS_COLOR_PROFILE_CLIENT_RESULT_OFF) : 0U),
                (unsigned long)(reply_size >= 0x28U ?
                    get_u32(m + CGS_COLOR_PROFILE_CLIENT_ID_OFF) : 0U));
        fflush(stderr);
    }
#endif
#ifdef PM_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_TRACE
    if (request_id == CGS_COLOR_PROFILE_RESOLVE_LEGACY_REQUEST_ID ||
        request_id == CGS_COLOR_PROFILE_RESOLVE_LION_REQUEST_ID) {
        fprintf(stderr,
                "PM_CGS_COLOR_PROFILE_RESOLVE_TRACE_REPLY:kind=%s bits=0x%08lx size=0x%08lx id=0x%08lx expected=0x%08lx resultRaw=0x%08lx out0LoRaw=0x%08lx out0HiRaw=0x%08lx out1LoRaw=0x%08lx out1HiRaw=0x%08lx\n",
                cgs_trace_kind(request_id),
                (unsigned long)reply_bits,
                (unsigned long)reply_size,
                (unsigned long)reply_id,
                (unsigned long)expected_reply,
                (unsigned long)(reply_size >= 0x24U ?
                    get_u32(m + CGS_COLOR_PROFILE_RESOLVE_RESULT_OFF) : 0U),
                (unsigned long)(reply_size >= CGS_COLOR_PROFILE_RESOLVE_SUCCESS_REPLY_SIZE ?
                    get_u32(m + CGS_COLOR_PROFILE_RESOLVE_OUT0_LO_OFF) : 0U),
                (unsigned long)(reply_size >= CGS_COLOR_PROFILE_RESOLVE_SUCCESS_REPLY_SIZE ?
                    get_u32(m + CGS_COLOR_PROFILE_RESOLVE_OUT0_HI_OFF) : 0U),
                (unsigned long)(reply_size >= CGS_COLOR_PROFILE_RESOLVE_SUCCESS_REPLY_SIZE ?
                    get_u32(m + CGS_COLOR_PROFILE_RESOLVE_OUT1_LO_OFF) : 0U),
                (unsigned long)(reply_size >= CGS_COLOR_PROFILE_RESOLVE_SUCCESS_REPLY_SIZE ?
                    get_u32(m + CGS_COLOR_PROFILE_RESOLVE_OUT1_HI_OFF) : 0U));
        fflush(stderr);
    }
#endif

#ifdef PM_CGS_SERVER_VERSION_COMPAT_INTEGRATION
    maybe_normalize_cgs_server_version_reply(m,
                                             request_id,
                                             server_version_request_exact,
                                             rcv_size,
                                             mr,
                                             reply_bits,
                                             reply_size,
                                             reply_id);
#endif

    return mr;
}
#endif

static kern_return_t
call_original_lookup(mach_port_t bp,
                     const char *service_name,
                     mach_port_t *service_port,
                     pid_t target_pid,
                     uint64_t flags,
                     const char *reason)
{
    bootstrap_lookup2_fn fn = original_lookup();
    kern_return_t kr;

    if (fn == NULL ||
        fn == (bootstrap_lookup2_fn)&rosetta_bootstrap_look_up2) {
        if (service_port != NULL)
            *service_port = MACH_PORT_NULL;
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_BOOTSTRAP_ORIGINAL_UNAVAILABLE:reason=%s\n",
                reason);
        fflush(stderr);
        return MIG_BAD_ID;
    }

    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_BOOTSTRAP_PASSTHROUGH:reason=%s name=%s pid=%ld flags=0x%08lx%08lx\n",
            reason,
            service_name ? service_name : "(null)",
            (long)target_pid,
            (unsigned long)(uint32_t)(flags >> 32),
            (unsigned long)(uint32_t)flags);
    fflush(stderr);

    kr = fn(bp, service_name, service_port, target_pid, flags);

    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_BOOTSTRAP_PASSTHROUGH_RETURN:kr=%ld hex=0x%08lx servicePort=0x%08lx\n",
            (long)kr,
            (unsigned long)(uint32_t)kr,
            (unsigned long)((service_port != NULL) ?
                            *service_port : MACH_PORT_NULL));
    fflush(stderr);

    return kr;
}

static int
build_lion_lookup_request(unsigned char *buffer,
                          mach_port_t remote_port,
                          mach_port_t reply_port,
                          const char *service_name,
                          pid_t target_pid,
                          uint64_t flags)
{
    uint32_t bits;

    if (buffer == NULL || service_name == NULL)
        return 0;

    memset(buffer, 0, LOOKUP_SEND_SIZE);

    bits = (uint32_t)MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND,
                                    MACH_MSG_TYPE_MAKE_SEND_ONCE);

    put_u32(buffer + 0x00, bits);
    put_u32(buffer + 0x04, LOOKUP_SEND_SIZE);
    put_u32(buffer + 0x08, (uint32_t)remote_port);
    put_u32(buffer + 0x0c, (uint32_t)reply_port);
    put_u32(buffer + 0x10, 0U);
    put_u32(buffer + 0x14, LOOKUP_REQUEST_ID);
    memcpy(buffer + 0x18, &NDR_record, sizeof(NDR_record));

    strncpy((char *)(buffer + LOOKUP_SERVICE_OFF),
            service_name, 0x7f);
    ((char *)(buffer + LOOKUP_SERVICE_OFF))[0x7f] = '\0';

    memcpy(buffer + LOOKUP_PID_OFF, &target_pid, sizeof(target_pid));
    memset(buffer + LOOKUP_UUID_OFF, 0, 16);
    put_u64(buffer + LOOKUP_FLAGS_OFF, flags);

    return get_u32(buffer + 0x00) == 0x00001513U &&
           get_u32(buffer + 0x04) == LOOKUP_SEND_SIZE &&
           get_u32(buffer + 0x14) == LOOKUP_REQUEST_ID;
}

static int
extract_server_euid(unsigned char *message,
                    uint32_t reply_size,
                    uid_t *server_euid)
{
    uintptr_t trailer_addr;
    mach_msg_audit_trailer_t *trailer;

    if (message == NULL || server_euid == NULL)
        return 0;

    trailer_addr = (uintptr_t)(message + ((reply_size + 3U) & ~3U));
    trailer = (mach_msg_audit_trailer_t *)trailer_addr;

    if (trailer->msgh_trailer_type != MACH_MSG_TRAILER_FORMAT_0)
        return 0;
    if (trailer->msgh_trailer_size < sizeof(mach_msg_audit_trailer_t))
        return 0;

    *server_euid = (uid_t)trailer->msgh_audit.val[1];
    return 1;
}

static kern_return_t
lion_format_lookup(mach_port_t bp,
                   const char *service_name,
                   mach_port_t *service_port,
                   pid_t target_pid,
                   uint64_t flags)
{
    uint32_t storage[LOOKUP_SEND_SIZE / sizeof(uint32_t)];
    unsigned char *message = (unsigned char *)storage;
    mach_port_t reply_port;
    mach_port_t returned_port;
    mach_msg_return_t mr;
    uint32_t reply_bits;
    uint32_t reply_size;
    uint32_t reply_id;
    uint32_t descriptor_count;
    int32_t retcode;
    uid_t server_euid = (uid_t)-1;

    if (service_port == NULL)
        return MIG_BAD_ARGUMENTS;

    *service_port = MACH_PORT_NULL;

    reply_port = mig_get_reply_port();
    if (reply_port == MACH_PORT_NULL)
        return MIG_NO_REPLY;

    if (!build_lion_lookup_request(message, bp, reply_port,
                                   service_name, target_pid, flags))
        return MIG_BAD_ARGUMENTS;

    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_BOOTSTRAP_ADAPTER_REQUEST:bp=0x%08lx reply=0x%08lx id=0x%08lx send=0x%08lx recv=0x%08lx pid=%ld uuid=ZERO flags=0x%08lx%08lx\n",
            (unsigned long)bp,
            (unsigned long)reply_port,
            (unsigned long)LOOKUP_REQUEST_ID,
            (unsigned long)LOOKUP_SEND_SIZE,
            (unsigned long)LOOKUP_RECV_SIZE,
            (long)target_pid,
            (unsigned long)(uint32_t)(flags >> 32),
            (unsigned long)(uint32_t)flags);
    fflush(stderr);

    mr = call_original_mach_msg((mach_msg_header_t *)message,
                                (mach_msg_option_t)LOOKUP_MSG_OPTIONS,
                                (mach_msg_size_t)LOOKUP_SEND_SIZE,
                                (mach_msg_size_t)LOOKUP_RECV_SIZE,
                                reply_port,
                                MACH_MSG_TIMEOUT_NONE,
                                MACH_PORT_NULL);

    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_BOOTSTRAP_ADAPTER_MACH_MSG:kr=%ld hex=0x%08lx\n",
            (long)mr, (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    reply_bits = get_u32(message + 0x00);
    reply_size = get_u32(message + 0x04);
    reply_id = get_u32(message + 0x14);

    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_BOOTSTRAP_ADAPTER_REPLY:bits=0x%08lx size=0x%08lx id=0x%08lx\n",
            (unsigned long)reply_bits,
            (unsigned long)reply_size,
            (unsigned long)reply_id);
    fflush(stderr);

    if (reply_id != LOOKUP_REPLY_ID)
        return MIG_REPLY_MISMATCH;

    if ((reply_bits & MACH_MSGH_BITS_COMPLEX) == 0) {
        if (reply_size != LOOKUP_ERROR_SIZE)
            return MIG_TYPE_ERROR;

        retcode =
            (int32_t)get_u32(message + LOOKUP_REPLY_RETCODE_OFF);
        return (kern_return_t)retcode;
    }

    descriptor_count =
        get_u32(message + LOOKUP_REPLY_DESC_COUNT_OFF);
    returned_port =
        (mach_port_t)get_u32(message + LOOKUP_REPLY_PORT_OFF);

    if (reply_size != LOOKUP_SUCCESS_SIZE ||
        descriptor_count != 1U ||
        returned_port == MACH_PORT_NULL) {
        if (returned_port != MACH_PORT_NULL)
            (void)mach_port_deallocate(mach_task_self(), returned_port);
        return MIG_TYPE_ERROR;
    }

    if (!extract_server_euid(message, reply_size, &server_euid)) {
        (void)mach_port_deallocate(mach_task_self(), returned_port);
        return MIG_TYPE_ERROR;
    }

    if ((flags & PRIVILEGED_SERVER_FLAG) != 0 &&
        server_euid != 0) {
        (void)mach_port_deallocate(mach_task_self(), returned_port);
        return BOOTSTRAP_NOT_PRIVILEGED;
    }

    *service_port = returned_port;
    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_BOOTSTRAP_ADAPTER_RESULT:LOOKUP_PASS servicePort=0x%08lx serverEuid=%lu\n",
            (unsigned long)returned_port,
            (unsigned long)server_euid);
    fflush(stderr);
    return KERN_SUCCESS;
}

static int
is_servercheckin_candidate(mach_msg_header_t *msg)
{
    unsigned char *m = (unsigned char *)msg;

    if (msg == NULL || gCoreServicesServerPort == MACH_PORT_NULL)
        return 0;

    return get_u32(m + 0x08) == (uint32_t)gCoreServicesServerPort &&
           get_u32(m + 0x14) == CHECKIN_REQUEST_ID;
}

static int
is_exact_legacy_servercheckin(mach_msg_header_t *msg,
                              mach_msg_option_t option,
                              mach_msg_size_t send_size,
                              mach_msg_size_t rcv_size,
                              mach_port_name_t rcv_name,
                              mach_msg_timeout_t timeout,
                              mach_port_name_t notify)
{
    unsigned char *m = (unsigned char *)msg;

    if (!is_servercheckin_candidate(msg))
        return 0;

    if ((uint32_t)option != 0x00000003U ||
        send_size != CHECKIN_LEGACY_SEND_SIZE ||
        rcv_size != CHECKIN_RECV_SIZE ||
        timeout != MACH_MSG_TIMEOUT_NONE ||
        notify != MACH_PORT_NULL)
        return 0;

    if (get_u32(m + 0x00) != CHECKIN_LEGACY_BITS ||
        get_u32(m + 0x0c) != (uint32_t)rcv_name ||
        get_u32(m + 0x18) != 1U)
        return 0;

    if (get_u32(m + 0x1c) == (uint32_t)MACH_PORT_NULL ||
        m[0x26] != 0x13 ||
        m[0x27] != 0x00)
        return 0;

    return 1;
}


static void
record_servercheckin_session_port(unsigned char *m,
                                  mach_msg_return_t mr,
                                  const char *source)
{
    if (m == NULL || mr != MACH_MSG_SUCCESS)
        return;

    if (get_u32(m + 0x14) == CHECKIN_REPLY_ID &&
        get_u32(m + 0x04) == CHECKIN_SUCCESS_SIZE &&
        (get_u32(m + 0x00) & MACH_MSGH_BITS_COMPLEX) != 0 &&
        get_u32(m + CHECKIN_REPLY_DESC_COUNT_OFF) == 1U &&
        get_u32(m + CHECKIN_REPLY_PORT_OFF) != 0U &&
        m[CHECKIN_REPLY_DISPOSITION_OFF] == 0x11 &&
        m[CHECKIN_REPLY_TYPE_OFF] == 0x00) {
        gServerCheckinReplyPort =
            (mach_port_t)get_u32(m + CHECKIN_REPLY_PORT_OFF);
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_SERVERCHECKIN_REPLY_PORT:source=%s port=0x%08lx\n",
                source ? source : "(unknown)",
                (unsigned long)gServerCheckinReplyPort);
        fflush(stderr);
    }
}

static int
is_sessioninit_candidate(mach_msg_header_t *msg)
{
    unsigned char *m = (unsigned char *)msg;

    if (msg == NULL || gCoreServicesServerPort == MACH_PORT_NULL)
        return 0;

    return get_u32(m + 0x08) == (uint32_t)gCoreServicesServerPort &&
           get_u32(m + 0x14) == SESSIONINIT_REQUEST_ID;
}

static int
is_exact_legacy_sessioninit(mach_msg_header_t *msg,
                            mach_msg_option_t option,
                            mach_msg_size_t send_size,
                            mach_msg_size_t rcv_size,
                            mach_port_name_t rcv_name,
                            mach_msg_timeout_t timeout,
                            mach_port_name_t notify)
{
    unsigned char *m = (unsigned char *)msg;

    if (!is_sessioninit_candidate(msg))
        return 0;

    if ((uint32_t)option != 0x00000003U ||
        send_size != SESSIONINIT_LEGACY_SEND_SIZE ||
        rcv_size != SESSIONINIT_RECV_SIZE ||
        timeout != MACH_MSG_TIMEOUT_NONE ||
        notify != MACH_PORT_NULL)
        return 0;

    if (get_u32(m + 0x00) != SESSIONINIT_BITS ||
        get_u32(m + 0x0c) != (uint32_t)rcv_name)
        return 0;

    return 1;
}

static mach_msg_return_t
handle_sessioninit(mach_msg_header_t *msg,
                   mach_msg_option_t option,
                   mach_msg_size_t send_size,
                   mach_msg_size_t rcv_size,
                   mach_port_name_t rcv_name,
                   mach_msg_timeout_t timeout,
                   mach_port_name_t notify)
{
    const char *mode;
    unsigned char *m = (unsigned char *)msg;
    mach_msg_return_t mr;
    uint32_t legacy_pid;
    uint32_t legacy_uid;
    uint32_t legacy_layout;
    uint32_t reply_size;
    uint32_t reply_id;
    uint32_t retcode_raw;

    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_SESSIONINIT_CANDIDATE:bits=0x%08lx headerSizeObserved=0x%08lx id=0x%08lx option=0x%08lx send=0x%08lx recv=0x%08lx remotePort=0x%08lx serverCheckinPort=0x%08lx serverCheckinReplyPort=0x%08lx headerReplyPort=0x%08lx receivePort=0x%08lx timeout=0x%08lx notify=0x%08lx\n",
            (unsigned long)get_u32(m + 0x00),
            (unsigned long)get_u32(m + 0x04),
            (unsigned long)get_u32(m + 0x14),
            (unsigned long)(uint32_t)option,
            (unsigned long)send_size,
            (unsigned long)rcv_size,
            (unsigned long)get_u32(m + 0x08),
            (unsigned long)gCoreServicesServerPort,
            (unsigned long)gServerCheckinReplyPort,
            (unsigned long)get_u32(m + 0x0c),
            (unsigned long)rcv_name,
            (unsigned long)timeout,
            (unsigned long)notify);
    fflush(stderr);

    if (!is_exact_legacy_sessioninit(msg, option, send_size,
                                     rcv_size, rcv_name,
                                     timeout, notify)) {
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_SESSIONINIT_RESULT:NONEXACT_PASSTHROUGH\n");
        fflush(stderr);
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    ++gSessionInitExactCallCount;
    mode = getenv(COMPAT_MODE_ENV);
    legacy_pid = get_u32(m + SESSIONINIT_LEGACY_PID_OFF);
    legacy_uid = get_u32(m + SESSIONINIT_LEGACY_UID_OFF);
    legacy_layout = get_u32(m + SESSIONINIT_LEGACY_LAYOUT_OFF);

    fprintf(stderr, "%s\n", COMPAT_BUILD_MARKER);
    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_SESSIONINIT_EXACT_CALL:index=%u mode=%s pid=%lu uid=%lu layout=%lu\n",
            gSessionInitExactCallCount,
            mode ? mode : "(unset)",
            (unsigned long)legacy_pid,
            (unsigned long)legacy_uid,
            (unsigned long)legacy_layout);
    fflush(stderr);

    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_SESSIONINIT_ROUTE:remotePort=0x%08lx serverCheckinPort=0x%08lx serverCheckinReplyPort=0x%08lx\n",
            (unsigned long)get_u32(m + 0x08),
            (unsigned long)gCoreServicesServerPort,
            (unsigned long)gServerCheckinReplyPort);
    fflush(stderr);

    if (mode != NULL && strcmp(mode, COMPAT_MODE_PASSTHROUGH) == 0) {
        mr = call_original_mach_msg(msg, option, send_size,
                                    rcv_size, rcv_name,
                                    timeout, notify);
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_SESSIONINIT_PASSTHROUGH_RETURN:kr=%ld hex=0x%08lx\n",
                (long)mr, (unsigned long)(uint32_t)mr);
        fflush(stderr);
        return mr;
    }

    if (mode == NULL ||
        strcmp(mode, COMPAT_MODE_LION_SESSIONINIT) != 0)
        return MIG_BAD_ARGUMENTS;

    if (gSessionInitAdaptedCallCount != 0) {
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_SESSIONINIT_RESULT:SECOND_EXACT_CALL_BLOCKED\n");
        fflush(stderr);
        return MIG_BAD_ARGUMENTS;
    }

    ++gSessionInitAdaptedCallCount;

    put_u32(m + SESSIONINIT_LION_UID_OFF, legacy_uid);
    put_u32(m + SESSIONINIT_LION_LAYOUT_OFF, legacy_layout);
    put_u32(m + 0x04, SESSIONINIT_LION_SEND_SIZE);

    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_SESSIONINIT_ADAPTER_REQUEST:id=0x%08lx legacySend=0x%08lx adaptedSend=0x%08lx recv=0x%08lx droppedPid=%lu uid=%lu layout=%lu\n",
            (unsigned long)get_u32(m + 0x14),
            (unsigned long)send_size,
            (unsigned long)SESSIONINIT_LION_SEND_SIZE,
            (unsigned long)rcv_size,
            (unsigned long)legacy_pid,
            (unsigned long)get_u32(m + SESSIONINIT_LION_UID_OFF),
            (unsigned long)get_u32(m + SESSIONINIT_LION_LAYOUT_OFF));
    fflush(stderr);

    mr = call_original_mach_msg(msg, option,
                                (mach_msg_size_t)SESSIONINIT_LION_SEND_SIZE,
                                rcv_size, rcv_name, timeout, notify);

    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_SESSIONINIT_ADAPTER_MACH_MSG:kr=%ld hex=0x%08lx\n",
            (long)mr, (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr != MACH_MSG_SUCCESS)
        return mr;

    reply_size = get_u32(m + 0x04);
    reply_id = get_u32(m + 0x14);
    retcode_raw = get_u32(m + SESSIONINIT_REPLY_RETCODE_OFF);

    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_SESSIONINIT_ADAPTER_REPLY:size=0x%08lx id=0x%08lx retcodeRaw=0x%08lx\n",
            (unsigned long)reply_size,
            (unsigned long)reply_id,
            (unsigned long)retcode_raw);
    fflush(stderr);

    if (reply_id == SESSIONINIT_REPLY_ID &&
        reply_size == SESSIONINIT_SUCCESS_SIZE &&
        retcode_raw == 0U) {
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_SESSIONINIT_RESULT:PASS\n");
        fflush(stderr);
    } else if (reply_id == SESSIONINIT_REPLY_ID &&
               reply_size == SESSIONINIT_ERROR_SIZE) {
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_SESSIONINIT_RESULT:SERVER_ERROR retcodeRaw=0x%08lx\n",
                (unsigned long)retcode_raw);
        fflush(stderr);
    } else {
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_SESSIONINIT_RESULT:REPLY_SHAPE_UNEXPECTED\n");
        fflush(stderr);
    }

    return mr;
}

static mach_msg_return_t
rosetta_mach_msg(mach_msg_header_t *msg,
                 mach_msg_option_t option,
                 mach_msg_size_t send_size,
                 mach_msg_size_t rcv_size,
                 mach_port_name_t rcv_name,
                 mach_msg_timeout_t timeout,
                 mach_port_name_t notify)
{
    const char *mode;
    unsigned char *m = (unsigned char *)msg;
    mach_msg_return_t mr;

    if (is_servercheckin_candidate(msg)) {
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_SERVERCHECKIN_CANDIDATE:bits=0x%08lx headerSizeObserved=0x%08lx id=0x%08lx option=0x%08lx send=0x%08lx recv=0x%08lx serverPort=0x%08lx headerReplyPort=0x%08lx receivePort=0x%08lx descriptorCount=%lu descriptorPort=0x%08lx disposition=0x%02x type=0x%02x timeout=0x%08lx notify=0x%08lx\n",
                (unsigned long)get_u32(m + 0x00),
                (unsigned long)get_u32(m + 0x04),
                (unsigned long)get_u32(m + 0x14),
                (unsigned long)(uint32_t)option,
                (unsigned long)send_size,
                (unsigned long)rcv_size,
                (unsigned long)get_u32(m + 0x08),
                (unsigned long)get_u32(m + 0x0c),
                (unsigned long)rcv_name,
                (unsigned long)get_u32(m + 0x18),
                (unsigned long)get_u32(m + 0x1c),
                (unsigned int)m[0x26],
                (unsigned int)m[0x27],
                (unsigned long)timeout,
                (unsigned long)notify);
        fflush(stderr);
    }

    if (!is_servercheckin_candidate(msg)) {
        if (is_sessioninit_candidate(msg))
            return handle_sessioninit(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
#if defined(PM_CGS_CONNECTION_TRACE) || defined(PM_CGS_SERVER_VERSION_COMPAT_INTEGRATION)
        if (is_cgs_trace_candidate(msg))
            return trace_cgs_message(msg, option, send_size,
                                     rcv_size, rcv_name,
                                     timeout, notify);
#ifdef PM_CGS_SHOWWINDOW_UNKNOWN_TRACE
        if (is_cgs_showwindow_unknown_trace_candidate(
                msg, option, send_size, rcv_size, rcv_name,
                timeout, notify))
            return trace_cgs_message(msg, option, send_size,
                                     rcv_size, rcv_name,
                                     timeout, notify);
#endif
#endif
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    if (!is_exact_legacy_servercheckin(msg, option, send_size,
                                       rcv_size, rcv_name,
                                       timeout, notify)) {
        return call_original_mach_msg(msg, option, send_size,
                                      rcv_size, rcv_name,
                                      timeout, notify);
    }

    ++gServerCheckinExactCallCount;
    mode = getenv(COMPAT_MODE_ENV);

    fprintf(stderr, "%s\n", COMPAT_BUILD_MARKER);
    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_SERVERCHECKIN_EXACT_CALL:index=%u mode=%s serverPort=0x%08lx replyPort=0x%08lx descriptorPort=0x%08lx\n",
            gServerCheckinExactCallCount,
            mode ? mode : "(unset)",
            (unsigned long)gCoreServicesServerPort,
            (unsigned long)rcv_name,
            (unsigned long)get_u32(m + 0x1c));
    fflush(stderr);

    if (mode != NULL && strcmp(mode, COMPAT_MODE_PASSTHROUGH) == 0) {
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_SERVERCHECKIN_PASSTHROUGH:bits=0x%08lx send=0x%08lx recv=0x%08lx\n",
                (unsigned long)get_u32(m + 0x00),
                (unsigned long)send_size,
                (unsigned long)rcv_size);
        fflush(stderr);
        mr = call_original_mach_msg(msg, option, send_size,
                                    rcv_size, rcv_name,
                                    timeout, notify);
        record_servercheckin_session_port(m, mr, "passthrough");
        return mr;
    }

    if (!is_lion_compat_mode(mode))
        return MIG_BAD_ARGUMENTS;

    if (gServerCheckinAdaptedCallCount != 0) {
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_SERVERCHECKIN_ADAPTER_RESULT:SECOND_EXACT_CALL_BLOCKED\n");
        fflush(stderr);
        return MIG_BAD_ARGUMENTS;
    }

    ++gServerCheckinAdaptedCallCount;

    put_u32(m + 0x00, CHECKIN_LION_BITS);
    put_u32(m + 0x04, CHECKIN_LION_SEND_SIZE);

    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_SERVERCHECKIN_ADAPTER_REQUEST:bits=0x%08lx id=0x%08lx legacy_send=0x%08lx adapted_send=0x%08lx recv=0x%08lx\n",
            (unsigned long)get_u32(m + 0x00),
            (unsigned long)get_u32(m + 0x14),
            (unsigned long)send_size,
            (unsigned long)CHECKIN_LION_SEND_SIZE,
            (unsigned long)rcv_size);
    fflush(stderr);

    mr = call_original_mach_msg(msg, option,
                                (mach_msg_size_t)CHECKIN_LION_SEND_SIZE,
                                rcv_size, rcv_name, timeout, notify);

    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_SERVERCHECKIN_ADAPTER_MACH_MSG:kr=%ld hex=0x%08lx\n",
            (long)mr, (unsigned long)(uint32_t)mr);
    fflush(stderr);

    if (mr == MACH_MSG_SUCCESS) {
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_SERVERCHECKIN_ADAPTER_REPLY:bits=0x%08lx size=0x%08lx id=0x%08lx\n",
                (unsigned long)get_u32(m + 0x00),
                (unsigned long)get_u32(m + 0x04),
                (unsigned long)get_u32(m + 0x14));
        fflush(stderr);

        if (get_u32(m + 0x14) == CHECKIN_REPLY_ID &&
            get_u32(m + 0x04) == CHECKIN_SUCCESS_SIZE &&
            (get_u32(m + 0x00) & MACH_MSGH_BITS_COMPLEX) != 0 &&
            get_u32(m + CHECKIN_REPLY_DESC_COUNT_OFF) == 1U &&
            get_u32(m + CHECKIN_REPLY_PORT_OFF) != 0U &&
            m[CHECKIN_REPLY_DISPOSITION_OFF] == 0x11 &&
            m[CHECKIN_REPLY_TYPE_OFF] == 0x00) {
            record_servercheckin_session_port(m, mr, "adapter");
            fprintf(stderr,
                    "PM_CORESERVICES_COMPAT_SERVERCHECKIN_ADAPTER_RESULT:PASS sessionPort=0x%08lx options=0x%08lx\n",
                    (unsigned long)gServerCheckinReplyPort,
                    (unsigned long)get_u32(m + CHECKIN_REPLY_OPTIONS_OFF));
            fflush(stderr);
        } else {
            fprintf(stderr,
                    "PM_CORESERVICES_COMPAT_SERVERCHECKIN_ADAPTER_RESULT:REPLY_SHAPE_UNEXPECTED\n");
            fflush(stderr);
        }
    }

    return mr;
}

static kern_return_t
rosetta_bootstrap_look_up2(mach_port_t bp,
                           const char *service_name,
                           mach_port_t *service_port,
                           pid_t target_pid,
                           uint64_t flags)
{
    const char *mode;
    int exact_match;
    kern_return_t kr;

#ifdef PM_DISTRIBUTED_NOTIFICATIONS_INGRESS_INTEGRATION
    if (service_name != NULL &&
        strcmp(service_name, kDistributedNotificationsName) == 0 &&
        target_pid == (pid_t)0 &&
        flags == PRIVILEGED_SERVER_FLAG) {
        return rosetta_distnotify_handle_lookup2(
            original_lookup(),
            bp,
            service_name,
            service_port,
            target_pid,
            flags);
    }
#endif

#ifdef PM_DISTRIBUTED_NOTIFICATIONS_COMPAT_PROTOCOL
    if (service_name != NULL &&
        strcmp(service_name, kDistributedNotificationsName) == 0 &&
        target_pid == (pid_t)0 &&
        flags == PRIVILEGED_SERVER_FLAG) {
        ++gDistributedNotificationsCompatCallCount;
        mode = getenv(DISTNOTIFY_COMPAT_ENV);

        fprintf(stderr, "%s\n", COMPAT_BUILD_MARKER);
        fprintf(stderr,
                "PM_DISTRIBUTED_NOTIFICATIONS_COMPAT_CALL:index=%u mode=%s bp=0x%08lx name=%s pid=%ld flags=0x%08lx%08lx\n",
                gDistributedNotificationsCompatCallCount,
                mode ? mode : "(unset)",
                (unsigned long)bp,
                service_name,
                (long)target_pid,
                (unsigned long)(uint32_t)(flags >> 32),
                (unsigned long)(uint32_t)flags);
        fflush(stderr);

        if (mode != NULL &&
            strcmp(mode, DISTNOTIFY_COMPAT_PASSTHROUGH) == 0) {
            kr = call_original_lookup(bp, service_name, service_port,
                                      target_pid, flags,
                                      "DISTNOTIFY_SNOW_CONTROL");
            fprintf(stderr,
                    "PM_DISTRIBUTED_NOTIFICATIONS_COMPAT_RESULT:PASSTHROUGH kr=%ld hex=0x%08lx servicePort=0x%08lx\n",
                    (long)kr,
                    (unsigned long)(uint32_t)kr,
                    (unsigned long)((service_port != NULL) ?
                                    *service_port : MACH_PORT_NULL));
            fflush(stderr);
            return kr;
        }

        if (mode == NULL ||
            strcmp(mode, DISTNOTIFY_COMPAT_LION_V1) != 0 ||
            gDistributedNotificationsCompatCallCount != 1U) {
            if (service_port != NULL)
                *service_port = MACH_PORT_NULL;
            fprintf(stderr,
                    "PM_DISTRIBUTED_NOTIFICATIONS_COMPAT_RESULT:PREDICATE_REJECTED\n");
            fflush(stderr);
            return MIG_BAD_ARGUMENTS;
        }

        kr = lion_format_lookup(bp, service_name, service_port,
                                target_pid, flags);
        if (kr == KERN_SUCCESS &&
            service_port != NULL &&
            *service_port != MACH_PORT_NULL) {
            fprintf(stderr,
                    "PM_DISTRIBUTED_NOTIFICATIONS_COMPAT_RESULT:ADAPTER_PASS kr=%ld hex=0x%08lx servicePort=0x%08lx\n",
                    (long)kr,
                    (unsigned long)(uint32_t)kr,
                    (unsigned long)*service_port);
        } else {
            fprintf(stderr,
                    "PM_DISTRIBUTED_NOTIFICATIONS_COMPAT_RESULT:ADAPTER_FAILED kr=%ld hex=0x%08lx servicePort=0x%08lx\n",
                    (long)kr,
                    (unsigned long)(uint32_t)kr,
                    (unsigned long)((service_port != NULL) ?
                                    *service_port : MACH_PORT_NULL));
        }
        fflush(stderr);
        return kr;
    }
#endif

    exact_match = (service_name != NULL &&
                   strcmp(service_name, kCoreServicesDName) == 0 &&
                   target_pid == (pid_t)0 &&
                   flags == PRIVILEGED_SERVER_FLAG);

    if (!exact_match) {
        return call_original_lookup(bp, service_name, service_port,
                                    target_pid, flags, "NON_TARGET");
    }

    ++gBootstrapExactCallCount;
    mode = getenv(COMPAT_MODE_ENV);

    fprintf(stderr, "%s\n", COMPAT_BUILD_MARKER);
    fprintf(stderr,
            "PM_CORESERVICES_COMPAT_BOOTSTRAP_EXACT_CALL:index=%u mode=%s\n",
            gBootstrapExactCallCount,
            mode ? mode : "(unset)");
    fflush(stderr);

    if (mode != NULL && strcmp(mode, COMPAT_MODE_PASSTHROUGH) == 0) {
        kr = call_original_lookup(bp, service_name, service_port,
                                  target_pid, flags,
                                  "SNOW_CONTROL_EXACT_TARGET");
        if (kr == KERN_SUCCESS && service_port != NULL)
            gCoreServicesServerPort = *service_port;
        return kr;
    }

    if (!is_lion_compat_mode(mode)) {
        if (service_port != NULL)
            *service_port = MACH_PORT_NULL;
        return MIG_BAD_ARGUMENTS;
    }

    if (gBootstrapAdaptedCallCount != 0) {
        if (service_port != NULL)
            *service_port = MACH_PORT_NULL;
        fprintf(stderr,
                "PM_CORESERVICES_COMPAT_BOOTSTRAP_ADAPTER_RESULT:SECOND_EXACT_CALL_BLOCKED\n");
        fflush(stderr);
        return MIG_BAD_ARGUMENTS;
    }

    ++gBootstrapAdaptedCallCount;
    kr = lion_format_lookup(bp, service_name, service_port,
                            target_pid, flags);
    if (kr == KERN_SUCCESS && service_port != NULL)
        gCoreServicesServerPort = *service_port;
    return kr;
}

__attribute__((used))
static struct interpose_tuple sInterposes[2]
__attribute__((section("__DATA,__interpose"))) = {
    {
        (const void *)(uintptr_t)&rosetta_bootstrap_look_up2,
        (const void *)(uintptr_t)&bootstrap_look_up2
    },
    {
        (const void *)(uintptr_t)&rosetta_mach_msg,
        (const void *)(uintptr_t)&mach_msg
    }
};
