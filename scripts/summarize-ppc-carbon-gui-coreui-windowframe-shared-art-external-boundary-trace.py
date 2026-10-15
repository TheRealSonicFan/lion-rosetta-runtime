#!/usr/bin/python
from __future__ import print_function

import re
import sys

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-coreui-windowframe-shared-art-external-boundary-live-v1"
BUILD_ID = "coreui-windowframe-shared-art-external-boundary-trace-compat-v1"

ACTIVE_IDS = [0x4e8e, 0x4e90, 0x4e8d, 0x4e8f, 0x4e91]
SNOW_ORDER = ACTIVE_IDS
LION_RAW_IDS = set([0x4e8e, 0x4e8d])
LION_IMAGEIO_IDS = set([0x4e90, 0x4e8f, 0x4e91])

PROVIDER_RE = re.compile(
    r"^PM_COREUI_SHARED_ART_BOUNDARY_PROVIDER:path=(RAW|IMAGEIO) "
    r"phase=(CALL|RESULT) image_id=(0x[0-9a-fA-F]+) "
    r"stack_ok=(YES|NO) frame_target=(YES|NO) "
    r"data=(0x[0-9a-fA-F]+) size=([0-9]+)"
    r"(?: provider=(0x[0-9a-fA-F]+))?$"
)
SOURCE_RE = re.compile(
    r"^PM_COREUI_SHARED_ART_BOUNDARY_SOURCE:phase=(CALL|RESULT) "
    r"image_id=(0x[0-9a-fA-F]+) stack_ok=(YES|NO) "
    r"frame_target=(YES|NO) provider=(0x[0-9a-fA-F]+)"
    r"(?: source=(0x[0-9a-fA-F]+))?$"
)
FINAL_RE = re.compile(
    r"^PM_COREUI_SHARED_ART_BOUNDARY_FINAL:phase=(CALL|RESULT) "
    r"source=(0x[0-9a-fA-F]+) image_index=([0-9]+)"
    r"(?: result=(NONNULL|NULL))?$"
)
RAW_RE = re.compile(
    r"^PM_COREUI_SHARED_ART_BOUNDARY_RAW_IMAGE:phase=(CALL|RESULT) "
    r"image_id=(0x[0-9a-fA-F]+) stack_ok=(YES|NO) "
    r"frame_target=(YES|NO) width=([0-9]+) height=([0-9]+) bpr=([0-9]+)"
    r"(?: result=(NONNULL|NULL))?$"
)


def emit(fp, value=""):
    fp.write(value)
    fp.write("\n")


def parse_hex(value):
    return int(value, 16)


def parse_report(lines):
    providers = []
    sources = []
    finals = []
    raws = []
    for raw in lines:
        line = raw.rstrip("\r\n")
        m = PROVIDER_RE.match(line)
        if m:
            providers.append(dict(
                path=m.group(1), phase=m.group(2), image_id=parse_hex(m.group(3)),
                stack_ok=m.group(4), frame_target=m.group(5),
                data=m.group(6), size=int(m.group(7)),
                provider=m.group(8)))
            continue
        m = SOURCE_RE.match(line)
        if m:
            sources.append(dict(
                phase=m.group(1), image_id=parse_hex(m.group(2)),
                stack_ok=m.group(3), frame_target=m.group(4),
                provider=m.group(5), source=m.group(6)))
            continue
        m = FINAL_RE.match(line)
        if m:
            finals.append(dict(
                phase=m.group(1), source=m.group(2), image_index=int(m.group(3)),
                result=m.group(4)))
            continue
        m = RAW_RE.match(line)
        if m:
            raws.append(dict(
                phase=m.group(1), image_id=parse_hex(m.group(2)),
                stack_ok=m.group(3), frame_target=m.group(4),
                width=int(m.group(5)), height=int(m.group(6)),
                bpr=int(m.group(7)), result=m.group(8)))
    return providers, sources, finals, raws


