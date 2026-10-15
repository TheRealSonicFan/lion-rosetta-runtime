#!/usr/bin/python
from __future__ import print_function
import re
import sys

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-coreui-windowframe-shared-art-slot0-format-compat-live-v1"
BUILD_ID = "coreui-windowframe-shared-art-slot0-compat-v2"

MAP = {
    0x4e8d: 0x4e75,
    0x4e8e: 0x4e76,
    0x4e8f: 0x4e77,
    0x4e90: 0x4e78,
    0x4e91: 0x4e79,
}
EXPECTED_BITMAP = {
    0x4e8d: 0x00000002,
    0x4e8e: 0x00000002,
    0x4e8f: 0x00002002,
    0x4e90: 0x00000002,
    0x4e91: 0x00002002,
}
SNOW_ORDER = [0x4e8e, 0x4e90, 0x4e8d, 0x4e8f, 0x4e91]
RAW_IDS = set([0x4e8e, 0x4e8d])
IMAGEIO_IDS = set([0x4e90, 0x4e8f, 0x4e91])
SHIFTED_PAYLOADS = [269, 269, 271, 277, 273, 277, 273, 286, 283, 272, 275, 273, 274, 257]

ACTIVITY_RE = re.compile(
    r"^PM_COREUI_SHARED_ART_SLOT0_COMPAT:(PASSTHROUGH|SOURCE_BIND|CALL|RESULT) "
    r"branch=(RAW|IMAGEIO) legacy_id=(0x[0-9a-fA-F]+) "
    r"lion_id=(0x[0-9a-fA-F]+)(?: result=([^ ]+))?$"
)
FORMAT_RE = re.compile(
    r"^PM_COREUI_SHARED_ART_SLOT0_FORMAT:legacy_id=(0x[0-9a-fA-F]+) "
    r"lion_id=(0x[0-9a-fA-F]+) bitmapInfo=(0x[0-9a-fA-F]+)$"
)
REQUEST_RE = re.compile(
    r"^PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:index=([0-9]+) "
    r".* payload=([0-9]+) "
)


def emit(fp, value=""):
    fp.write(value + "\n")


def get_scalar(lines, key):
    prefix = key + "="
    values = [line.strip().split("=", 1)[1] for line in lines
              if line.strip().startswith(prefix)]
    return values[-1] if values else None


