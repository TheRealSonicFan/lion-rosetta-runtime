#!/usr/bin/python
from __future__ import print_function

import os
import re
import sys

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-coreui-windowframe-shared-art-selection-live-v1"
BUILD_ID = "coreui-windowframe-shared-art-selection-trace-compat-v1"

RAW_RE = re.compile(
    r"^PM_COREUI_SHARED_ART_SELECTION_RAW:phase=(CALL|RESULT) "
    r"frame_id=(0x[0-9a-fA-F]+) stack_ok=(YES|NO) frame_target=(YES|NO) "
    r"width=([0-9]+) height=([0-9]+) bpr=([0-9]+)"
    r"(?: result=(NONNULL|NULL))?$"
)
IMAGEIO_RE = re.compile(
    r"^PM_COREUI_SHARED_ART_SELECTION_IMAGEIO:phase=(CALL|RESULT) "
    r"frame_id=(0x[0-9a-fA-F]+) stack_ok=(YES|NO) frame_target=(YES|NO) "
    r"image_index=([0-9]+)(?: result=(NONNULL|NULL))?$"
)

FRAME_IDS = set([
    0x4e8e, 0x4e90, 0x4e89, 0x4e8a, 0x4e8d, 0x4e8f, 0x4e91
])


def emit(fp, value=""):
    fp.write(value)
    fp.write("\n")


def last_value(lines, prefix):
    value = None
    for line in lines:
        if line.startswith(prefix):
            value = line[len(prefix):].strip()
    return value