def mode_from_lines(lines):
    product = None
    build = None
    for line in lines:
        if line.startswith("product_version="):
            product = line.split("=", 1)[1].strip()
        elif line.startswith("build_version="):
            build = line.split("=", 1)[1].strip()
    if product == "10.6.8" and build == "10K549":
        return "snow", product, build
    if product == "10.7.5" and build == "11G63":
        return "lion", product, build
    return "unknown", product or "UNKNOWN", build or "UNKNOWN"


def unique_target(items, phase=None, path=None):
    out = []
    for item in items:
        if phase is not None and item.get("phase") != phase:
            continue
        if path is not None and item.get("path") != path:
            continue
        if item.get("image_id") in ACTIVE_IDS:
            out.append(item)
    return out


def by_id(items):
    out = {}
    for item in items:
        out.setdefault(item["image_id"], []).append(item)
    return out


def main():
    if len(sys.argv) != 3:
        print("usage: %s SUBJECT_LOG OUTPUT" % sys.argv[0], file=sys.stderr)
        return 64

    subject_log = sys.argv[1]
    output = sys.argv[2]
    lines = open(subject_log, "r").readlines()
    mode, product, build = mode_from_lines(lines)
    providers, sources, finals, raws = parse_report(lines)
    issues = []

    build_count = sum(1 for x in lines if
                      x.strip() == "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_BUILD_ID:" + BUILD_ID)
    runner_pass = any(x.strip() == "RESULT: PASS" for x in lines)
    compat_call_count = sum(1 for x in lines if
                            x.startswith("PM_COREUI_IMAGE_BITMAPINFO_COMPAT_CALL:") and
                            " exact=YES " in x)
    adapted_count = sum(1 for x in lines if
                        x.strip() == "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_ADAPTED:from=0x00000002 to=0x00002002")
    passthrough_count = sum(1 for x in lines if
                            x.strip() == "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PASSTHROUGH")
    adapter_pass_count = sum(1 for x in lines if
                             x.strip() == "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_PASS")

    if mode == "unknown":
        issues.append("unsupported product/build")
    if build_count != 1:
        issues.append("build marker count is not one")
    if not runner_pass:
        issues.append("underlying compatibility runner did not pass")
    if compat_call_count != 6:
        issues.append("exact-six bitmapInfo call count mismatch")

    raw_calls = unique_target(raws, "CALL")
    raw_results = unique_target(raws, "RESULT")
    raw_provider_calls = unique_target(providers, "CALL", "RAW")
    raw_provider_results = unique_target(providers, "RESULT", "RAW")
    imageio_provider_calls = unique_target(providers, "CALL", "IMAGEIO")
    imageio_provider_results = unique_target(providers, "RESULT", "IMAGEIO")
    source_calls = unique_target(sources, "CALL")
    source_results = unique_target(sources, "RESULT")

    for collection, label in [
        (raw_calls, "raw image call"),
        (raw_results, "raw image result"),
        (raw_provider_calls, "raw provider call"),
        (raw_provider_results, "raw provider result"),
        (imageio_provider_calls, "ImageIO provider call"),
        (imageio_provider_results, "ImageIO provider result"),
        (source_calls, "source call"),
        (source_results, "source result"),
    ]:
        for item in collection:
            if item["stack_ok"] != "YES" or item["frame_target"] != "YES":
                issues.append("%s stack/target recovery failed" % label)

    for item in raw_results:
        if item.get("result") != "NONNULL":
            issues.append("raw target image result is NULL")
    for item in raw_provider_results + imageio_provider_results:
        if item.get("provider") in (None, "0x00000000"):
            issues.append("target provider result is NULL")
    for item in source_results:
        if item.get("source") in (None, "0x00000000"):
            issues.append("target ImageIO source result is NULL")

    correlated = []
    source_by_id = by_id(source_results)
    imageio_provider_by_id = by_id(imageio_provider_results)
    for image_id in ACTIVE_IDS:
        if image_id not in source_by_id:
            continue
        if len(source_by_id[image_id]) != 1:
            issues.append("ambiguous target source count for 0x%04x" % image_id)
            continue
        src_item = source_by_id[image_id][0]
        provider_items = imageio_provider_by_id.get(image_id, [])
        if len(provider_items) != 1:
            issues.append("ImageIO provider/source count mismatch for 0x%04x" % image_id)
            continue
        if src_item["provider"].lower() != provider_items[0]["provider"].lower():
            issues.append("ImageIO provider pointer mismatch for 0x%04x" % image_id)
            continue
        final_calls = [x for x in finals if x["phase"] == "CALL" and
                       x["source"].lower() == src_item["source"].lower()]
        final_results = [x for x in finals if x["phase"] == "RESULT" and
                         x["source"].lower() == src_item["source"].lower()]
        if len(final_calls) != 1 or len(final_results) != 1:
            issues.append("final ImageIO source correlation count mismatch for 0x%04x" % image_id)
            continue
        if final_results[0].get("result") != "NONNULL":
            issues.append("final ImageIO target result is NULL")
            continue
        correlated.append(dict(
            image_id=image_id,
            provider=src_item["provider"],
            source=src_item["source"],
            provider_size=provider_items[0]["size"],
            image_index=final_calls[0]["image_index"],
            result=final_results[0]["result"]))

    raw_ids = [x["image_id"] for x in raw_calls]
    source_ids = set(x["image_id"] for x in source_results)
    correlated_ids = set(x["image_id"] for x in correlated)

    if mode == "snow":
        if adapted_count != 0 or passthrough_count != 6 or adapter_pass_count != 0:
            issues.append("Snow bitmapInfo mode counts mismatch")
        if raw_ids != SNOW_ORDER:
            issues.append("Snow raw target order mismatch")
        if [x["image_id"] for x in raw_provider_calls] != SNOW_ORDER:
            issues.append("Snow raw provider target order mismatch")
        if any(x["size"] != 484 for x in raw_provider_calls):
            issues.append("Snow raw provider size mismatch")
        if source_ids:
            issues.append("Snow target ImageIO source count is not zero")
        if correlated_ids:
            issues.append("Snow target final ImageIO correlation is not zero")
    elif mode == "lion":
        if adapted_count != 6 or adapter_pass_count != 6 or passthrough_count != 0:
            issues.append("Lion bitmapInfo mode counts mismatch")
        if set(raw_ids) != LION_RAW_IDS or len(raw_ids) != 2:
            issues.append("Lion raw target ID set mismatch")
        if set(x["image_id"] for x in raw_provider_calls) != LION_RAW_IDS or len(raw_provider_calls) != 2:
            issues.append("Lion raw provider target ID set mismatch")
        raw_geometry = dict((x["image_id"], (x["width"], x["height"], x["bpr"]))
                            for x in raw_calls)
        if raw_geometry.get(0x4e8e) != (256, 256, 1024):
            issues.append("Lion 0x4e8e raw geometry mismatch")
        if raw_geometry.get(0x4e8d) != (2, 62, 8):
            issues.append("Lion 0x4e8d raw geometry mismatch")
        raw_sizes = dict((x["image_id"], x["size"]) for x in raw_provider_calls)
        if raw_sizes.get(0x4e8e) != 262144:
            issues.append("Lion 0x4e8e raw provider size mismatch")
        if raw_sizes.get(0x4e8d) != 496:
            issues.append("Lion 0x4e8d raw provider size mismatch")
        if source_ids != LION_IMAGEIO_IDS or len(source_results) != 3:
            issues.append("Lion ImageIO source target ID set mismatch")
        if correlated_ids != LION_IMAGEIO_IDS or len(correlated) != 3:
            issues.append("Lion final ImageIO source correlation mismatch")

    fp = open(output, "w")
    try:
        emit(fp, "== PPC Carbon GUI CoreUI shared-art external-boundary live trace summary ==")
        emit(fp, "analyzer_version=%s" % ANALYZER_VERSION)
        emit(fp, "audit_contract=%s" % AUDIT_CONTRACT)
        emit(fp, "mode=%s" % mode)
        emit(fp, "product_version=%s" % product)
        emit(fp, "build_version=%s" % build)
        emit(fp, "build_marker_count=%d" % build_count)
        emit(fp, "runner_result_pass=%s" % ("YES" if runner_pass else "NO"))
        emit(fp, "image_bitmapinfo_exact_call_count=%d" % compat_call_count)
        emit(fp, "image_bitmapinfo_adapted_count=%d" % adapted_count)
        emit(fp, "image_bitmapinfo_passthrough_count=%d" % passthrough_count)
        emit(fp, "image_bitmapinfo_adapter_pass_count=%d" % adapter_pass_count)

        emit(fp)
        emit(fp, "== Raw branch target correlation ==")
        emit(fp, "raw_target_call_count=%d" % len(raw_calls))
        for item in raw_calls:
            emit(fp, "raw_target image_id=0x%04x width=%d height=%d bpr=%d stack_ok=%s" %
                 (item["image_id"], item["width"], item["height"], item["bpr"],
                  item["stack_ok"]))
        emit(fp, "raw_provider_target_count=%d" % len(raw_provider_calls))
        for item in raw_provider_calls:
            emit(fp, "raw_provider image_id=0x%04x data=%s size=%d stack_ok=%s" %
                 (item["image_id"], item["data"], item["size"], item["stack_ok"]))

        emit(fp)
        emit(fp, "== ImageIO source target correlation ==")
        emit(fp, "imageio_provider_target_count=%d" % len(imageio_provider_calls))
        for item in imageio_provider_calls:
            emit(fp, "imageio_provider image_id=0x%04x data=%s size=%d stack_ok=%s" %
                 (item["image_id"], item["data"], item["size"], item["stack_ok"]))
        emit(fp, "imageio_source_target_count=%d" % len(source_results))
        for item in source_results:
            emit(fp, "imageio_source image_id=0x%04x provider=%s source=%s stack_ok=%s" %
                 (item["image_id"], item["provider"], item["source"], item["stack_ok"]))
        emit(fp, "correlated_final_target_count=%d" % len(correlated))
        for item in sorted(correlated, key=lambda x: x["image_id"]):
            emit(fp, "correlated_final image_id=0x%04x provider=%s provider_size=%d source=%s image_index=%d result=%s" %
                 (item["image_id"], item["provider"], item["provider_size"],
                  item["source"], item["image_index"], item["result"]))

        emit(fp)
        emit(fp, "== Compatibility design evidence ==")
        emit(fp, "raw_boundary_context=CGDataProviderCreateWithData_and_CGImageCreate_preserve_exact_legacy_ID")
        emit(fp, "imageio_boundary_context=CGImageSourceCreateWithDataProvider_preserves_exact_legacy_ID_via_CreateImageSource_saved_incoming_r30")
        emit(fp, "final_image_context=source_pointer_correlates_back_to_exact_legacy_ID")
        emit(fp, "resource_rewrite_required=NO")
        emit(fp, "private_CoreUI_patch_required=NO")

        emit(fp)
        emit(fp, "== Validation ==")
        if issues:
            for issue in issues:
                emit(fp, "validation_issue=%s" % issue)
            emit(fp, "RESULT: FAIL")
        else:
            emit(fp, "external_boundary_trace_exact=YES")
            emit(fp, "RESULT: PASS")
    finally:
        fp.close()

    print("Created: %s" % output)
    if issues:
        print("RESULT: FAIL")
        for issue in issues:
            print("validation_issue=%s" % issue)
        return 1
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