def main():
    if len(sys.argv) != 3:
        print("usage: %s SUBJECT_LOG OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    lines = open(sys.argv[1], "r").readlines()
    product = get_scalar(lines, "product_version")
    build = get_scalar(lines, "build_version")
    mode = "snow" if product == "10.6.8" and build == "10K549" else (
        "lion" if product == "10.7.5" and build == "11G63" else "unknown"
    )
    issues = []
    activities = []
    formats = []
    requests = {}

    for line in lines:
        s = line.strip()
        m = ACTIVITY_RE.match(s)
        if m:
            activities.append(dict(
                phase=m.group(1),
                branch=m.group(2),
                legacy=int(m.group(3), 16),
                lion=int(m.group(4), 16),
                result=m.group(5),
            ))
        m = FORMAT_RE.match(s)
        if m:
            formats.append(dict(
                legacy=int(m.group(1), 16),
                lion=int(m.group(2), 16),
                bitmap=int(m.group(3), 16),
            ))
        m = REQUEST_RE.match(s)
        if m:
            requests[int(m.group(1))] = int(m.group(2))

    build_count = sum(
        1 for line in lines
        if line.strip() == "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_BUILD_ID:" + BUILD_ID
    )
    runner_pass = any(line.strip() == "RESULT: PASS" for line in lines)
    runner_fail = any(line.strip() == "RESULT: FAIL" for line in lines)
    exact = sum(
        1 for line in lines
        if line.startswith("PM_COREUI_IMAGE_BITMAPINFO_COMPAT_CALL:")
        and " exact=YES " in line
    )
    adapted = sum(
        1 for line in lines
        if line.strip() == "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_ADAPTED:from=0x00000002 to=0x00002002"
    )
    passthrough_bm = sum(
        1 for line in lines
        if line.strip() == "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PASSTHROUGH"
    )
    bitmap_pass = sum(
        1 for line in lines
        if line.strip() == "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_PASS"
    )
    fallback_count = sum(1 for line in lines if "ADAPTER_FALLBACK" in line)
    null_count = sum(1 for line in lines if "ADAPTER_NULL" in line)

    shifted_payloads = [requests.get(i) for i in range(7, 21)]
    known_shift = (
        mode == "lion"
        and not runner_pass
        and runner_fail
        and get_scalar(lines, "carbon_gui_exec_status") == "0"
        and get_scalar(lines, "windowserver_observer_status") == "0"
        and get_scalar(lines, "protected_hashes_unchanged") == "YES"
        and get_scalar(lines, "notification_register_accept_count") == "6"
        and get_scalar(lines, "notification_broker_summary_count") == "0"
        and get_scalar(lines, "notification_broker_pass_count") == "0"
        and get_scalar(lines, "notification_broker_fail_count") == "1"
        and get_scalar(lines, "notification_broker_reject_count") == "14"
        and shifted_payloads == SHIFTED_PAYLOADS
        and 21 not in requests
    )

    if mode == "unknown":
        issues.append("unsupported product/build")
    if build_count != 1:
        issues.append("build marker count mismatch")
    if exact != 6:
        issues.append("bitmapInfo exact-six count mismatch")
    if fallback_count != 0:
        issues.append("slot0 fallback observed")
    if null_count != 0:
        issues.append("adapter null observed")

    for item in activities:
        if MAP.get(item["legacy"]) != item["lion"]:
            issues.append("mapping mismatch for 0x%04x" % item["legacy"])
    for item in formats:
        if MAP.get(item["legacy"]) != item["lion"]:
            issues.append("format mapping mismatch for 0x%04x" % item["legacy"])
        if EXPECTED_BITMAP.get(item["legacy"]) != item["bitmap"]:
            issues.append("format bitmapInfo mismatch for 0x%04x" % item["legacy"])

    pass_items = [item for item in activities if item["phase"] == "PASSTHROUGH"]
    binds = [item for item in activities if item["phase"] == "SOURCE_BIND"]
    calls = [item for item in activities if item["phase"] == "CALL"]
    results = [item for item in activities if item["phase"] == "RESULT"]

    if mode == "snow":
        if not runner_pass:
            issues.append("Snow underlying runner did not pass")
        if adapted != 0 or passthrough_bm != 6 or bitmap_pass != 0:
            issues.append("Snow bitmapInfo counts mismatch")
        if [item["legacy"] for item in pass_items if item["branch"] == "RAW"] != SNOW_ORDER:
            issues.append("Snow slot0 passthrough order mismatch")
        if binds or calls or results or formats:
            issues.append("Snow produced slot0 adaptation activity")
    elif mode == "lion":
        if not runner_pass and not known_shift:
            issues.append("Lion runner failure is not the known notification shift")
        if adapted != 6 or passthrough_bm != 0 or bitmap_pass != 6:
            issues.append("Lion exact-six bitmapInfo counts mismatch")
        raw_calls = [item for item in calls if item["branch"] == "RAW"]
        image_calls = [item for item in calls if item["branch"] == "IMAGEIO"]
        raw_results = [item for item in results if item["branch"] == "RAW"]
        image_results = [item for item in results if item["branch"] == "IMAGEIO"]
        if set(item["legacy"] for item in raw_calls) != RAW_IDS or len(raw_calls) != 2:
            issues.append("Lion raw adaptation ID set mismatch")
        if set(item["legacy"] for item in image_calls) != IMAGEIO_IDS or len(image_calls) != 3:
            issues.append("Lion ImageIO adaptation ID set mismatch")
        if set(item["legacy"] for item in binds) != IMAGEIO_IDS or len(binds) != 3:
            issues.append("Lion source binding ID set mismatch")
        if len(raw_results) != 2 or len(image_results) != 3:
            issues.append("Lion result count mismatch")
        if any(item.get("result") != "ADAPTER_PASS" for item in results):
            issues.append("Lion slot0 adapter non-pass result")
        if any(item.get("result") != "BOUND" for item in binds):
            issues.append("Lion source bind result mismatch")
        if pass_items:
            issues.append("Lion unexpected slot0 passthrough marker")
        if len(formats) != 5 or set(item["legacy"] for item in formats) != set(EXPECTED_BITMAP.keys()):
            issues.append("Lion slot0 format marker set mismatch")

    fp = open(sys.argv[2], "w")
    try:
        emit(fp, "== PPC Carbon GUI CoreUI shared-art slot0 format compatibility summary ==")
        emit(fp, "analyzer_version=%s" % ANALYZER_VERSION)
        emit(fp, "audit_contract=%s" % AUDIT_CONTRACT)
        emit(fp, "mode=%s" % mode)
        emit(fp, "product_version=%s" % (product or "UNKNOWN"))
        emit(fp, "build_version=%s" % (build or "UNKNOWN"))
        emit(fp, "build_marker_count=%d" % build_count)
        emit(fp, "runner_result_pass=%s" % ("YES" if runner_pass else "NO"))
        emit(fp, "known_notification_shift=%s" % ("YES" if known_shift else "NO"))
        emit(fp, "image_bitmapinfo_exact_call_count=%d" % exact)
        emit(fp, "image_bitmapinfo_adapted_count=%d" % adapted)
        emit(fp, "image_bitmapinfo_passthrough_count=%d" % passthrough_bm)
        emit(fp, "image_bitmapinfo_adapter_pass_count=%d" % bitmap_pass)
        emit(fp, "slot0_fallback_count=%d" % fallback_count)
        emit(fp, "adapter_null_count=%d" % null_count)

        emit(fp)
        emit(fp, "== Slot0 compatibility activity ==")
        emit(fp, "snow_raw_passthrough_count=%d" % len(pass_items))
        emit(fp, "source_bind_count=%d" % len(binds))
        emit(fp, "adapter_call_count=%d" % len(calls))
        emit(fp, "adapter_result_count=%d" % len(results))
        for item in activities:
            emit(fp, "activity phase=%s branch=%s legacy_id=0x%04x lion_id=0x%04x result=%s" % (
                item["phase"], item["branch"], item["legacy"], item["lion"],
                item.get("result") or "NONE"
            ))

        emit(fp)
        emit(fp, "== Slot0 image-format activity ==")
        for item in formats:
            emit(fp, "format legacy_id=0x%04x lion_id=0x%04x bitmapInfo=0x%08x" % (
                item["legacy"], item["lion"], item["bitmap"]
            ))
        emit(fp, "format_0x2_ids=%s" % ",".join(
            "0x%04x" % item["legacy"] for item in formats if item["bitmap"] == 0x2
        ))
        emit(fp, "format_0x2002_ids=%s" % ",".join(
            "0x%04x" % item["legacy"] for item in formats if item["bitmap"] == 0x2002
        ))

        emit(fp)
        emit(fp, "== Notification oracle ==")
        emit(fp, "request_7_to_20_payloads=%s" % ",".join(
            str(value) if value is not None else "MISSING" for value in shifted_payloads
        ))
        emit(fp, "request_21_present=%s" % ("YES" if 21 in requests else "NO"))

        emit(fp)
        emit(fp, "== Validation ==")
        if issues:
            for issue in issues:
                emit(fp, "validation_issue=%s" % issue)
            emit(fp, "RESULT: FAIL")
        else:
            emit(fp, "shared_art_slot0_format_compat_exact=YES")
            emit(fp, "RESULT: PASS")
    finally:
        fp.close()

    print("Created: %s" % sys.argv[2])
    if issues:
        print("RESULT: FAIL")
        for issue in issues:
            print("validation_issue=%s" % issue)
        return 1
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