def main():
    if len(sys.argv) != 3:
        print("usage: %s SUBJECT_LOG OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    log_path = sys.argv[1]
    out_path = sys.argv[2]

    if not os.path.isfile(log_path):
        print("error: missing subject log: %s" % log_path, file=sys.stderr)
        return 66

    data = open(log_path, "r").read().splitlines()
    product = last_value(data, "product_version=") or "UNKNOWN"
    build = last_value(data, "build_version=") or "UNKNOWN"
    mode = "UNKNOWN"
    if product == "10.6.8" and build == "10K549":
        mode = "snow"
    elif product == "10.7.5" and build == "11G63":
        mode = "lion"

    raw_calls = []
    raw_results = []
    imageio_calls = []
    imageio_results = []

    for line in data:
        m = RAW_RE.match(line)
        if m:
            item = dict(
                phase=m.group(1),
                image_id=int(m.group(2), 16),
                image_id_text=m.group(2).lower(),
                stack_ok=m.group(3),
                frame_target=m.group(4),
                width=int(m.group(5)),
                height=int(m.group(6)),
                bpr=int(m.group(7)),
                result=m.group(8),
            )
            if item["phase"] == "CALL":
                raw_calls.append(item)
            else:
                raw_results.append(item)
            continue

        m = IMAGEIO_RE.match(line)
        if m:
            item = dict(
                phase=m.group(1),
                image_id=int(m.group(2), 16),
                image_id_text=m.group(2).lower(),
                stack_ok=m.group(3),
                frame_target=m.group(4),
                image_index=int(m.group(5)),
                result=m.group(6),
            )
            if item["phase"] == "CALL":
                imageio_calls.append(item)
            else:
                imageio_results.append(item)

    build_marker = "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_BUILD_ID:%s" % BUILD_ID
    build_marker_count = sum(1 for line in data if line == build_marker)
    runner_pass_count = sum(1 for line in data if line == "RESULT: PASS")
    exact_titlebar_count = sum(
        1 for line in data
        if line.startswith("PM_COREUI_IMAGE_BITMAPINFO_COMPAT_CALL:") and
           " exact=YES " in line and
           " caller_offset=0x000299e0" in line
    )
    adapted_count = sum(
        1 for line in data
        if line == "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_ADAPTED:from=0x00000002 to=0x00002002"
    )

    issues = []
    if mode == "UNKNOWN":
        issues.append("unexpected product/build identity")
    if build_marker_count != 1:
        issues.append("shared-art trace build marker count is not 1")
    if runner_pass_count < 1:
        issues.append("underlying compatibility runner did not end in PASS")
    if exact_titlebar_count != 6:
        issues.append("accepted exact-six bitmap-info call count is not 6")
    if mode == "snow" and adapted_count != 0:
        issues.append("Snow unexpectedly adapted titlebar bitmap info")
    if mode == "lion" and adapted_count != 6:
        issues.append("Lion exact-six bitmap-info adaptation count is not 6")

    if len(raw_calls) != len(raw_results):
        issues.append("raw shared-art CALL/RESULT count mismatch")
    if len(imageio_calls) != len(imageio_results):
        issues.append("ImageIO shared-art CALL/RESULT count mismatch")

    for item in raw_calls + raw_results + imageio_calls + imageio_results:
        if item["stack_ok"] != "YES":
            issues.append("stack recovery failed for shared-art trace")
        if item["frame_target"] != "YES":
            issues.append("recovered shared-art ID is outside exact-seven frame set")
        if item["image_id"] not in FRAME_IDS:
            issues.append("recovered shared-art ID is not an exact-seven frame ID")
        if item.get("result") == "NULL":
            issues.append("shared-art image result is NULL")

    if mode == "snow":
        if len(raw_calls) != 5:
            issues.append("Snow raw shared-art call count is not the prior live count 5")
        for item in raw_calls:
            if (item["width"], item["height"], item["bpr"]) != (11, 11, 44):
                issues.append("Snow raw shared-art geometry differs from prior 11x11/bpr44")
        if imageio_calls:
            issues.append("Snow exact-seven frame IDs unexpectedly used ImageIO")
    elif mode == "lion":
        if len(raw_calls) != 2:
            issues.append("Lion raw shared-art call count is not the prior live count 2")
        dims = sorted((item["width"], item["height"], item["bpr"]) for item in raw_calls)
        if dims != [(2, 62, 8), (256, 256, 1024)]:
            issues.append("Lion raw shared-art geometry differs from prior 2x62/256x256 stream")

    fp = open(out_path, "w")
    try:
        emit(fp, "== PPC Carbon GUI CoreUI shared-art selection live trace ==")
        emit(fp, "analyzer_version=%s" % ANALYZER_VERSION)
        emit(fp, "audit_contract=%s" % AUDIT_CONTRACT)
        emit(fp, "trace_build_id=%s" % BUILD_ID)
        emit(fp, "product_version=%s" % product)
        emit(fp, "build_version=%s" % build)
        emit(fp, "mode=%s" % mode)
        emit(fp, "build_marker_count=%d" % build_marker_count)
        emit(fp, "runner_pass_count=%d" % runner_pass_count)
        emit(fp, "exact_titlebar_bitmapinfo_call_count=%d" % exact_titlebar_count)
        emit(fp, "titlebar_bitmapinfo_adapted_count=%d" % adapted_count)

        emit(fp)
        emit(fp, "== Raw CreateImageFromBytes selections ==")
        emit(fp, "raw_call_count=%d" % len(raw_calls))
        for i, item in enumerate(raw_calls):
            emit(fp,
                 "raw_call=%d frame_id=0x%04x width=%d height=%d bpr=%d stack_ok=%s frame_target=%s" %
                 (i + 1, item["image_id"], item["width"], item["height"],
                  item["bpr"], item["stack_ok"], item["frame_target"]))
        emit(fp, "raw_result_count=%d" % len(raw_results))
        for i, item in enumerate(raw_results):
            emit(fp,
                 "raw_result=%d frame_id=0x%04x width=%d height=%d bpr=%d result=%s" %
                 (i + 1, item["image_id"], item["width"], item["height"],
                  item["bpr"], item["result"] or "MISSING"))

        emit(fp)
        emit(fp, "== ImageIO CreateImageSource selections ==")
        emit(fp, "imageio_call_count=%d" % len(imageio_calls))
        for i, item in enumerate(imageio_calls):
            emit(fp,
                 "imageio_call=%d frame_id=0x%04x image_index=%d stack_ok=%s frame_target=%s" %
                 (i + 1, item["image_id"], item["image_index"],
                  item["stack_ok"], item["frame_target"]))
        emit(fp, "imageio_result_count=%d" % len(imageio_results))
        for i, item in enumerate(imageio_results):
            emit(fp,
                 "imageio_result=%d frame_id=0x%04x image_index=%d result=%s" %
                 (i + 1, item["image_id"], item["image_index"],
                  item["result"] or "MISSING"))

        if mode == "lion":
            two62 = [item for item in raw_calls
                     if (item["width"], item["height"]) == (2, 62)]
            two56 = [item for item in raw_calls
                     if (item["width"], item["height"]) == (256, 256)]
            emit(fp)
            emit(fp, "== Lion geometry identity ==")
            emit(fp, "lion_2x62_frame_id=%s" %
                 ("0x%04x" % two62[0]["image_id"] if len(two62) == 1 else "AMBIGUOUS"))
            emit(fp, "lion_256x256_frame_id=%s" %
                 ("0x%04x" % two56[0]["image_id"] if len(two56) == 1 else "AMBIGUOUS"))

        emit(fp)
        emit(fp, "== Audit validation ==")
        if issues:
            for issue in issues:
                emit(fp, "validation_issue=%s" % issue)
            emit(fp, "RESULT: FAIL")
        else:
            emit(fp, "shared_art_selection_trace_exact=YES")
            emit(fp, "RESULT: PASS")
    finally:
        fp.close()

    print("Created: %s" % out_path)
    if issues:
        print("RESULT: FAIL")
        for issue in issues:
            print("validation_issue=%s" % issue)
        return 1
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
